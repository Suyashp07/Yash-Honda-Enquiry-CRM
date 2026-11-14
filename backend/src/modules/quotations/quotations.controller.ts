import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { QuotationsService } from './quotations.service';
import { CalculateQuotationDto, CreateQuotationDto } from './dto/quotation.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { BranchAccessGuard } from '../../common/guards/branch-access.guard';

@ApiTags('quotations')
@Controller('quotations')
@UseGuards(JwtAuthGuard, BranchAccessGuard)
@ApiBearerAuth()
export class QuotationsController {
  constructor(private readonly quotationsService: QuotationsService) {}

  @Post('calculate')
  @ApiOperation({ summary: 'Calculate quotation live on customize screen without saving' })
  calculate(@Body() dto: CalculateQuotationDto) {
    return this.quotationsService.calculate(dto);
  }

  @Post()
  @ApiOperation({ summary: 'Create and snapshot official quotation for an enquiry' })
  create(@Body() dto: CreateQuotationDto) {
    return this.quotationsService.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List quotations with optional branch filter' })
  @ApiQuery({ name: 'branchId', required: false })
  findAll(@Query('branchId') branchId?: string) {
    return this.quotationsService.findAll(branchId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get full quotation details and snapshotted line items' })
  findOne(@Param('id') id: string) {
    return this.quotationsService.findOne(id);
  }
}

