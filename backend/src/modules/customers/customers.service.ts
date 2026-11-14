import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCustomerDto, UpdateCustomerDto } from './dto/customer.dto';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async findAll(search?: string) {
    return this.prisma.customer.findMany({
      where: search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { mobile: { contains: search } },
            ],
          }
        : undefined,
      include: {
        area: true,
        _count: {
          select: { enquiries: true },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take: 50,
    });
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        area: true,
        enquiries: {
          include: {
            branch: true,
            quotations: {
              include: {
                vehicle: true,
              },
            },
            followUps: true,
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!customer) {
      throw new NotFoundException(`Customer with ID ${id} not found`);
    }
    return customer;
  }

  async findOrCreate(dto: CreateCustomerDto) {
    const existing = await this.prisma.customer.findFirst({
      where: { mobile: dto.mobile },
    });

    if (existing) {
      return this.prisma.customer.update({
        where: { id: existing.id },
        data: {
          name: dto.name || existing.name,
          email: dto.email ?? existing.email,
          address: dto.address ?? existing.address,
          areaId: dto.areaId ?? existing.areaId,
        },
        include: { area: true },
      });
    }

    return this.prisma.customer.create({
      data: {
        name: dto.name,
        mobile: dto.mobile,
        email: dto.email,
        dob: dto.dob ? new Date(dto.dob) : undefined,
        anniversary: dto.anniversary ? new Date(dto.anniversary) : undefined,
        address: dto.address,
        areaId: dto.areaId,
      },
      include: { area: true },
    });
  }

  async update(id: string, dto: UpdateCustomerDto) {
    await this.findOne(id);
    return this.prisma.customer.update({
      where: { id },
      data: {
        ...dto,
        dob: dto.dob ? new Date(dto.dob) : undefined,
        anniversary: dto.anniversary ? new Date(dto.anniversary) : undefined,
      },
      include: { area: true },
    });
  }
}
