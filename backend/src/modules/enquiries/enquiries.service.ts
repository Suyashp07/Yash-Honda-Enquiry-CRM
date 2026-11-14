import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { QuotationsService } from '../quotations/quotations.service';
import { CreateEnquiryDto, UpdateEnquiryStatusDto, AssignEnquiryDto } from './dto/enquiry.dto';
import { EnquiryStatus, Role } from '@prisma/client';

@Injectable()
export class EnquiriesService {
  constructor(
    private prisma: PrismaService,
    private quotationsService: QuotationsService,
  ) {}

  async create(dto: CreateEnquiryDto, userId: string) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Resolve or create customer
      let customerId = dto.customerId;
      if (!customerId) {
        if (!dto.customer || !dto.customer.mobile || !dto.customer.name) {
          throw new BadRequestException('Customer details (name & mobile) are required');
        }

        let customer = await tx.customer.findFirst({
          where: { mobile: dto.customer.mobile },
        });

        if (!customer) {
          customer = await tx.customer.create({
            data: {
              name: dto.customer.name,
              mobile: dto.customer.mobile,
              email: dto.customer.email,
              address: dto.customer.address,
              areaId: dto.customer.areaId,
            },
          });
        }
        customerId = customer.id;
      }

      // 2. Create Enquiry
      const enquiry = await tx.enquiry.create({
        data: {
          customerId,
          branchId: dto.branchId,
          createdById: userId,
          assignedToId: dto.assignedToId || userId,
          leadSourceId: dto.leadSourceId,
          enquiryType: dto.enquiryType,
          purchaseMode: dto.purchaseMode,
          financierId: dto.financierId,
          exchange: dto.exchange || 'No',
          buyingWhen: dto.buyingWhen,
          remarks: dto.remarks,
          status: EnquiryStatus.ACTIVE,
          statusHistory: {
            create: {
              toStatus: EnquiryStatus.ACTIVE,
            },
          },
        },
      });

      // 3. If quotation payload provided (Unified Enquiry Flow), create Quotation atomically
      let quotation = null;
      if (dto.quotation) {
        quotation = await this.quotationsService.create(
          {
            enquiryId: enquiry.id,
            branchId: dto.branchId,
            vehicleId: dto.quotation.vehicleId,
            colourName: dto.quotation.colourName,
            purchaseMode: dto.purchaseMode,
            accessories: dto.quotation.accessories,
          },
          tx,
        );
      }

      return tx.enquiry.findUnique({
        where: { id: enquiry.id },
        include: {
          customer: true,
          branch: true,
          createdBy: { select: { id: true, name: true, mobile: true } },
          assignedTo: { select: { id: true, name: true, mobile: true } },
          leadSource: true,
          financier: true,
          quotations: {
            include: {
              vehicle: true,
              items: true,
              accessories: { include: { accessory: true } },
            },
          },
          statusHistory: { orderBy: { changedAt: 'desc' } },
        },
      });
    });
  }

  async findAll(user: any, filters: {
    branchId?: string;
    status?: EnquiryStatus;
    assignedToId?: string;
    search?: string;
    from?: string;
    to?: string;
  }) {
    const where: any = {};

    // Branch scoping
    if (user.role !== Role.SUPER_ADMIN) {
      if (filters.branchId) {
        if (!user.assignedBranchIds.includes(filters.branchId)) {
          throw new ForbiddenException('Access denied to this branch');
        }
        where.branchId = filters.branchId;
      } else {
        where.branchId = { in: user.assignedBranchIds };
      }
    } else if (filters.branchId) {
      where.branchId = filters.branchId;
    }

    if (filters.status) {
      where.status = filters.status;
    }

    if (filters.assignedToId) {
      where.assignedToId = filters.assignedToId;
    }

    if (filters.from || filters.to) {
      where.createdAt = {};
      if (filters.from) where.createdAt.gte = new Date(filters.from);
      if (filters.to) where.createdAt.lte = new Date(filters.to);
    }

    if (filters.search) {
      where.customer = {
        OR: [
          { name: { contains: filters.search, mode: 'insensitive' } },
          { mobile: { contains: filters.search } },
        ],
      };
    }

    return this.prisma.enquiry.findMany({
      where,
      include: {
        customer: true,
        branch: true,
        assignedTo: { select: { id: true, name: true, mobile: true } },
        quotations: {
          include: { vehicle: true },
          take: 1,
          orderBy: { createdAt: 'desc' },
        },
        _count: {
          select: { followUps: true, calls: true, quotations: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async findOne(id: string, user: any) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id },
      include: {
        customer: { include: { area: true } },
        branch: true,
        createdBy: { select: { id: true, name: true, mobile: true } },
        assignedTo: { select: { id: true, name: true, mobile: true } },
        leadSource: true,
        financier: true,
        quotations: {
          include: {
            vehicle: true,
            items: true,
            accessories: { include: { accessory: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
        followUps: { orderBy: { scheduledAt: 'desc' } },
        statusHistory: { orderBy: { changedAt: 'desc' } },
        calls: { orderBy: { createdAt: 'desc' } },
        communications: { orderBy: { createdAt: 'desc' } },
      },
    });

    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${id} not found`);
    }

    if (user.role !== Role.SUPER_ADMIN && !user.assignedBranchIds.includes(enquiry.branchId)) {
      throw new ForbiddenException('Access denied: You are not assigned to this enquiry branch');
    }

    return enquiry;
  }

  async updateStatus(id: string, dto: UpdateEnquiryStatusDto, user: any) {
    const enquiry = await this.findOne(id, user);

    if (enquiry.status === dto.status) {
      return enquiry;
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.enquiryStatusHistory.create({
        data: {
          enquiryId: id,
          fromStatus: enquiry.status,
          toStatus: dto.status,
        },
      });

      return tx.enquiry.update({
        where: { id },
        data: {
          status: dto.status,
          remarks: dto.remarks ? `${enquiry.remarks || ''}\n${dto.remarks}`.trim() : enquiry.remarks,
        },
        include: {
          statusHistory: { orderBy: { changedAt: 'desc' } },
        },
      });
    });
  }

  async assign(id: string, dto: AssignEnquiryDto, user: any) {
    const enquiry = await this.findOne(id, user);

    // Verify assigned user belongs to that branch
    const targetUserBranch = await this.prisma.userBranch.findUnique({
      where: {
        userId_branchId: {
          userId: dto.assignedToId,
          branchId: enquiry.branchId,
        },
      },
    });

    if (!targetUserBranch) {
      throw new BadRequestException('Assigned executive does not belong to this enquiry branch');
    }

    return this.prisma.enquiry.update({
      where: { id },
      data: {
        assignedToId: dto.assignedToId,
      },
      include: {
        assignedTo: { select: { id: true, name: true, mobile: true } },
      },
    });
  }
}
