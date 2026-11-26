import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
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

  async update(id: string, dto: UpdateUserDto, currentUser?: any) {
    const target = await this.findOne(id);

    if (currentUser && currentUser.id === id) {
      if (dto.status === 'Inactive') {
        throw new BadRequestException('You cannot deactivate your own account.');
      }
      if (dto.role && dto.role !== target.role && dto.role !== Role.OWNER && dto.role !== Role.SUPER_ADMIN) {
        throw new BadRequestException('You cannot demote your own administrator role.');
      }
    }

    const isAdminRole = target.role === Role.SUPER_ADMIN || target.role === Role.OWNER;
    const isDemotingOrDeactivating =
      dto.status === 'Inactive' ||
      (dto.role && dto.role !== Role.SUPER_ADMIN && dto.role !== Role.OWNER);
    if (isAdminRole && isDemotingOrDeactivating) {
      const activeAdmins = await this.prisma.user.count({
        where: {
          role: { in: [Role.SUPER_ADMIN, Role.OWNER] },
          status: 'Active',
        },
      });
      if (activeAdmins <= 1) {
        throw new BadRequestException('Cannot deactivate or demote the last active administrator.');
      }
    }

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

  async remove(id: string, currentUser?: any) {
    const target = await this.findOne(id);
    if (currentUser && currentUser.id === id) {
      throw new BadRequestException('You cannot deactivate your own account.');
    }
    if (target.role === Role.SUPER_ADMIN || target.role === Role.OWNER) {
      const activeAdmins = await this.prisma.user.count({
        where: {
          role: { in: [Role.SUPER_ADMIN, Role.OWNER] },
          status: 'Active',
        },
      });
      if (activeAdmins <= 1) {
        throw new BadRequestException('Cannot deactivate the last active administrator.');
      }
    }
    return this.prisma.user.update({
      where: { id },
      data: { status: 'Inactive' },
    });
  }

  async getRolePermissions() {
    const defaultPermissions: Record<string, Record<string, Record<string, boolean>>> = {
      'Accounts': {
        'Leads': { view: true, create: false, edit: true, delete: false, export: false, send: false },
        'Quotes': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Follow-ups': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Dashboard': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Reports': { view: true, create: false, edit: false, delete: false, export: true, send: false },
        'Masters': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Users': { view: false, create: false, edit: false, delete: false, export: false, send: false },
      },
      'Branch Manager': {
        'Leads': { view: true, create: true, edit: true, delete: true, export: false, send: false },
        'Quotes': { view: true, create: true, edit: true, delete: false, export: false, send: true },
        'Follow-ups': { view: true, create: true, edit: true, delete: true, export: false, send: false },
        'Dashboard': { view: true, create: false, edit: false, delete: false, export: false, send: false },
        'Reports': { view: true, create: false, edit: false, delete: false, export: true, send: false },
        'Masters': { view: true, create: false, edit: false, delete: false, export: false, send: false },
        'Users': { view: false, create: false, edit: false, delete: false, export: false, send: false },
      },
      'Sales Executive': {
        'Leads': { view: true, create: true, edit: true, delete: false, export: false, send: false },
        'Quotes': { view: true, create: true, edit: true, delete: false, export: false, send: true },
        'Follow-ups': { view: true, create: true, edit: true, delete: false, export: false, send: false },
        'Dashboard': { view: true, create: false, edit: false, delete: false, export: false, send: false },
        'Reports': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Masters': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Users': { view: false, create: false, edit: false, delete: false, export: false, send: false },
      },
      'Owner': {
        'Leads': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Quotes': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Follow-ups': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Dashboard': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Reports': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Masters': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Users': { view: true, create: true, edit: true, delete: true, export: true, send: true },
      },
      'Super Admin': {
        'Leads': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Quotes': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Follow-ups': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Dashboard': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Reports': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Masters': { view: true, create: true, edit: true, delete: true, export: true, send: true },
        'Users': { view: true, create: true, edit: true, delete: true, export: true, send: true },
      },
      'Tele-caller': {
        'Leads': { view: true, create: true, edit: false, delete: false, export: false, send: false },
        'Quotes': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Follow-ups': { view: true, create: true, edit: true, delete: false, export: false, send: false },
        'Dashboard': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Reports': { view: true, create: false, edit: false, delete: false, export: true, send: false },
        'Masters': { view: false, create: false, edit: false, delete: false, export: false, send: false },
        'Users': { view: false, create: false, edit: false, delete: false, export: false, send: false },
      },
    };

    const saved = await this.prisma.rolePermission.findMany();
    const result = { ...defaultPermissions };
    for (const item of saved) {
      if (item.permissions && typeof item.permissions === 'object') {
        result[item.role] = item.permissions as Record<string, Record<string, boolean>>;
      }
    }
    return result;
  }

  async saveRolePermissions(role: string, permissions: any) {
    return this.prisma.rolePermission.upsert({
      where: { role },
      update: { permissions },
      create: { role, permissions },
    });
  }
}

