import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EnquiryStatus, Role } from '@prisma/client';

@Injectable()
export class AnalyticsService {
  constructor(private prisma: PrismaService) {}

  private activeFloorSessions = new Map<string, {
    salesExecId: string;
    salesExecName?: string;
    customerName: string;
    customerMobile?: string;
    vehicleName: string;
    colourName?: string;
    grandTotal?: number;
    branchId: string;
    status: string;
    startedAt: Date;
    lastHeartbeat: Date;
  }>();

  upsertFloorSession(user: any, data: any) {
    const salesExecId = data.salesExecId || user.id;
    const branchId = data.branchId || user.assignedBranchIds?.[0] || '';
    const existing = this.activeFloorSessions.get(salesExecId);

    const session = {
      salesExecId,
      salesExecName: data.salesExecName || user.name || 'Sales Rep',
      customerName: data.customerName || 'Walk-in Guest',
      customerMobile: data.customerMobile || '',
      vehicleName: data.vehicleName || 'Honda Model',
      colourName: data.colourName || '',
      grandTotal: data.grandTotal ? Number(data.grandTotal) : undefined,
      branchId,
      status: data.status || 'IN_PROGRESS',
      startedAt: existing?.startedAt || new Date(),
      lastHeartbeat: new Date(),
    };

    this.activeFloorSessions.set(salesExecId, session);
    return { success: true, session };
  }

  removeFloorSession(user: any, salesExecId?: string) {
    const targetId = salesExecId || user.id;
    this.activeFloorSessions.delete(targetId);
    return { success: true };
  }

  getActiveFloorSessions(branchIds: string[]) {
    const cutoff = new Date(Date.now() - 30 * 60 * 1000);
    const result: any[] = [];
    for (const [id, s] of this.activeFloorSessions.entries()) {
      if (s.lastHeartbeat < cutoff) {
        this.activeFloorSessions.delete(id);
      } else if (branchIds.includes(s.branchId)) {
        result.push(s);
      }
    }
    return result;
  }

