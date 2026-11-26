import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateBranchDto, UpdateBranchDto } from './dto/branch.dto';

@Injectable()
export class BranchesService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.branch.findMany({
      orderBy: { name: 'asc' },
      include: {
        _count: {
          select: {
            userBranches: true,
            enquiries: true,
            quotations: true,
          },
        },
      },
    });
  }

  async findOne(id: string) {
    const branch = await this.prisma.branch.findUnique({
      where: { id },
      include: {
        userBranches: {
          include: {
            user: {
              select: { id: true, name: true, mobile: true, role: true },
            },
          },
        },
      },
    });
    if (!branch) {
      throw new NotFoundException(`Branch with ID ${id} not found`);
    }
    return branch;
  }

  async create(dto: CreateBranchDto) {
    const existing = await this.prisma.branch.findUnique({
      where: { code: dto.code },
    });
    if (existing) {
      throw new ConflictException(`Branch with code ${dto.code} already exists`);
    }
    return this.prisma.branch.create({
      data: dto,
    });
  }

  async update(id: string, dto: UpdateBranchDto) {
    await this.findOne(id);
    return this.prisma.branch.update({
      where: { id },
      data: dto,
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    const [userCount, enquiryCount, quoteCount] = await Promise.all([
      this.prisma.userBranch.count({ where: { branchId: id } }),
      this.prisma.enquiry.count({ where: { branchId: id } }),
      this.prisma.quotation.count({ where: { branchId: id } }),
    ]);
    if (userCount > 0 || enquiryCount > 0 || quoteCount > 0) {
      throw new BadRequestException(
        'Cannot delete branch because it has linked users, enquiries, or quotations. Mark it Inactive instead.',
      );
    }
    return this.prisma.branch.delete({
      where: { id },
    });
  }
}

