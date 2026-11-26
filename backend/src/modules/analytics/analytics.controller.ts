import { Controller, Get, Post, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '@prisma/client';

@ApiTags('analytics')
@Controller('analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('floor')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Floor Dashboard live rep workload and today enquiry metrics (RIGID)' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'date', required: false })
  getFloorDashboard(
    @CurrentUser() user: any,
    @Query('branchId') branchId?: string,
    @Query('date') date?: string,
  ) {
    return this.analyticsService.getFloorDashboard(user, branchId, date);
  }

  @Post('floor/session')
  @Roles(Role.SUPER_ADMIN, Role.OWNER, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'Broadcast active live floor session / in-progress enquiry drafting' })
  upsertFloorSession(@CurrentUser() user: any, @Body() data: any) {
    return this.analyticsService.upsertFloorSession(user, data);
  }

  @Delete('floor/session/:salesExecId')
  @Roles(Role.SUPER_ADMIN, Role.OWNER, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'End active live floor session' })
  removeFloorSession(@CurrentUser() user: any, @Param('salesExecId') salesExecId: string) {
    return this.analyticsService.removeFloorSession(user, salesExecId);
  }

  @Get('summary/executive')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Dealership Executive Summary KPIs on-the-fly (RIGID)' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'range', required: false, enum: ['today', 'mtd', '30d'] })
  getExecutiveSummary(
    @CurrentUser() user: any,
    @Query('branchId') branchId?: string,
    @Query('range') range: string = 'today',
  ) {
    return this.analyticsService.getExecutiveSummary(user, branchId, range);
  }

  @Get('summary/financial')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Dealership Financial Summary on-the-fly (RIGID)' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'range', required: false, enum: ['today', 'mtd', '30d'] })
  getFinancialSummary(
    @CurrentUser() user: any,
    @Query('branchId') branchId?: string,
    @Query('range') range: string = 'today',
  ) {
    return this.analyticsService.getFinancialSummary(user, branchId, range);
  }

  @Get('summary/matrix')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Dealership Matrix cross-tabulation by Branch x Vehicle (RIGID)' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'range', required: false, enum: ['today', 'mtd', '30d'] })
  getMatrixSummary(
    @CurrentUser() user: any,
    @Query('branchId') branchId?: string,
    @Query('range') range: string = 'mtd',
  ) {
    return this.analyticsService.getMatrixSummary(user, branchId, range);
  }

  @Get('summary/dealership')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'Comprehensive Dealership As-On-Date & MTD Conversion Matrix with Financials' })
  @ApiQuery({ name: 'date', required: false, description: 'YYYY-MM-DD' })
  @ApiQuery({ name: 'period', required: false, enum: ['today', 'week', 'mtd', 'ytd', 'custom'] })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD (for custom period)' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD (for custom period)' })
  getComprehensiveDealershipSummary(
    @CurrentUser() user: any,
    @Query('date') date?: string,
    @Query('period') period: string = 'today',
    @Query('branchId') branchId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.analyticsService.getComprehensiveDealershipSummary(user, date, period, branchId, from, to);
  }

  @Get('v3/summary')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER)
  @ApiOperation({ summary: 'Alias matching prototype /api/v3/summary' })
  getV3Summary(
    @CurrentUser() user: any,
    @Query('date') date?: string,
    @Query('period') period: string = 'today',
    @Query('branchId') branchId?: string,
  ) {
    return this.analyticsService.getComprehensiveDealershipSummary(user, date, period, branchId);
  }
}

