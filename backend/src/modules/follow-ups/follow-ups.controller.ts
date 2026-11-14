import { Controller, Get, Post, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { FollowUpsService } from './follow-ups.service';
import { CreateFollowUpDto, CompleteFollowUpDto } from './dto/follow-up.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('follow-ups')
@Controller('follow-ups')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class FollowUpsController {
  constructor(private readonly followUpsService: FollowUpsService) {}

  @Post()
  @ApiOperation({ summary: 'Schedule a new customer follow-up call/visit' })
  create(@Body() dto: CreateFollowUpDto) {
    return this.followUpsService.create(dto);
  }

  @Patch(':id/complete')
  @ApiOperation({ summary: 'Mark follow-up as completed with remarks' })
  complete(@Param('id') id: string, @Body() dto: CompleteFollowUpDto) {
    return this.followUpsService.complete(id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List follow-ups with filter (today | overdue | upcoming | completed)' })
  @ApiQuery({ name: 'scope', required: false, enum: ['today', 'overdue', 'upcoming', 'completed'] })
  @ApiQuery({ name: 'branchId', required: false })
  findAll(
    @CurrentUser() user: any,
    @Query('scope') scope?: 'today' | 'overdue' | 'upcoming' | 'completed',
    @Query('branchId') branchId?: string,
  ) {
    return this.followUpsService.findAll(user, scope, branchId);
  }
}

