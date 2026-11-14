import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '@prisma/client';

@ApiTags('reports')
@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('pending')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Report: Active pending enquiries awaiting action' })
  @ApiQuery({ name: 'branchId', required: false })
  getPendingLeads(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.reportsService.getPendingLeads(user, branchId);
  }

  @Get('lost')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Report: Closed/Lost leads with history reasons' })
  @ApiQuery({ name: 'branchId', required: false })
  getLostLeads(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.reportsService.getLostLeads(user, branchId);
  }

  @Get('finance')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Report: Finance leads and designated financier partners' })
  @ApiQuery({ name: 'branchId', required: false })
  getFinanceLeads(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.reportsService.getFinanceLeads(user, branchId);
  }

  @Get('exchange')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Report: Old two-wheeler exchange leads' })
  @ApiQuery({ name: 'branchId', required: false })
  getExchangeLeads(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.reportsService.getExchangeLeads(user, branchId);
  }
}
