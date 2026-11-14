import { Injectable, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EnquiryStatus, Role } from '@prisma/client';

@Injectable()
export class AnalyticsService {
  constructor(private prisma: PrismaService) {}

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

  async getFloorDashboard(user: any, branchId?: string) {
    const todayDates = this.getDates('today');

    const branchFilter =
      user.role === Role.SUPER_ADMIN
        ? branchId
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
    });

    const activeBranchIds = branches.map((b) => b.id);

    // Reps assigned to these branches
    const salesReps = await this.prisma.user.findMany({
      where: {
        role: Role.SALES_EXEC,
        status: 'Active',
        userBranches: { some: { branchId: { in: activeBranchIds } } },
      },
      select: {
        id: true,
        name: true,
        mobile: true,
        userBranches: { select: { branch: { select: { id: true, code: true, name: true } } } },
      },
    });

    // Today's enquiries
    const todayEnquiries = await this.prisma.enquiry.findMany({
      where: {
        branchId: { in: activeBranchIds },
        createdAt: todayDates,
      },
      select: {
        id: true,
        branchId: true,
        enquiryType: true,
        status: true,
        assignedToId: true,
      },
    });

    const totalToday = todayEnquiries.length;
    const walkInsToday = todayEnquiries.filter((e) => e.enquiryType?.toLowerCase().includes('walk')).length;
    const teleToday = todayEnquiries.filter((e) => e.enquiryType?.toLowerCase().includes('tele')).length;
    const bookedToday = todayEnquiries.filter((e) => e.status === EnquiryStatus.CUSTOMER_BOUGHT).length;

    // Rep workload mapping
    const repStats = salesReps.map((rep) => {
      const repEnquiriesToday = todayEnquiries.filter((e) => e.assignedToId === rep.id);
      return {
        id: rep.id,
        name: rep.name,
        mobile: rep.mobile,
        branches: rep.userBranches.map((ub) => ub.branch.code),
        enquiriesTodayCount: repEnquiriesToday.length,
        status: repEnquiriesToday.length > 0 ? 'Busy' : 'Idle',
      };
    });

    return {
      date: new Date().toISOString().split('T')[0],
      summary: {
        totalEnquiriesToday: totalToday,
        walkInsToday,
        telephonicToday: teleToday,
        bookingsToday: bookedToday,
        activeRepsCount: salesReps.length,
      },
      branches,
      reps: repStats,
    };
  }

  async getExecutiveSummary(user: any, branchId?: string, range: string = 'today') {
    const dateRange = this.getDates(range);

    const branchCondition: any =
      user.role === Role.SUPER_ADMIN
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
      user.role === Role.SUPER_ADMIN
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
      user.role === Role.SUPER_ADMIN
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
}

