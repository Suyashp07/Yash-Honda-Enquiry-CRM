import { Controller, Get, Post, Body, Param, Header, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CommunicationsService } from './communications.service';
import { SendWhatsAppDto, SendEmailDto } from './dto/communication.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('communications')
@Controller('communications')
export class CommunicationsController {
  constructor(private readonly communicationsService: CommunicationsService) {}

  @Post('whatsapp')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send pre-approved WhatsApp message/quotation via Meta Cloud API' })
  sendWhatsApp(@Body() dto: SendWhatsAppDto) {
    return this.communicationsService.sendWhatsApp(dto);
  }

  @Post('email')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Send quotation PDF email via Brevo transactional API' })
  sendEmail(@Body() dto: SendEmailDto) {
    return this.communicationsService.sendEmail(dto);
  }

  @Public()
  @Post('configurator-whatsapp')
  @ApiOperation({ summary: 'Send quotation via WhatsApp from customer self-serve configurator' })
  sendConfiguratorWhatsApp(@Body() dto: SendWhatsAppDto) {
    return this.communicationsService.sendWhatsApp(dto);
  }

  @Public()
  @Post('configurator-email')
  @ApiOperation({ summary: 'Send quotation via Email from customer self-serve configurator' })
  sendConfiguratorEmail(@Body() dto: SendEmailDto) {
    return this.communicationsService.sendEmail(dto);
  }

  @Get('preview-email/:quotationId')
  @Header('Content-Type', 'text/html')
  @ApiOperation({ summary: 'Preview live responsive HTML quotation email in browser' })
  previewEmail(@Param('quotationId') quotationId: string) {
    return this.communicationsService.previewQuotationHtml(quotationId);
  }

  @Get('enquiry/:enquiryId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get communication log history for an enquiry' })
  findByEnquiry(@Param('enquiryId') enquiryId: string) {
    return this.communicationsService.findByEnquiry(enquiryId);
  }
}

