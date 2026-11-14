import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { LeadSourcesService } from './lead-sources.service';
import { CreateLeadSourceDto, UpdateLeadSourceDto } from './dto/lead-source.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('lead-sources')
@Controller('lead-sources')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class LeadSourcesController {
  constructor(private readonly leadSourcesService: LeadSourcesService) {}

  @Get()
  @ApiOperation({ summary: 'List all enquiry lead sources' })
  findAll() {
    return this.leadSourcesService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get lead source details by ID' })
  findOne(@Param('id') id: string) {
    return this.leadSourcesService.findOne(id);
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create new lead source (Super Admin only)' })
  create(@Body() dto: CreateLeadSourceDto) {
    return this.leadSourcesService.create(dto);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update lead source (Super Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateLeadSourceDto) {
    return this.leadSourcesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete lead source (Super Admin only)' })
  remove(@Param('id') id: string) {
    return this.leadSourcesService.remove(id);
  }
}

