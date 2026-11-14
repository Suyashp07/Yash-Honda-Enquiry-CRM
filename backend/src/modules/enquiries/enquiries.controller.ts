import { Controller, Get, Post, Put, Patch, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { EnquiriesService } from './enquiries.service';
import { CreateEnquiryDto, UpdateEnquiryStatusDto, AssignEnquiryDto } from './dto/enquiry.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { EnquiryStatus } from '@prisma/client';

@ApiTags('enquiries')
@Controller('enquiries')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class EnquiriesController {
  constructor(private readonly enquiriesService: EnquiriesService) {}

  @Post()
  @ApiOperation({ summary: 'Create new enquiry (supports atomic quotation in Unified Flow)' })
  create(@Body() dto: CreateEnquiryDto, @CurrentUser('id') userId: string) {
    return this.enquiriesService.create(dto, userId);
  }

  @Get()
  @ApiOperation({ summary: 'List enquiries scoped to authorized branches with filters' })
  @ApiQuery({ name: 'branchId', required: false })
  @ApiQuery({ name: 'status', required: false, enum: EnquiryStatus })
  @ApiQuery({ name: 'assignedToId', required: false })
  @ApiQuery({ name: 'search', required: false })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  findAll(
    @CurrentUser() user: any,
    @Query('branchId') branchId?: string,
    @Query('status') status?: EnquiryStatus,
    @Query('assignedToId') assignedToId?: string,
    @Query('search') search?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.enquiriesService.findAll(user, { branchId, status, assignedToId, search, from, to });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get full enquiry details, timeline history, quotations, and calls' })
  findOne(@Param('id') id: string, @CurrentUser() user: any) {
    return this.enquiriesService.findOne(id, user);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Update enquiry status and append to EnquiryStatusHistory' })
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateEnquiryStatusDto,
    @CurrentUser() user: any,
  ) {
    return this.enquiriesService.updateStatus(id, dto, user);
  }

  @Patch(':id/assign')
  @ApiOperation({ summary: 'Assign enquiry to a sales executive at the same branch' })
  assign(
    @Param('id') id: string,
    @Body() dto: AssignEnquiryDto,
    @CurrentUser() user: any,
  ) {
    return this.enquiriesService.assign(id, dto, user);
  }
}

