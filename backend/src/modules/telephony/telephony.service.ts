import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { InitiateCallDto } from './dto/telephony.dto';
import { Role } from '@prisma/client';

@Injectable()
export class TelephonyService {
  constructor(
    private prisma: PrismaService,
    private configService: ConfigService,
  ) {}

  async initiateCall(dto: InitiateCallDto, user: any) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
      include: { customer: true, branch: true },
    });

    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    if (user.role !== Role.SUPER_ADMIN && !user.assignedBranchIds.includes(enquiry.branchId)) {
      throw new ForbiddenException('Access denied to call customer for this branch');
    }

    if (!user.mobile || !enquiry.customer.mobile) {
      throw new BadRequestException('Employee and customer mobile numbers are required');
    }

    // Call record creation
    const call = await this.prisma.call.create({
      data: {
        enquiryId: enquiry.id,
        employeeId: user.id,
        branchId: enquiry.branchId,
        employeePhone: user.mobile,
        customerPhone: enquiry.customer.mobile,
        status: 'initiated',
        providerCallId: `exotel_mock_${Date.now()}`,
      },
    });

    return {
      message: 'Callback initiated. Sales rep phone will ring first, then customer will be connected.',
      callId: call.id,
      status: call.status,
      employeePhone: call.employeePhone,
      customerPhone: call.customerPhone,
    };
  }

  async findAll(user: any, branchId?: string) {
    const where: any = {};
    if (user.role !== Role.SUPER_ADMIN) {
      if (branchId) {
        where.branchId = branchId;
      } else {
        where.branchId = { in: user.assignedBranchIds };
      }
    } else if (branchId) {
      where.branchId = branchId;
    }

    return this.prisma.call.findMany({
      where,
      include: {
        enquiry: {
          include: { customer: true },
        },
        employee: {
          select: { id: true, name: true, mobile: true },
        },
        branch: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async getRecordingUrl(callId: string, user: any) {
    const call = await this.prisma.call.findUnique({
      where: { id: callId },
    });

    if (!call) {
      throw new NotFoundException(`Call with ID ${callId} not found`);
    }

    if (user.role !== Role.SUPER_ADMIN && !user.assignedBranchIds.includes(call.branchId)) {
      throw new ForbiddenException('Access denied to access call recording');
    }

    const r2PublicUrl = this.configService.get<string>('R2_PUBLIC_URL') || 'https://storage.yashhonda.com';
    return {
      callId: call.id,
      recordingUrl: call.recordingR2Key ? `${r2PublicUrl}/${call.recordingR2Key}` : null,
      recordingStatus: call.recordingStatus || 'ready',
    };
  }
}
