import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AccessoriesService } from './accessories.service';
import { CreateAccessoryDto, UpdateAccessoryDto } from './dto/accessory.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('accessories')
@Controller('accessories')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AccessoriesController {
  constructor(private readonly accessoriesService: AccessoriesService) {}

  @Get()
  @ApiOperation({ summary: 'List all accessories with price editability flags' })
  findAll() {
    return this.accessoriesService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get accessory details by ID' })
  findOne(@Param('id') id: string) {
    return this.accessoriesService.findOne(id);
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create new accessory (Super Admin only)' })
  create(@Body() dto: CreateAccessoryDto) {
    return this.accessoriesService.create(dto);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update accessory (Super Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateAccessoryDto) {
    return this.accessoriesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete accessory (Super Admin only)' })
  remove(@Param('id') id: string) {
    return this.accessoriesService.remove(id);
  }
}

