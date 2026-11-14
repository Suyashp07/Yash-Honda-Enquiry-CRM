import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateUserDto, UpdateUserDto } from './dto/user.dto';
import { Role } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll(branchId?: string, role?: Role) {
    return this.prisma.user.findMany({
      where: {
        role: role ? role : undefined,
        userBranches: branchId
          ? {
              some: { branchId },
            }
          : undefined,
      },
      select: {
        id: true,
        name: true,
        mobile: true,
        role: true,
        status: true,
        createdAt: true,
        userBranches: {
          select: {
            branch: {
              select: { id: true, code: true, name: true },
            },
          },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        mobile: true,
        role: true,
        status: true,
        createdAt: true,
        userBranches: {
          select: {
            branch: {
              select: { id: true, code: true, name: true, address: true },
            },
          },
        },
      },
    });
    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
    return user;
  }

  async create(dto: CreateUserDto) {
    const existing = await this.prisma.user.findUnique({
      where: { mobile: dto.mobile },
    });
    if (existing) {
      throw new ConflictException(`User with mobile ${dto.mobile} already exists`);
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: dto.name,
          mobile: dto.mobile,
          passwordHash,
          role: dto.role,
        },
      });

      if (dto.branchIds && dto.branchIds.length > 0) {
        await tx.userBranch.createMany({
          data: dto.branchIds.map((branchId) => ({
            userId: user.id,
            branchId,
          })),
        });
      }

      return tx.user.findUnique({
        where: { id: user.id },
        select: {
          id: true,
          name: true,
          mobile: true,
          role: true,
          status: true,
          userBranches: {
            select: { branch: true },
          },
        },
      });
    });
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.findOne(id);

    return this.prisma.$transaction(async (tx) => {
      const updateData: any = {};
      if (dto.name !== undefined) updateData.name = dto.name;
      if (dto.role !== undefined) updateData.role = dto.role;
      if (dto.status !== undefined) updateData.status = dto.status;
      if (dto.password) {
        updateData.passwordHash = await bcrypt.hash(dto.password, 10);
      }

      await tx.user.update({
        where: { id },
        data: updateData,
      });

      if (dto.branchIds !== undefined) {
        await tx.userBranch.deleteMany({
          where: { userId: id },
        });

        if (dto.branchIds.length > 0) {
          await tx.userBranch.createMany({
            data: dto.branchIds.map((branchId) => ({
              userId: id,
              branchId,
            })),
          });
        }
      }

      return tx.user.findUnique({
        where: { id },
        select: {
          id: true,
          name: true,
          mobile: true,
          role: true,
          status: true,
          userBranches: {
            select: { branch: true },
          },
        },
      });
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    return this.prisma.user.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }
}

