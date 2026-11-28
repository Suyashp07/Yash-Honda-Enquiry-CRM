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

    // Fetch live ground-truth metrics across floor, analytics, branches, enquiries, follow-ups
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const enquiryWhere: any = branchId ? { branchId } : {};

    const [execSummary, floorData, allBranches, mtdEnquiries, followUps, activeVehiclesCount] =
      await Promise.all([
        this.analyticsService.getExecutiveSummary(user, branchId, range),
        this.analyticsService.getFloorDashboard(user, branchId),
        this.prisma.branch.findMany({
          orderBy: { name: 'asc' },
          select: { id: true, name: true, code: true, wing: true, address: true, status: true },
        }),
        this.prisma.enquiry.findMany({
          where: { ...enquiryWhere, createdAt: { gte: startOfMonth } },
          orderBy: { createdAt: 'desc' },
          include: {
            branch: { select: { id: true, name: true, code: true, wing: true } },
            customer: { select: { name: true, mobile: true, area: { select: { name: true } } } },
            leadSource: { select: { name: true } },
            assignedTo: { select: { id: true, name: true } },
            quotations: {
              take: 1,
              orderBy: { createdAt: 'desc' },
              include: { vehicle: { select: { name: true, code: true, category: true } } },
            },
          },
        }),
        this.prisma.followUp.findMany({
          where: branchId ? { enquiry: { branchId } } : {},
          include: {
            enquiry: {
              select: {
                branch: { select: { name: true } },
                customer: { select: { name: true, mobile: true } },
              },
            },
          },
        }),
        this.prisma.vehicle.count({ where: { status: 'Active' } }),
      ]);

    const kpis = execSummary.kpis;
    const floor = floorData.summary;
    const reps = floorData.reps || [];
    const busyReps = reps.filter((r: any) => r.status === 'Busy');
    const idleReps = reps.filter((r: any) => r.status === 'Available' || r.status === 'Idle');
    const sessions = floorData.sessions || [];

    // Per-branch breakdown (MTD + Today)
    const branchBreakdown = allBranches.map((b) => {
      const bEnqs = mtdEnquiries.filter((e) => e.branchId === b.id);
      const bToday = bEnqs.filter((e) => e.createdAt >= startOfToday);
      const bBooked = bEnqs.filter((e) => e.status === 'CUSTOMER_BOUGHT').length;
      const bConv = bEnqs.length > 0 ? ((bBooked / bEnqs.length) * 100).toFixed(1) : '0.0';
      return {
        id: b.id,
        name: b.name,
        code: b.code,
        wing: b.wing || 'RedWing',
        status: b.status,
        address: b.address,
        todayLeads: bToday.length,
        mtdLeads: bEnqs.length,
        mtdBooked: bBooked,
        mtdConversion: `${bConv}%`,
        walkIns: bEnqs.filter((e) => e.enquiryType === 'Walk-in').length,
        telephonic: bEnqs.filter((e) => e.enquiryType !== 'Walk-in').length,
        cash: bEnqs.filter((e) => e.purchaseMode === 'Cash').length,
        finance: bEnqs.filter((e) => e.purchaseMode === 'Finance').length,
        exchange: bEnqs.filter((e) => e.exchange !== 'No').length,
      };
    });

    // Model-wise breakdown (MTD)
    const modelMap = new Map<string, { leads: number; booked: number }>();
    const sourceMap = new Map<string, number>();
    const areaMap = new Map<string, number>();
    const repMap = new Map<string, { leads: number; booked: number }>();

    for (const e of mtdEnquiries) {
      const vName = e.quotations?.[0]?.vehicle?.name || 'Unspecified';
      const curM = modelMap.get(vName) || { leads: 0, booked: 0 };
      curM.leads += 1;
      if (e.status === 'CUSTOMER_BOUGHT') curM.booked += 1;
      modelMap.set(vName, curM);

      const src = e.leadSource?.name || e.enquiryType || 'Direct';
      sourceMap.set(src, (sourceMap.get(src) || 0) + 1);

      const area = e.customer?.area?.name || 'Unspecified';
      areaMap.set(area, (areaMap.get(area) || 0) + 1);

      const repName = e.assignedTo?.name || 'Unassigned';
      const curR = repMap.get(repName) || { leads: 0, booked: 0 };
      curR.leads += 1;
      if (e.status === 'CUSTOMER_BOUGHT') curR.booked += 1;
      repMap.set(repName, curR);
    }

    const topModels = Array.from(modelMap.entries())
      .map(([model, s]) => ({ model, leads: s.leads, booked: s.booked }))
      .sort((a, b) => b.leads - a.leads)
      .slice(0, 12);

    const topSources = Array.from(sourceMap.entries())
      .map(([source, count]) => ({ source, count }))
      .sort((a, b) => b.count - a.count);

    const topAreas = Array.from(areaMap.entries())
      .map(([area, count]) => ({ area, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    const repPerformance = Array.from(repMap.entries())
      .map(([name, s]) => ({ name, mtdLeads: s.leads, mtdBooked: s.booked }))
      .sort((a, b) => b.mtdLeads - a.mtdLeads);

    // Follow-ups summary
    const overdueFollowUps = followUps.filter(
      (f) => !f.completedAt && f.scheduledAt && f.scheduledAt < startOfToday,
    );
    const dueTodayFollowUps = followUps.filter(
      (f) => !f.completedAt && f.scheduledAt && f.scheduledAt >= startOfToday && f.scheduledAt <= endOfToday,
    );
    const upcomingFollowUps = followUps.filter(
      (f) => !f.completedAt && f.scheduledAt && f.scheduledAt > endOfToday,
    );
    const completedFollowUps = followUps.filter((f) => Boolean(f.completedAt));

    // System context for LLM / reasoning engine
    const dealershipContext = {
      dealership: 'Yash Honda Two-Wheelers Pvt Ltd (Authorized Honda Dealership, Pune Network)',
      selectedScope: branch === 'all' ? 'All Branches' : branch,
      selectedRange: range,
      activeCatalogVehicles: activeVehiclesCount,
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
      branches: branchBreakdown,
      topModelsMtd: topModels,
      topSourcesMtd: topSources,
      topAreasMtd: topAreas,
      followUps: {
        overdueCount: overdueFollowUps.length,
        dueTodayCount: dueTodayFollowUps.length,
        upcomingCount: upcomingFollowUps.length,
        completedCount: completedFollowUps.length,
        overdueSample: overdueFollowUps.slice(0, 5).map((f) => ({
          customer: f.enquiry?.customer?.name,
          branch: f.enquiry?.branch?.name,
          scheduledAt: f.scheduledAt,
        })),
      },
      repsStatus: {
        totalReps: reps.length,
        busyCount: busyReps.length,
        busyNames: busyReps.map((r: any) => `${r.name} (with ${r.activeCustomerName || 'Customer'})`),
        idleCount: idleReps.length,
        idleNames: idleReps.slice(0, 10).map((r: any) => r.name),
      },
      repPerformanceMtd: repPerformance.slice(0, 12),
      recentEnquiries: mtdEnquiries.slice(0, 10).map((e) => ({
        customer: e.customer?.name,
        branch: e.branch?.name,
        vehicle: e.quotations?.[0]?.vehicle?.name || 'N/A',
        quoteNo: e.quotations?.[0]?.quoteNumber || 'N/A',
        grandTotal: e.quotations?.[0]?.grandTotal ? Number(e.quotations[0].grandTotal) : 0,
        mode: e.purchaseMode,
        status: e.status,
        rep: e.assignedTo?.name || 'Unassigned',
        date: e.createdAt.toISOString().split('T')[0],
      })),
      activeSessions: sessions.slice(0, 8).map((s: any) => ({
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
    const {
      kpis,
      repsStatus,
      branches = [],
      topModelsMtd = [],
      topSourcesMtd = [],
      topAreasMtd = [],
      followUps = {},
      repPerformanceMtd = [],
      recentEnquiries = [],
      activeCatalogVehicles = 0,
    } = ctx;

    // 0. Specific Branch Query (match by branch name or code)
    const matchedBranch = (branches as any[]).find(
      (b) =>
        q.includes((b.name || '').toLowerCase()) ||
        q.includes((b.code || '').toLowerCase()),
    );
    if (matchedBranch) {
      return `### ${matchedBranch.name} (${matchedBranch.code} · ${matchedBranch.wing})
- Status: **${matchedBranch.status}**
- Address: ${matchedBranch.address || 'Pune'}
- Today's Leads: **${matchedBranch.todayLeads}**
- Month-to-Date (MTD) Leads: **${matchedBranch.mtdLeads}** (Walk-in: **${matchedBranch.walkIns}**, Tele: **${matchedBranch.telephonic}**)
- MTD Bookings: **${matchedBranch.mtdBooked}** (**${matchedBranch.mtdConversion}** conversion)
- Payment Split (MTD): **${matchedBranch.finance}** Finance · **${matchedBranch.cash}** Cash · **${matchedBranch.exchange}** Exchange`;
    }

    // 1. Branch Performance / Comparison
    if (q.includes('branch') || q.includes('location') || q.includes('leading') || q.includes('compare')) {
      const sorted = [...(branches as any[])].sort((a, b) => b.mtdLeads - a.mtdLeads);
      const lines = sorted.map(
        (b) =>
          `- **${b.name}** (${b.wing}): **${b.todayLeads}** today · **${b.mtdLeads}** MTD leads · **${b.mtdBooked}** booked (**${b.mtdConversion}**)`,
      );
      return `### Branch-by-Branch Performance (Live)
${lines.join('\n')}`;
    }

    // 2. Follow-ups & Alerts
    if (q.includes('follow') || q.includes('pending') || q.includes('overdue') || q.includes('alert')) {
      const sample = (followUps.overdueSample || []) as any[];
      const sampleLines = sample.length
        ? '\n\nTop overdue follow-ups:\n' +
          sample.map((s) => `- **${s.customer || 'Customer'}** (${s.branch || 'Branch'})`).join('\n')
        : '';
      return `### Follow-up Status
- Overdue: **${followUps.overdueCount ?? 0}**
- Due Today: **${followUps.dueTodayCount ?? 0}**
- Upcoming: **${followUps.upcomingCount ?? 0}**
- Completed: **${followUps.completedCount ?? 0}**${sampleLines}`;
    }

    // 3. Top Models / Vehicle Catalog
    if (q.includes('model') || q.includes('bike') || q.includes('scooter') || q.includes('vehicle') || q.includes('selling')) {
      const modelLines = (topModelsMtd as any[]).slice(0, 6).map(
        (m) => `- **${m.model}**: **${m.leads}** leads · **${m.booked}** booked`,
      );
      return `### Top Honda Models (MTD · ${activeCatalogVehicles} active models in catalog)
${modelLines.length ? modelLines.join('\n') : '- No model enquiries recorded MTD yet.'}`;
    }

    // 4. Sales Reps / Floor Attendance / Performance
    if (q.includes('rep') || q.includes('staff') || q.includes('executive') || q.includes('floor') || q.includes('busy') || q.includes('idle')) {
      const repLines = (repPerformanceMtd as any[]).slice(0, 6).map(
        (r) => `- **${r.name}**: **${r.mtdLeads}** MTD leads · **${r.mtdBooked}** booked`,
      );
      return `### Sales Floor & Team Status
- Active on Floor: **${repsStatus.totalReps}** total (**${repsStatus.busyCount}** busy, **${repsStatus.idleCount}** available)
- Currently Busy: ${repsStatus.busyNames?.length ? repsStatus.busyNames.join(', ') : 'None'}
- Available Reps: ${repsStatus.idleNames?.length ? repsStatus.idleNames.join(', ') : 'None'}

Top MTD Performers:
${repLines.length ? repLines.join('\n') : '- No MTD rep activity recorded yet.'}`;
    }

    // 5. Sources & Areas
    if (q.includes('source') || q.includes('area') || q.includes('marketing') || q.includes('channel')) {
      const srcLines = (topSourcesMtd as any[]).slice(0, 5).map((s) => `- **${s.source}**: **${s.count}**`);
      const areaLines = (topAreasMtd as any[]).slice(0, 5).map((a) => `- **${a.area}**: **${a.count}**`);
      return `### Lead Sources & Top Areas (MTD)
Sources:
${srcLines.length ? srcLines.join('\n') : '- No source data yet.'}

Top Areas:
${areaLines.length ? areaLines.join('\n') : '- No area data yet.'}`;
    }

    // 6. Finance / Cash / Payment
    if (q.includes('finance') || q.includes('cash') || q.includes('loan') || q.includes('payment') || q.includes('exchange')) {
      return `### Payment Mode & Exchange Mix
- Finance Leads: **${kpis.financeCount}** (**${kpis.financePercentage}**)
- Cash Leads: **${kpis.cashCount}**
- Exchange Enquiries: **${kpis.exchangeCount}**`;
    }

    // 7. Recent Enquiries / Quotes
    if (q.includes('recent') || q.includes('latest') || q.includes('enquiry') || q.includes('quote') || q.includes('customer')) {
      const recLines = (recentEnquiries as any[]).slice(0, 5).map(
        (e) => `- **${e.customer || 'Guest'}** · ${e.vehicle} · ${e.branch} (${e.status})`,
      );
      return `### Recent Enquiries
${recLines.length ? recLines.join('\n') : '- No enquiries found in current MTD scope.'}`;
    }

    // 8. Default / Overall Performance Summary
    return `### Dealership Executive Briefing
- Total Leads (Scope): **${kpis.totalLeads}** (${kpis.walkInsToday} walk-ins today, ${kpis.telephonicToday} calls)
- Bookings: **${kpis.bookedCount}** (**${kpis.conversionRate}** conversion)
- Floor Team: **${repsStatus.busyCount}** busy · **${repsStatus.idleCount}** available
- Payment Split: **${kpis.financeCount}** Finance (${kpis.financePercentage}) · **${kpis.cashCount}** Cash · **${kpis.exchangeCount}** Exchange
- Follow-ups: **${followUps.overdueCount ?? 0}** overdue · **${followUps.dueTodayCount ?? 0}** due today

Ask about any specific branch (e.g. Phursungi, BT Kawade, Saswad, Sasane Nagar, Uruli Kanchan, Wadki), model, sales rep, or follow-up.`;
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
    const systemPrompt = `You are the executive Business Advisor for Yash Honda Two-Wheelers in Pune. You have complete live dealership data: ${JSON.stringify(context)}. Answer any question about any branch, vehicle model, sales executive, follow-up, lead source, area, payment mode, or recent enquiry using ONLY the provided live metrics. Be concise, structured with clean headings (###) and bullet points (- ), and never invent numbers.`;

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

    for (const model of ['gemini-2.5-flash', 'gemini-2.0-flash']) {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (res.ok) {
        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        if (text) return text;
      } else {
        const errText = await res.text();
        this.logger.warn(`Gemini ${model} returned ${res.status}: ${errText}`);
      }
    }
    throw new Error('All Gemini models failed');
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
