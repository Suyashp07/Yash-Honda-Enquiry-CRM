import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AiInsightsService } from './ai-insights.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '@prisma/client';

@ApiTags('ai-insights')
@Controller('ai-insights')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class AiInsightsController {
  constructor(private readonly aiInsightsService: AiInsightsService) {}

  @Get('summary')
  @Roles(Role.SUPER_ADMIN, Role.BRANCH_MANAGER, Role.SALES_EXEC)
  @ApiOperation({ summary: 'AI-generated natural language executive briefing (privacy-safe, cached in AiSummaryCache)' })
  @ApiQuery({ name: 'branch', required: false, example: 'all' })
  @ApiQuery({ name: 'range', required: false, example: 'today' })
  @ApiQuery({ name: 'forceRefresh', required: false, type: Boolean })
  getSummary(
    @CurrentUser() user: any,
    @Query('branch') branch: string = 'all',
    @Query('range') range: string = 'today',
    @Query('forceRefresh') forceRefresh?: string,
  ) {
    const isForce = forceRefresh === 'true' || forceRefresh === '1';
    return this.aiInsightsService.getSummary(user, branch, range, isForce);
  }
}

