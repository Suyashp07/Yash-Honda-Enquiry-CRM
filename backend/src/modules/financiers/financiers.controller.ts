import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { FinanciersService } from './financiers.service';
import { CreateFinancierDto, UpdateFinancierDto } from './dto/financier.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '@prisma/client';

@ApiTags('financiers')
@Controller('financiers')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class FinanciersController {
  constructor(private readonly financiersService: FinanciersService) {}

  @Get()
  @ApiOperation({ summary: 'List all partner financiers' })
  findAll() {
    return this.financiersService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get financier details by ID' })
  findOne(@Param('id') id: string) {
    return this.financiersService.findOne(id);
  }

  @Post()
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Create new financier partner (Super Admin only)' })
  create(@Body() dto: CreateFinancierDto) {
    return this.financiersService.create(dto);
  }

  @Put(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Update financier details (Super Admin only)' })
  update(@Param('id') id: string, @Body() dto: UpdateFinancierDto) {
    return this.financiersService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.SUPER_ADMIN)
  @ApiOperation({ summary: 'Soft delete financier (Super Admin only)' })
  remove(@Param('id') id: string) {
    return this.financiersService.remove(id);
  }
}

