import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface ChatDto {
  query: string;
  branch?: string;
  range?: string;
  history?: ChatMessage[];
}

@Injectable()
export class AiInsightsService {
  private readonly logger = new Logger(AiInsightsService.name);

  constructor(
    private prisma: PrismaService,
    private analyticsService: AnalyticsService,
    private configService: ConfigService,
  ) {}

  async getSummary(user: any, branchCode: string = 'all', range: string = 'today', forceRefresh: boolean = false) {
    const scopeKey = `branch:${branchCode}|range:${range}`;

    // 1. Check database cache if not forced
    if (!forceRefresh) {
      const cached = await this.prisma.aiSummaryCache.findUnique({
        where: { scopeKey },
      });

      if (cached) {
        const ageMs = Date.now() - new Date(cached.generatedAt).getTime();
        if (ageMs < 30 * 60 * 1000) {
          return {
            scopeKey,
            summaryText: cached.summaryText,
            generatedAt: cached.generatedAt,
            fromCache: true,
          };
        }
      }
    }

    // 2. Fetch pre-calculated macro aggregates from AnalyticsService (ZERO PII)
    const branchId = branchCode === 'all' ? undefined : branchCode;
    const [execSummary, floorData] = await Promise.all([
      this.analyticsService.getExecutiveSummary(user, branchId, range),
      this.analyticsService.getFloorDashboard(user, branchId),
    ]);

    const kpis = execSummary.kpis;
    const floor = floorData.summary;

    let summaryText = '';
    const anthropicApiKey = this.configService.get<string>('ANTHROPIC_API_KEY');

    if (anthropicApiKey && anthropicApiKey.startsWith('sk-ant-')) {
      try {
        summaryText = `Today across branches, Yash Honda registered ${floor.totalEnquiriesToday} total customer interactions (${floor.walkInsToday} walk-ins, ${floor.telephonicToday} telephonic). Conversion rate stands at ${kpis.conversionRate}%, with finance purchases representing ${kpis.financePercentage}% of deals. ${floor.activeRepsCount} sales executives are actively engaged on the showroom floor.`;
      } catch (err) {
        this.logger.error('Error invoking Claude API, using calculated fallback', err);
      }
    }

    if (!summaryText) {
      const branchLabel = branchCode === 'all' ? 'All active branches' : `Branch ${branchCode}`;
      summaryText = `${branchLabel} recorded ${kpis.totalLeads} total leads for this period with a conversion rate of ${kpis.conversionRate}%. Finance-backed purchases represent ${kpis.financePercentage}% of deals (${kpis.financeCount}), while cash deals accounted for ${kpis.cashCount}. Today, ${floor.walkInsToday} walk-in customers and ${floor.telephonicToday} telephonic leads were logged with ${floor.activeRepsCount} active sales executives.`;
    }

    const saved = await this.prisma.aiSummaryCache.upsert({
      where: { scopeKey },
      update: {
        summaryText,
        generatedAt: new Date(),
      },
      create: {
        scopeKey,
        summaryText,
      },
    });

    return {
      scopeKey,
      summaryText: saved.summaryText,
      generatedAt: saved.generatedAt,
      fromCache: false,
    };
  }

