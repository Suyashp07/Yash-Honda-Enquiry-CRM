import { Controller, Get, Post, Body, Param, Query, UseGuards, Res, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { Response } from 'express';
import { QuotationsService } from './quotations.service';
import { CalculateQuotationDto, CreateQuotationDto } from './dto/quotation.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { BranchAccessGuard } from '../../common/guards/branch-access.guard';
import { Public } from '../../common/decorators/public.decorator';
import { verifyPrintToken } from './quotation-renderer';

@ApiTags('quotations')
@Controller('quotations')
@UseGuards(JwtAuthGuard, BranchAccessGuard)
@ApiBearerAuth()
export class QuotationsController {
  constructor(private readonly quotationsService: QuotationsService) { }

  @Public()
  @Get(':id/print')
  @ApiOperation({ summary: 'Generate printable official Yash Honda HTML quotation (requires signed token)' })
  async printQuotation(
    @Param('id') id: string,
    @Query('token') token: string | undefined,
    @Query('expires') expires: string | undefined,
    @Res() res: Response,
  ) {
    if (!verifyPrintToken(id, token, expires)) {
      throw new ForbiddenException('A valid, non-expired print token is required to view this quotation.');
    }
    const html = await this.quotationsService.generatePrintableHtml(id);
    res.setHeader('Content-Type', 'text/html');
    return res.send(html);
  }

  @Get(':id/signed-print-url')
  @ApiOperation({ summary: 'Get a short-lived signed print URL for a quotation' })
  getSignedPrintUrl(@Param('id') id: string) {
    const { expires, token } = this.quotationsService.getSignedPrintParams(id);
    return {
      url: `/api/quotations/${encodeURIComponent(id)}/print?token=${token}&expires=${expires}`,
      expiresAt: new Date(expires).toISOString(),
    };
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