  private getDates(range?: string, from?: string, to?: string) {
    if (from && to) {
      return { gte: new Date(from), lte: new Date(to) };
    }
    const now = new Date();
    if (range === 'today') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
      return { gte: start, lte: end };
    }
    if (range === 'mtd') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      return { gte: start, lte: now };
    }
    // Default last 30 days
    const start = new Date();
    start.setDate(now.getDate() - 30);
    return { gte: start, lte: now };
  }

  async getFloorDashboard(user: any, branchId?: string, targetDateStr?: string) {
    let dayDates: { gte: Date; lte: Date };
    let effectiveDateStr: string;

    if (targetDateStr) {
      const parts = targetDateStr.split('-');
      if (parts.length === 3) {
        const year = parseInt(parts[0], 10);
        const month = parseInt(parts[1], 10) - 1;
        const day = parseInt(parts[2], 10);
        const start = new Date(year, month, day, 0, 0, 0, 0);
        const end = new Date(year, month, day, 23, 59, 59, 999);
        dayDates = { gte: start, lte: end };
        effectiveDateStr = targetDateStr;
      } else {
        const parsed = new Date(targetDateStr);
        if (!isNaN(parsed.getTime())) {
          const start = new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate(), 0, 0, 0, 0);
          const end = new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate(), 23, 59, 59, 999);
          dayDates = { gte: start, lte: end };
          effectiveDateStr = parsed.toISOString().split('T')[0];
        } else {
          dayDates = this.getDates('today');
          effectiveDateStr = new Date().toISOString().split('T')[0];
        }
      }
    } else {
      dayDates = this.getDates('today');
      effectiveDateStr = new Date().toISOString().split('T')[0];
    }

    // Consolidated: all active branches across Pune
    const allBranches = await this.prisma.branch.findMany({
      where: { status: 'Active' },
      select: {
        id: true,
        code: true,
        name: true,
      },
      orderBy: { code: 'asc' },
    });
    const allBranchIds = allBranches.map((b) => b.id);

    // Enforce branch scope based on user role
    const isSuperAdmin = user.role === Role.SUPER_ADMIN || user.role === Role.OWNER;
    const userAssignedBranchIds: string[] = user.assignedBranchIds || [];
    const accessibleBranchIds = isSuperAdmin
      ? allBranchIds
      : userAssignedBranchIds.length > 0
        ? userAssignedBranchIds
        : (allBranchIds.length > 0 ? [allBranchIds[0]] : []);

    // Current Dealership filter
    let currentBranchFilter = branchId && branchId !== 'all' ? branchId : undefined;
    if (!isSuperAdmin) {
      if (!currentBranchFilter || !accessibleBranchIds.includes(currentBranchFilter)) {
        currentBranchFilter = accessibleBranchIds[0];
      }
    }

    const currentBranchIds = currentBranchFilter ? [currentBranchFilter] : accessibleBranchIds;
    const currentBranchObj = currentBranchFilter
      ? allBranches.find((b) => b.id === currentBranchFilter)
      : allBranches.find((b) => accessibleBranchIds.includes(b.id)) || allBranches[0];
    const currentBranchName = currentBranchObj?.name || 'Phursungi';

    // Enquiries on this day within accessible branch scope (newest first)
    const allTodayEnquiries = await this.prisma.enquiry.findMany({
      where: {
        branchId: { in: accessibleBranchIds },
        createdAt: dayDates,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        customer: {
          select: {
            id: true,
            name: true,
            mobile: true,
          },
        },
        quotations: {
          take: 1,
          orderBy: { createdAt: 'desc' },
          include: {
            vehicle: {
              select: {
                id: true,
                code: true,
                name: true,
              },
            },
          },
        },
      },
    });

    // Current branch enquiries today
    const currentTodayEnquiries = currentBranchFilter
      ? allTodayEnquiries.filter((e) => e.branchId === currentBranchFilter)
      : allTodayEnquiries;

    // Current Dealership metrics
    const currentTotal = currentTodayEnquiries.length;
    const currentWalkIns = currentTodayEnquiries.filter((e) =>
      e.enquiryType?.toLowerCase().includes('walk'),
    ).length;
    const currentCalls = currentTodayEnquiries.filter((e) =>
      e.enquiryType?.toLowerCase().includes('tele'),
    ).length;

    // Consolidated metrics (All Dealerships)
    const consolidatedTotal = allTodayEnquiries.length;
    const consolidatedWalkIns = allTodayEnquiries.filter((e) =>
      e.enquiryType?.toLowerCase().includes('walk'),
    ).length;
    const consolidatedCalls = allTodayEnquiries.filter((e) =>
      e.enquiryType?.toLowerCase().includes('tele'),
    ).length;

    // Reps assigned to current branches
    const salesReps = await this.prisma.user.findMany({
      where: {
        role: Role.SALES_EXEC,
        status: 'Active',
        userBranches: { some: { branchId: { in: currentBranchIds } } },
      },
      select: {
        id: true,
        name: true,
        mobile: true,
        userBranches: { select: { branch: { select: { id: true, code: true, name: true } } } },
      },
      orderBy: { name: 'asc' },
    });

    const bookedToday = currentTodayEnquiries.filter(
      (e) => e.status === EnquiryStatus.CUSTOMER_BOUGHT,
    ).length;
    const quotedToday = currentTodayEnquiries.filter(
      (e) => e.quotations && e.quotations.length > 0 && e.status !== EnquiryStatus.CUSTOMER_BOUGHT,
    ).length;
    const inProgressToday = currentTodayEnquiries.filter(
      (e) =>
        e.status !== EnquiryStatus.CUSTOMER_BOUGHT && (!e.quotations || e.quotations.length === 0),
    ).length;

    const activeSessions = this.getActiveFloorSessions(currentBranchIds);

    // Rep workload mapping
    const repStats = salesReps.map((rep) => {
      const repEnquiriesToday = currentTodayEnquiries.filter((e) => e.assignedToId === rep.id);
      const activeLiveSession = activeSessions.find((s) => s.salesExecId === rep.id);
      const inProgressEnq = repEnquiriesToday.find((e) =>
        e.status === 'ACTIVE' && (e.remarks?.includes('In progress') || !e.quotations?.length),
      );
      const isBusy = activeLiveSession != null || inProgressEnq != null;
      const activeCustomer = activeLiveSession?.customerName || inProgressEnq?.customer?.name;
      return {
        id: rep.id,
        name: rep.name,
        mobile: rep.mobile,
        branches: rep.userBranches.map((ub) => ub.branch.code),
        enquiriesTodayCount: repEnquiriesToday.length + (activeLiveSession ? 1 : 0),
        status: isBusy ? 'Busy' : 'Idle',
        activeCustomerName: activeCustomer,
      };
    });

    // Sort reps alphabetically matching prototype
    repStats.sort((a, b) => a.name.localeCompare(b.name));

    const busyRepsCount = repStats.filter((r) => r.status === 'Busy').length;
    const idleRepsCount = repStats.length - busyRepsCount;
    const liveSessionsCount = activeSessions.length;

    return {
      date: effectiveDateStr,
      currentDealership: {
        name: currentBranchName,
        total: currentTotal + liveSessionsCount,
        walkIns: currentWalkIns + liveSessionsCount,
        callsRecd: currentCalls,
      },
      consolidated: {
        name: 'All Dealerships',
        total: consolidatedTotal + liveSessionsCount,
        walkIns: consolidatedWalkIns + liveSessionsCount,
        callsRecd: consolidatedCalls,
      },
      summary: {
        totalEnquiriesToday: currentTotal + liveSessionsCount,
        walkInsToday: currentWalkIns + liveSessionsCount,
        telephonicToday: currentCalls,
        bookingsToday: bookedToday,
        activeRepsCount: salesReps.length,
        busyRepsCount,
        idleRepsCount,
        outcomes: {
          inProgress: inProgressToday + liveSessionsCount,
          quoted: quotedToday,
          booked: bookedToday,
        },
      },
      branches: isSuperAdmin
        ? allBranches
        : allBranches.filter((b) => accessibleBranchIds.includes(b.id)),
      reps: repStats,
      sessions: [
        ...activeSessions.map((s) => ({
          id: `live-${s.salesExecId}`,
          enquiryNumber: 'Draft · Live',
          branchId: s.branchId,
          enquiryType: 'Walk-in',
          status: 'ACTIVE',
          sales_exec_id: s.salesExecId,
          customer_name: s.customerName || 'Walk-in Guest',
          customer_mobile: s.customerMobile || '',
          vehicle_name: s.vehicleName || 'Honda Model',
          colour: s.colourName || '',
          grand_total: s.grandTotal || null,
          created_at: s.startedAt.toISOString(),
        })),
        ...currentTodayEnquiries.map((e) => {
          const q = e.quotations?.[0];
          const isBooked = e.status === EnquiryStatus.CUSTOMER_BOUGHT;
          const isInProgress = !isBooked && (e.remarks?.includes('In progress') || (e.status as any) === 'IN_PROGRESS' || !q);
          const computedStatus = isBooked ? 'BOOKED' : (isInProgress ? 'IN_PROGRESS' : 'QUOTED');
          return {
            id: e.id,
            enquiryNumber: q?.quoteNumber || `ENQ-${e.id.slice(-5).toUpperCase()}`,
            branchId: e.branchId,
            enquiryType: e.enquiryType,
            status: computedStatus,
            sales_exec_id: e.assignedToId,
            customer_name: e.customer?.name ?? 'Walk-in Guest',
            customer_mobile: e.customer?.mobile ?? '',
            vehicle_name: q?.vehicle?.name ?? (e.remarks?.split('·')[0]?.trim() || 'Honda Model'),
            colour: q?.colourName ?? '',
            buying_when: e.buyingWhen ?? '',
            grand_total: q?.grandTotal ? Number(q.grandTotal) : null,
            created_at: e.createdAt.toISOString(),
          };
        }),
      ],
    };
  }

  async getExecutiveSummary(user: any, branchId?: string, range: string = 'today') {
    const dateRange = this.getDates(range);

    const branchCondition: any =
      user.role === Role.SUPER_ADMIN || user.role === Role.OWNER
        ? branchId
          ? { branchId }
          : {}
        : { branchId: branchId || { in: user.assignedBranchIds } };

    const enquiries = await this.prisma.enquiry.findMany({
      where: {
        ...branchCondition,
        createdAt: dateRange,
      },
      select: {
        id: true,
        branchId: true,
        purchaseMode: true,
        status: true,
        exchange: true,
      },
    });

    const totalLeads = enquiries.length;
    const bookedCount = enquiries.filter((e) => e.status === EnquiryStatus.CUSTOMER_BOUGHT).length;
    const activeCount = enquiries.filter((e) => e.status === EnquiryStatus.ACTIVE).length;
    const closedCount = enquiries.filter((e) => e.status === EnquiryStatus.CLOSED).length;
    const financeCount = enquiries.filter((e) => e.purchaseMode?.toLowerCase() === 'finance').length;
    const cashCount = enquiries.filter((e) => e.purchaseMode?.toLowerCase() === 'cash').length;
    const exchangeCount = enquiries.filter((e) => e.exchange && e.exchange !== 'No').length;

    const conversionRate = totalLeads > 0 ? Number(((bookedCount / totalLeads) * 100).toFixed(2)) : 0;
    const financePercentage = totalLeads > 0 ? Number(((financeCount / totalLeads) * 100).toFixed(2)) : 0;

    return {
      scope: {
        branch: branchId || 'all',
        range,
      },
      kpis: {
        totalLeads,
        bookedCount,
        activeCount,
        closedLostCount: closedCount,
        conversionRate,
        financeCount,
        cashCount,
        financePercentage,
        exchangeCount,
      },
    };
  }

  async getFinancialSummary(user: any, branchId?: string, range: string = 'today') {
    const dateRange = this.getDates(range);

    const branchCondition: any =
      user.role === Role.SUPER_ADMIN || user.role === Role.OWNER
        ? branchId
          ? { branchId }
          : {}
        : { branchId: branchId || { in: user.assignedBranchIds } };

    const quotations = await this.prisma.quotation.findMany({
      where: {
        ...branchCondition,
        createdAt: dateRange,
      },
      include: {
        accessories: true,
      },
    });

    let totalQuotationValue = 0;
    let totalExShowroomValue = 0;
    let totalRoadTaxValue = 0;
    let totalInsuranceValue = 0;
    let totalAccessoriesValue = 0;

    for (const q of quotations) {
      totalQuotationValue += Number(q.grandTotal);
      totalExShowroomValue += Number(q.exShowroom);
      totalRoadTaxValue += Number(q.roadTax);
      totalInsuranceValue += Number(q.insurance);
      for (const a of q.accessories) {
        totalAccessoriesValue += Number(a.amount);
      }
    }

    const quotesCount = quotations.length;
    const avgDealSize = quotesCount > 0 ? Math.round(totalQuotationValue / quotesCount) : 0;

    return {
      scope: {
        branch: branchId || 'all',
        range,
      },
      financials: {
        quotesCount,
        totalQuotationValue,
        avgDealSize,
        totalExShowroomValue,
        totalRoadTaxValue,
        totalInsuranceValue,
        totalAccessoriesValue,
      },
    };
  }

  async getMatrixSummary(user: any, branchId?: string, range: string = 'mtd') {
    const dateRange = this.getDates(range);

    const branchCondition: any =
      user.role === Role.SUPER_ADMIN || user.role === Role.OWNER
        ? branchId
          ? { branchId }
          : {}
        : { branchId: branchId || { in: user.assignedBranchIds } };

    const quotations = await this.prisma.quotation.findMany({
      where: {
        ...branchCondition,
        createdAt: dateRange,
      },
      include: {
        branch: { select: { id: true, code: true, name: true } },
        vehicle: { select: { id: true, code: true, name: true, category: true } },
      },
    });

    const matrixMap: Record<string, Record<string, { count: number; totalValue: number }>> = {};

    for (const q of quotations) {
      const bCode = q.branch.code;
      const vCode = q.vehicle.code;

      if (!matrixMap[bCode]) matrixMap[bCode] = {};
      if (!matrixMap[bCode][vCode]) matrixMap[bCode][vCode] = { count: 0, totalValue: 0 };

      matrixMap[bCode][vCode].count += 1;
      matrixMap[bCode][vCode].totalValue += Number(q.grandTotal);
    }

    return {
      range,
      matrix: matrixMap,
    };
  }

  async getComprehensiveDealershipSummary(
    user: any,
    dateStr?: string,
    period: string = 'today',
    branchId?: string,
    fromStr?: string,
    toStr?: string,
  ) {
    const targetDate = dateStr ? new Date(`${dateStr}T12:00:00Z`) : new Date();
    const y = targetDate.getUTCFullYear();
    const m = targetDate.getUTCMonth();
    const d = targetDate.getUTCDate();

    let startDate: Date;
    let endDate: Date = new Date(Date.UTC(y, m, d, 23, 59, 59, 999));

    if (period === 'custom' && fromStr && toStr) {
      startDate = new Date(`${fromStr}T00:00:00.000Z`);
      endDate = new Date(`${toStr}T23:59:59.999Z`);
    } else if (period === 'week') {
      startDate = new Date(Date.UTC(y, m, d - 7, 0, 0, 0));
    } else if (period === 'mtd') {
      startDate = new Date(Date.UTC(y, m, 1, 0, 0, 0));
    } else if (period === 'ytd') {
      startDate = new Date(Date.UTC(y, 0, 1, 0, 0, 0));
    } else {
      // today
      startDate = new Date(Date.UTC(y, m, d, 0, 0, 0));
    }

    const monthStartDate = new Date(
      Date.UTC(endDate.getUTCFullYear(), endDate.getUTCMonth(), 1, 0, 0, 0),
    );

    // Branches filter based on user role and branchId query
    const branchFilter =
      user.role === Role.SUPER_ADMIN || user.role === Role.OWNER
        ? branchId && branchId !== 'all'
          ? { id: branchId }
          : undefined
        : { id: { in: user.assignedBranchIds } };

    const branches = await this.prisma.branch.findMany({
      where: {
        status: 'Active',
        ...(branchFilter ? branchFilter : {}),
      },
      select: {
        id: true,
        code: true,
        name: true,
      },
      orderBy: { code: 'asc' },
    });

    const activeBranchIds = branches.map((b) => b.id);

    // 1. Fetch period enquiries
    const enquiries = await this.prisma.enquiry.findMany({
      where: {
        branchId: { in: activeBranchIds },
        createdAt: { gte: startDate, lte: endDate },
      },
      include: {
        branch: { select: { id: true, code: true, name: true } },
        assignedTo: { select: { id: true, name: true } },
        leadSource: { select: { id: true, name: true } },
        quotations: {
          take: 1,
          orderBy: { createdAt: 'desc' },
          include: {
            vehicle: { select: { id: true, code: true, name: true, category: true } },
            accessories: true,
          },
        },
      },
    });

    // 2. Fetch MTD enquiries for conversion tracking
    const mtdEnquiries = await this.prisma.enquiry.findMany({
      where: {
        branchId: { in: activeBranchIds },
        createdAt: { gte: monthStartDate, lte: endDate },
      },
      include: {
        branch: { select: { id: true, code: true, name: true } },
        assignedTo: { select: { id: true, name: true } },
        leadSource: { select: { id: true, name: true } },
        quotations: {
          take: 1,
          orderBy: { createdAt: 'desc' },
          include: {
            vehicle: { select: { id: true, code: true, name: true, category: true } },
          },
        },
      },
    });

    // Vehicles list for categories
    const allVehicles = await this.prisma.vehicle.findMany({
      where: { status: 'Active' },
      select: { id: true, code: true, name: true, category: true },
      orderBy: { name: 'asc' },
    });

    // As on date / period metrics
    const totalLeads: Record<string, number> = { all: enquiries.length };
    const totalBk: Record<string, number> = {
      all: enquiries.filter((e) => e.status === EnquiryStatus.CUSTOMER_BOUGHT).length,
    };
    const conversion: Record<string, string> = {};

    for (const b of branches) {
      const bLeads = enquiries.filter((e) => e.branchId === b.id).length;
      const bBk = enquiries.filter((e) => e.branchId === b.id && e.status === EnquiryStatus.CUSTOMER_BOUGHT).length;
      totalLeads[b.id] = bLeads;
      totalBk[b.id] = bBk;
      conversion[b.id] = bLeads > 0 ? `${((bBk / bLeads) * 100).toFixed(2)}%` : '0.00%';
    }
    conversion['all'] =
      totalLeads['all'] > 0 ? `${((totalBk['all'] / totalLeads['all']) * 100).toFixed(2)}%` : '0.00%';

    // Mode Breakup
    const buildBreakup = (keyFn: (e: any) => string, labels: string[]) => {
      return labels.map((label) => {
        const values: Record<string, number> = {
          all: enquiries.filter((e) => keyFn(e).toUpperCase() === label.toUpperCase()).length,
        };
        for (const b of branches) {
          values[b.id] = enquiries.filter(
            (e) => e.branchId === b.id && keyFn(e).toUpperCase() === label.toUpperCase(),
          ).length;
        }
        return { label, values };
      });
    };

    const modeBreakup = buildBreakup((e) => e.purchaseMode || 'CASH', ['CASH', 'FINANCE', 'EXCHANGE']);

    // Source Breakup
    const sources = await this.prisma.leadSource.findMany({ select: { name: true } });
    const sourceNames = sources.length > 0 ? sources.map((s) => s.name.toUpperCase()) : ['WALK IN', 'TELE', 'ONLINE', 'REFERRAL'];
    const sourceBreakup = buildBreakup((e) => e.leadSource?.name || e.enquiryType || 'WALK IN', sourceNames);

    // Model Wise Leads & BK
    const modelWiseLeads = allVehicles.map((v) => {
      const values: Record<string, number> = {
        all: enquiries.filter((e) => e.quotations?.[0]?.vehicle?.code === v.code).length,
      };
      for (const b of branches) {
        values[b.id] = enquiries.filter(
          (e) => e.branchId === b.id && e.quotations?.[0]?.vehicle?.code === v.code,
        ).length;
      }
      return { label: v.name, values };
    });

    const modelWiseBk = allVehicles.map((v) => {
      const values: Record<string, number> = {
        all: enquiries.filter(
          (e) => e.quotations?.[0]?.vehicle?.code === v.code && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length,
      };
      for (const b of branches) {
        values[b.id] = enquiries.filter(
          (e) =>
            e.branchId === b.id &&
            e.quotations?.[0]?.vehicle?.code === v.code &&
            e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
      }
      return { label: v.name, values };
    });

    // Sales Executive wise BK
    const salesExecs = await this.prisma.user.findMany({
      where: { role: Role.SALES_EXEC, status: 'Active' },
      select: { id: true, name: true },
    });

    const salesExWiseBk = salesExecs.map((exec) => {
      const values: Record<string, number> = {
        all: enquiries.filter(
          (e) => e.assignedToId === exec.id && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length,
      };
      for (const b of branches) {
        values[b.id] = enquiries.filter(
          (e) =>
            e.branchId === b.id &&
            e.assignedToId === exec.id &&
            e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
      }
      return { label: exec.name, values };
    });

    // Format helper for MTD Conversion cells: "X LEADS / Y BK / Z% CONV"
    const formatConvCell = (leads: number, bk: number) => {
      const pct = leads > 0 ? Math.round((bk / leads) * 100) : 0;
      return `${leads} LEADS / ${bk} BK / ${pct}% CONV`;
    };

    // MTD Model Conversion
    const mtdModelConv = allVehicles.map((v) => {
      const allLeads = mtdEnquiries.filter((e) => e.quotations?.[0]?.vehicle?.code === v.code).length;
      const allBk = mtdEnquiries.filter(
        (e) => e.quotations?.[0]?.vehicle?.code === v.code && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
      ).length;

      const values: Record<string, string> = {
        all: formatConvCell(allLeads, allBk),
      };

      for (const b of branches) {
        const bLeads = mtdEnquiries.filter(
          (e) => e.branchId === b.id && e.quotations?.[0]?.vehicle?.code === v.code,
        ).length;
        const bBk = mtdEnquiries.filter(
          (e) =>
            e.branchId === b.id &&
            e.quotations?.[0]?.vehicle?.code === v.code &&
            e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
        values[b.id] = formatConvCell(bLeads, bBk);
      }
      return { label: v.name, values };
    });

    // MTD Sales Ex Conversion
    const mtdSalesExConv = salesExecs.map((exec) => {
      const allLeads = mtdEnquiries.filter((e) => e.assignedToId === exec.id).length;
      const allBk = mtdEnquiries.filter(
        (e) => e.assignedToId === exec.id && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
      ).length;

      const values: Record<string, string> = {
        all: formatConvCell(allLeads, allBk),
      };

      for (const b of branches) {
        const bLeads = mtdEnquiries.filter((e) => e.branchId === b.id && e.assignedToId === exec.id).length;
        const bBk = mtdEnquiries.filter(
          (e) =>
            e.branchId === b.id &&
            e.assignedToId === exec.id &&
            e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
        values[b.id] = formatConvCell(bLeads, bBk);
      }
      return { label: exec.name, values };
    });

    // MTD Source Conversion
    const mtdSourceConv = sourceNames.map((source) => {
      const match = (e: any) => (e.leadSource?.name || e.enquiryType || '').toUpperCase() === source;
      const allLeads = mtdEnquiries.filter(match).length;
      const allBk = mtdEnquiries.filter((e) => match(e) && e.status === EnquiryStatus.CUSTOMER_BOUGHT).length;

      const values: Record<string, string> = {
        all: formatConvCell(allLeads, allBk),
      };

      for (const b of branches) {
        const bLeads = mtdEnquiries.filter((e) => e.branchId === b.id && match(e)).length;
        const bBk = mtdEnquiries.filter(
          (e) => e.branchId === b.id && match(e) && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
        values[b.id] = formatConvCell(bLeads, bBk);
      }
      return { label: source, values };
    });

    // MTD Mode Conversion
    const mtdModeConv = ['CASH', 'FINANCE', 'EXCHANGE'].map((mode) => {
      const match = (e: any) =>
        mode === 'EXCHANGE'
          ? e.exchange && e.exchange !== 'No'
          : (e.purchaseMode || 'CASH').toUpperCase() === mode;

      const allLeads = mtdEnquiries.filter(match).length;
      const allBk = mtdEnquiries.filter((e) => match(e) && e.status === EnquiryStatus.CUSTOMER_BOUGHT).length;

      const values: Record<string, string> = {
        all: formatConvCell(allLeads, allBk),
      };

      for (const b of branches) {
        const bLeads = mtdEnquiries.filter((e) => e.branchId === b.id && match(e)).length;
        const bBk = mtdEnquiries.filter(
          (e) => e.branchId === b.id && match(e) && e.status === EnquiryStatus.CUSTOMER_BOUGHT,
        ).length;
        values[b.id] = formatConvCell(bLeads, bBk);
      }
      return { label: mode, values };
    });

    // Financial Breakdown for Sold Vehicles (CUSTOMER_BOUGHT)
    const boughtEnquiries = enquiries.filter((e) => e.status === EnquiryStatus.CUSTOMER_BOUGHT);
    let fUnits = 0;
    let fExShowroom = 0;
    let fRoadTax = 0;
    let fInsurance = 0;
    let fStdAccessories = 0;
    let fOnRoad = 0;

    for (const be of boughtEnquiries) {
      const q = be.quotations?.[0];
      if (q) {
        fUnits += 1;
        fExShowroom += Number(q.exShowroom || 0);
        fRoadTax += Number(q.roadTax || 0);
        fInsurance += Number(q.insurance || 0);
        fStdAccessories += 1800; // standard Pune Yash Honda accessory kit
        fOnRoad += Number(q.grandTotal || 0);
      }
    }

    // Financials by location
    const byLocation = branches.map((b) => {
      const bBought = boughtEnquiries.filter((e) => e.branchId === b.id);
      let units = 0;
      let exShowroom = 0;
      let roadTax = 0;
      let insurance = 0;
      let stdAccessories = 0;
      let onRoad = 0;

      for (const be of bBought) {
        const q = be.quotations?.[0];
        if (q) {
          units += 1;
          exShowroom += Number(q.exShowroom || 0);
          roadTax += Number(q.roadTax || 0);
          insurance += Number(q.insurance || 0);
          stdAccessories += 1800;
          onRoad += Number(q.grandTotal || 0);
        }
      }

      return {
        id: b.id,
        code: b.code,
        name: b.name,
        units,
        exShowroom,
        roadTax,
        insurance,
        stdAccessories,
        onRoad,
      };
    });

    // Financials by Category
    const categoryMap: Record<string, { units: number; onRoad: number }> = {
      SCOOTERS: { units: 0, onRoad: 0 },
      MC: { units: 0, onRoad: 0 },
      'BIG BIKES': { units: 0, onRoad: 0 },
    };

    for (const be of boughtEnquiries) {
      const q = be.quotations?.[0];
      const cat = (q?.vehicle?.category || 'Scooter').toUpperCase();
      const normCat = cat.includes('MC') || cat.includes('MOTOR') ? 'MC' : (cat.includes('BIG') ? 'BIG BIKES' : 'SCOOTERS');
      categoryMap[normCat].units += 1;
      categoryMap[normCat].onRoad += Number(q?.grandTotal || 0);
    }

    const byCategory = Object.entries(categoryMap).map(([category, val]) => ({
      category,
      units: val.units,
      onRoad: val.onRoad,
    }));

    // Financials by Mode
    const modeMap: Record<string, { units: number; onRoad: number }> = {
      CASH: { units: 0, onRoad: 0 },
      FINANCE: { units: 0, onRoad: 0 },
      EXCHANGE: { units: 0, onRoad: 0 },
    };

    for (const be of boughtEnquiries) {
      const q = be.quotations?.[0];
      const isEx = be.exchange && be.exchange !== 'No';
      const mKey = isEx ? 'EXCHANGE' : ((be.purchaseMode || 'CASH').toUpperCase() === 'FINANCE' ? 'FINANCE' : 'CASH');
      modeMap[mKey].units += 1;
      modeMap[mKey].onRoad += Number(q?.grandTotal || 0);
    }

    const byMode = Object.entries(modeMap).map(([mode, val]) => ({
      mode,
      units: val.units,
      onRoad: val.onRoad,
    }));

    // Financials by Model
    const byModel = allVehicles
      .map((v) => {
        const vBought = boughtEnquiries.filter((e) => e.quotations?.[0]?.vehicle?.code === v.code);
        let units = 0;
        let exShowroom = 0;
        let roadTax = 0;
        let insurance = 0;
        let stdAccessories = 0;
        let onRoad = 0;

        for (const be of vBought) {
          const q = be.quotations?.[0];
          if (q) {
            units += 1;
            exShowroom += Number(q.exShowroom || 0);
            roadTax += Number(q.roadTax || 0);
            insurance += Number(q.insurance || 0);
            stdAccessories += 1800;
            onRoad += Number(q.grandTotal || 0);
          }
        }

        const unitPrice = units > 0 ? Math.round(onRoad / units) : 0;

        return {
          modelName: v.name,
          category: v.category,
          units,
          unitPrice,
          exShowroom,
          roadTax,
          insurance,
          stdAccessories,
          onRoad,
        };
      })
      .filter((m) => m.units > 0);

    return {
      success: true,
      data: {
        date: targetDate.toISOString().slice(0, 10),
        period,
        monthStart: monthStartDate.toISOString().slice(0, 10),
        branches,
        asOnDate: {
          totalLeads,
          totalBk,
          conversion,
        },
        modeBreakup,
        sourceBreakup,
        modelWiseLeads,
        modelWiseBk,
        salesExWiseBk,
        mtdModelConv,
        mtdSalesExConv,
        mtdSourceConv,
        mtdModeConv,
        financials: {
          totals: {
            units: fUnits,
            exShowroom: fExShowroom,
            roadTax: fRoadTax,
            insurance: fInsurance,
            stdAccessories: fStdAccessories,
            onRoad: fOnRoad,
          },
          byLocation,
          byCategory,
          byMode,
          byModel,
        },
      },
    };
  }
}