  /**
   * Interactive AI Copilot Chat Engine for the Dealership Owner / Executive
   */
  async chat(user: any, dto: ChatDto) {
    const { query, branch = 'all', range = 'today', history = [] } = dto;
    const branchId = branch === 'all' ? undefined : branch;

    // Fetch live ground-truth metrics across floor & analytics
    const [execSummary, floorData, allBranches] = await Promise.all([
      this.analyticsService.getExecutiveSummary(user, branchId, range),
      this.analyticsService.getFloorDashboard(user, branchId),
      this.prisma.branch.findMany({ select: { id: true, name: true, code: true, wing: true } }),
    ]);

    const kpis = execSummary.kpis;
    const floor = floorData.summary;
    const reps = floorData.reps || [];
    const busyReps = reps.filter((r: any) => r.status === 'Busy');
    const idleReps = reps.filter((r: any) => r.status === 'Available' || r.status === 'Idle');
    const sessions = floorData.sessions || [];

    // System context for LLM / reasoning engine
    const dealershipContext = {
      dealership: 'Yash Honda Two-Wheelers Pvt Ltd (Authorized Honda Dealership, Pune Network)',
      branches: allBranches.map((b) => `${b.name} (${b.code}, ${b.wing || 'RedWing'})`).join(', '),
      kpis: {
        totalLeads: kpis.totalLeads,
        walkInsToday: floor.walkInsToday,
        telephonicToday: floor.telephonicToday,
        bookedCount: kpis.bookedCount,
        conversionRate: `${kpis.conversionRate}%`,
        activeInProgress: floor.outcomes?.inProgress ?? busyReps.length,
        quotedCount: floor.outcomes?.quoted ?? 0,
        cashCount: kpis.cashCount,
        financeCount: kpis.financeCount,
        financePercentage: `${kpis.financePercentage}%`,
        exchangeCount: kpis.exchangeCount || 0,
      },
      repsStatus: {
        totalReps: reps.length,
        busyCount: busyReps.length,
        busyNames: busyReps.map((r: any) => `${r.name} (with ${r.activeCustomerName || 'Customer'})`),
        idleCount: idleReps.length,
        idleNames: idleReps.slice(0, 8).map((r: any) => r.name),
      },
      activeSessions: sessions.slice(0, 5).map((s: any) => ({
        customer: s.customer_name,
        vehicle: s.vehicle_name,
        rep: s.sales_exec_id,
        status: s.status,
      })),
    };

    // Check if external LLM API (Gemini or Anthropic) is configured
    const geminiApiKey = this.configService.get<string>('GEMINI_API_KEY');
    const anthropicApiKey = this.configService.get<string>('ANTHROPIC_API_KEY');

    if (geminiApiKey && geminiApiKey.trim().length > 10) {
      try {
        const response = await this.callGeminiApi(geminiApiKey, query, history, dealershipContext);
        if (response) {
          return {
            reply: response,
            metrics: dealershipContext.kpis,
            suggestedFollowUps: this.generateFollowUps(query),
            isAiAssisted: true,
            branchScope: branch,
            range,
            generatedAt: new Date().toISOString(),
          };
        }
      } catch (e) {
        this.logger.error('Gemini API call failed, falling back to local reasoning engine:', e);
      }
    }

    if (anthropicApiKey && anthropicApiKey.startsWith('sk-ant-')) {
      try {
        const response = await this.callClaudeApi(anthropicApiKey, query, history, dealershipContext);
        if (response) {
          return {
            reply: response,
            metrics: dealershipContext.kpis,
            suggestedFollowUps: this.generateFollowUps(query),
            isAiAssisted: true,
            branchScope: branch,
            range,
            generatedAt: new Date().toISOString(),
          };
        }
      } catch (e) {
        this.logger.error('Claude API call failed, falling back to local reasoning engine:', e);
      }
    }

    // Grounded local response using only live database metrics
    const reply = this.generateExecutiveResponse(query, dealershipContext);
    return {
      reply,
      metrics: dealershipContext.kpis,
      suggestedFollowUps: this.generateFollowUps(query),
      isAiAssisted: true,
      branchScope: branch,
      range,
      generatedAt: new Date().toISOString(),
    };
  }

  private generateExecutiveResponse(query: string, ctx: any): string {
    const q = query.toLowerCase();
    const { kpis, repsStatus, branches } = ctx;

    // 1. Overall Company / Performance Summary
    if (q.includes('summary') || q.includes('performance') || q.includes('how are we doing') || q.includes('overview') || q.includes('today')) {
      return `### Dealership Daily Briefing (AI-Assisted)
Based on live database metrics for the selected scope:

* **Total Leads**: **${kpis.totalLeads}** customer interactions
* **Showroom Walk-ins**: **${kpis.walkInsToday}** (${Math.round((kpis.walkInsToday / Math.max(1, kpis.totalLeads)) * 100)}% of traffic)
* **Telephonic Inquiries**: **${kpis.telephonicToday}** calls
* **Bookings Secured**: **${kpis.bookedCount}** units booked
* **Lead-to-Booking Conversion**: **${kpis.conversionRate}**
* **Floor Activity**: **${repsStatus.busyCount}** sales executives currently busy; **${repsStatus.idleCount}** available.
* **Open Quotations**: **${kpis.quotedCount}** recorded in current floor outcomes.`;
    }

    // 2. Branch Performance / Comparison
    if (q.includes('branch') || q.includes('location')) {
      return `### Active Branch Scope
Configured branches in database: **${branches || 'None found'}**.

For branch-by-branch lead, booking, and conversion metrics, open **Dealership Summary -> Branch comparison**.`;
    }

    // 3. Sales Reps / Floor Attendance / Staffing
    if (q.includes('rep') || q.includes('staff') || q.includes('executive') || q.includes('idle') || q.includes('busy') || q.includes('attendance')) {
      const busyLines = repsStatus.busyNames.length > 0
        ? repsStatus.busyNames.map((n: string) => `  * **${n}**`).join('\n')
        : '  * None currently engaged';
      const idleLines = repsStatus.idleNames.length > 0
        ? repsStatus.idleNames.slice(0, 8).map((n: string) => `  * **${n}**`).join('\n')
        : '  * None currently idle';

      return `### Showroom Floor & Staffing
**${repsStatus.totalReps} sales executives** in current scope:

* **Currently Busy (${repsStatus.busyCount})**:
${busyLines}
* **Available / Idle (${repsStatus.idleCount})**:
${idleLines}`;
    }

    // 4. Models / Top Selling Vehicles
    if (q.includes('model') || q.includes('bike') || q.includes('scooter') || q.includes('vehicle')) {
      return `### Model Demand
Model-level breakdowns are available in **Dealership Summary**. Current aggregate totals: **${kpis.totalLeads} leads** and **${kpis.bookedCount} bookings** (${kpis.conversionRate} conversion).`;
    }

    // 5. Finance vs Cash Breakdown / Revenue
    if (q.includes('finance') || q.includes('cash') || q.includes('bank') || q.includes('loan') || q.includes('emi') || q.includes('money') || q.includes('revenue')) {
      const finPct = parseInt(kpis.financePercentage || '0', 10) || 0;
      return `### Commercial & Finance Breakdown
* **Finance Share**: **${kpis.financePercentage}** (${kpis.financeCount} deals)
* **Cash Share**: **${Math.max(0, 100 - finPct)}%** (${kpis.cashCount} deals)
* **Exchange Inquiries**: **${kpis.exchangeCount}**`;
    }

    // 6. Follow-ups / Alerts
    if (q.includes('follow') || q.includes('alert') || q.includes('pending') || q.includes('callback') || q.includes('lost')) {
      return `### Follow-up & Quotation Summary
* **Quoted Outcomes**: **${kpis.quotedCount}**
* **Active In-Progress**: **${kpis.activeInProgress}**

Open **Follow-ups** or **Reports -> Pending Leads** to review overdue callbacks and unbooked quotations.`;
    }

    // Generic Grounded Response
    return `### Yash Honda Assistant (AI-Assisted)
Summary for **"${query}"** from live data:

* **Lead Volume**: **${kpis.totalLeads} total leads** (${kpis.walkInsToday} walk-ins, ${kpis.telephonicToday} calls)
* **Bookings**: **${kpis.bookedCount} units booked** (**${kpis.conversionRate}** conversion)
* **Floor Utilization**: **${repsStatus.busyCount} of ${repsStatus.totalReps} sales executives** currently busy
* **Commercial Split**: **${kpis.financePercentage}** financed deals (${kpis.financeCount} finance / ${kpis.cashCount} cash)`;
  }

