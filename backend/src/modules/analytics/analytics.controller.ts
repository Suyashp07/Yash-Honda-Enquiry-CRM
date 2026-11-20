import { Controller, Get, Query, UseGuards } from '@nestjs/common';
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
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'Floor Dashboard live rep workload and today enquiry metrics (RIGID)' })
  @ApiQuery({ name: 'branchId', required: false })
  getFloorDashboard(@CurrentUser() user: any, @Query('branchId') branchId?: string) {
    return this.analyticsService.getFloorDashboard(user, branchId);
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
  @ApiQuery({ name: 'period', required: false, enum: ['today', 'week', 'mtd', 'ytd'] })
  @ApiQuery({ name: 'branchId', required: false })
  getComprehensiveDealershipSummary(
    @CurrentUser() user: any,
    @Query('date') date?: string,
    @Query('period') period: string = 'today',
    @Query('branchId') branchId?: string,
  ) {
    return this.analyticsService.getComprehensiveDealershipSummary(user, date, period, branchId);
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

