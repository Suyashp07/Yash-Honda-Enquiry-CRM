import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateFollowUpDto, CompleteFollowUpDto } from './dto/follow-up.dto';
import { Role } from '@prisma/client';

@Injectable()
export class FollowUpsService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateFollowUpDto) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
    });
    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    return this.prisma.followUp.create({
      data: {
        enquiryId: dto.enquiryId,
        scheduledAt: new Date(dto.scheduledAt),
        remarks: dto.remarks,
      },
      include: {
        enquiry: {
          include: { customer: true, branch: true },
        },
      },
    });
  }

  async complete(id: string, dto: CompleteFollowUpDto) {
    const followUp = await this.prisma.followUp.findUnique({
      where: { id },
    });
    if (!followUp) {
      throw new NotFoundException(`FollowUp with ID ${id} not found`);
    }

    return this.prisma.followUp.update({
      where: { id },
      data: {
        completedAt: new Date(),
        remarks: dto.remarks ? `${followUp.remarks || ''}\nCompleted: ${dto.remarks}`.trim() : followUp.remarks,
      },
      include: {
        enquiry: {
          include: { customer: true, branch: true },
        },
      },
    });
  }

  async findAll(user: any, scope?: 'today' | 'overdue' | 'upcoming' | 'completed', branchId?: string) {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const where: any = {
      enquiry: {},
    };

    if (user.role !== Role.SUPER_ADMIN && user.role !== Role.OWNER) {
      if (branchId) {
        where.enquiry.branchId = branchId;
      } else {
        where.enquiry.branchId = { in: user.assignedBranchIds };
      }
    } else if (branchId) {
      where.enquiry.branchId = branchId;
    }

    if (scope === 'today') {
      where.completedAt = null;
      where.scheduledAt = { gte: startOfToday, lte: endOfToday };
    } else if (scope === 'overdue') {
      where.completedAt = null;
      where.scheduledAt = { lt: startOfToday };
    } else if (scope === 'upcoming') {
      where.completedAt = null;
      where.scheduledAt = { gt: endOfToday };
    } else if (scope === 'completed') {
      where.completedAt = { not: null };
    }

    return this.prisma.followUp.findMany({
      where,
      include: {
        enquiry: {
          include: {
            customer: true,
            branch: true,
            assignedTo: { select: { id: true, name: true, mobile: true } },
          },
        },
      },
      orderBy: { scheduledAt: 'asc' },
      take: 100,
    });
  }
}