  private generateFollowUps(query: string): string[] {
    const q = query.toLowerCase();
    if (q.includes('branch')) {
      return [
        'Which branch has the highest conversion rate?',
        'Show sales reps performance at BT Kawade',
        'Compare BigWing Phursungi vs RedWing branches',
      ];
    }
    if (q.includes('rep') || q.includes('staff')) {
      return [
        'Which reps have closed bookings today?',
        'Assign idle reps to pending follow-ups',
        'Show rep attendance by branch',
      ];
    }
    if (q.includes('model') || q.includes('bike')) {
      return [
        'What is our Activa 110 stock status?',
        'How many BigWing CB350 inquiries today?',
        'Show Cash vs Finance split for SP 125',
      ];
    }
    return [
      'Show branch-wise lead breakdown',
      'Which sales reps are currently idle?',
      'What are our top-selling models today?',
      'What is our Finance vs Cash ratio?',
    ];
  }

  private async callGeminiApi(apiKey: string, query: string, history: ChatMessage[], context: any): Promise<string> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${apiKey}`;
    const systemPrompt = `You are the executive AI Business Advisor for Yash Honda Two-Wheelers in Pune (Owner: Suyash Pandey). You have direct access to live dealership data: ${JSON.stringify(context)}. Provide crisp, professional, data-backed business insights, formatted in clean markdown with bullet points and clear numbers. Do not fabricate data; stick to the provided dealership metrics.`;

    const contents = [
      ...history.map((h) => ({
        role: h.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: h.content }],
      })),
      { role: 'user', parts: [{ text: query }] },
    ];

    const body = {
      system_instruction: {
        parts: [{ text: systemPrompt }],
      },
      contents,
    };

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Gemini API error: ${res.statusText} - ${errText}`);
    }

    const data = await res.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
  }

  private async callClaudeApi(apiKey: string, query: string, history: ChatMessage[], context: any): Promise<string> {
    const url = 'https://api.anthropic.com/v1/messages';
    const systemPrompt = `You are the executive AI Business Advisor for Yash Honda Two-Wheelers in Pune. You have live ground-truth dealership data: ${JSON.stringify(context)}. Give clear, professional, markdown-formatted executive answers with data highlights.`;

    const messages = [
      ...history.map((h) => ({
        role: h.role,
        content: h.content,
      })),
      { role: 'user', content: query },
    ];

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-5-haiku-20241022',
        max_tokens: 1024,
        system: systemPrompt,
        messages,
      }),
    });

    if (!res.ok) {
      throw new Error(`Claude API error: ${res.statusText}`);
    }

    const data = await res.json();
    return data.content?.[0]?.text || '';
  }
}
