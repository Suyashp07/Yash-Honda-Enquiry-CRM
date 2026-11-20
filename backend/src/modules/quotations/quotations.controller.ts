import { Controller, Get, Post, Body, Param, Query, UseGuards, Res } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { Response } from 'express';
import { QuotationsService } from './quotations.service';
import { CalculateQuotationDto, CreateQuotationDto } from './dto/quotation.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { BranchAccessGuard } from '../../common/guards/branch-access.guard';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('quotations')
@Controller('quotations')
@UseGuards(JwtAuthGuard, BranchAccessGuard)
@ApiBearerAuth()
export class QuotationsController {
  constructor(private readonly quotationsService: QuotationsService) { }

  @Public()
  @Get(':id/print')
  @ApiOperation({ summary: 'Generate printable official Yash Honda HTML quotation' })
  async printQuotation(@Param('id') id: string, @Res() res: Response) {
    const html = await this.quotationsService.generatePrintableHtml(id);
    res.setHeader('Content-Type', 'text/html');
    return res.send(html);
  }

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

