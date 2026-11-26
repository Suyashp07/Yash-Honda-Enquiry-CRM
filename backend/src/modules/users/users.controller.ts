import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CreateUserDto, UpdateUserDto } from './dto/user.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '@prisma/client';

@ApiTags('users')
@Controller('users')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles(Role.OWNER, Role.SUPER_ADMIN, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'List users with optional branch and role filters' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'role', required: false, enum: Role })
  findAll(@Query('branchId') branchId?: string, @Query('role') role?: Role) {
    return this.usersService.findAll(branchId, role);
  }

  @Get('permissions')
  @Roles(Role.OWNER, Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Get RBAC permissions matrix for all roles' })
  getPermissions() {
    return this.usersService.getRolePermissions();
  }

  @Put('permissions/:role')
  @Roles(Role.OWNER, Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update RBAC permissions for a role (Super Admin only)' })
  savePermissions(@Param('role') role: string, @Body() body: any) {
    return this.usersService.saveRolePermissions(role, body.permissions ?? body);
  }

  @Get(':id')
  @Roles(Role.OWNER, Role.SUPER_ADMIN, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'Get user profile and branch assignments' })
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Post()
  @Roles(Role.OWNER, Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create user with multi-branch assignment (Super Admin only)' })
  create(@Body() dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  @Put(':id')
  @Roles(Role.OWNER, Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update user, password or branch assignments (Super Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateUserDto, @CurrentUser() currentUser: any) {
    return this.usersService.update(id, dto, currentUser);
  }

  @Delete(':id')
  @Roles(Role.OWNER, Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Deactivate staff account (Super Admin only)' })
  remove(@Param('id') id: string, @CurrentUser() currentUser: any) {
    return this.usersService.remove(id, currentUser);
  }
}

