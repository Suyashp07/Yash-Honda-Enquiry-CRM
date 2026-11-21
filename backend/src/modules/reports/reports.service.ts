import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EnquiryStatus, Role } from '@prisma/client';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  private getBranchFilter(user: any, branchId?: string) {
    if (user.role === Role.SUPER_ADMIN || user.role === Role.OWNER) {
      return branchId ? { branchId } : {};
    }
    return { branchId: branchId || { in: user.assignedBranchIds } };
  }

  async getPendingLeads(user: any, branchId?: string) {
    return this.prisma.enquiry.findMany({
      where: {
        ...this.getBranchFilter(user, branchId),
        status: EnquiryStatus.ACTIVE,
      },
      include: {
        customer: true,
        branch: true,
        assignedTo: { select: { id: true, name: true, mobile: true } },
        followUps: { where: { completedAt: null }, take: 1, orderBy: { scheduledAt: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getLostLeads(user: any, branchId?: string) {
    return this.prisma.enquiry.findMany({
      where: {
        ...this.getBranchFilter(user, branchId),
        status: EnquiryStatus.CLOSED,
      },
      include: {
        customer: true,
        branch: true,
        assignedTo: { select: { id: true, name: true, mobile: true } },
        statusHistory: { orderBy: { changedAt: 'desc' }, take: 1 },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async getFinanceLeads(user: any, branchId?: string) {
    return this.prisma.enquiry.findMany({
      where: {
        ...this.getBranchFilter(user, branchId),
        purchaseMode: 'Finance',
      },
      include: {
        customer: true,
        branch: true,
        financier: true,
        quotations: { take: 1, orderBy: { createdAt: 'desc' } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getExchangeLeads(user: any, branchId?: string) {
    return this.prisma.enquiry.findMany({
      where: {
        ...this.getBranchFilter(user, branchId),
        exchange: { in: ['Yes', 'Yes & Print'] },
      },
      include: {
        customer: true,
        branch: true,
        assignedTo: { select: { id: true, name: true, mobile: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}

