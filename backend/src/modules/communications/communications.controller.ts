import { Controller, Get, Post, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CommunicationsService } from './communications.service';
import { SendWhatsAppDto, SendEmailDto } from './dto/communication.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('communications')
@Controller('communications')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class CommunicationsController {
  constructor(private readonly communicationsService: CommunicationsService) {}

  @Post('whatsapp')
  @ApiOperation({ summary: 'Send pre-approved WhatsApp message/quotation via Meta Cloud API' })
  sendWhatsApp(@Body() dto: SendWhatsAppDto) {
    return this.communicationsService.sendWhatsApp(dto);
  }

  @Post('email')
  @ApiOperation({ summary: 'Send quotation PDF email via Brevo transactional API' })
  sendEmail(@Body() dto: SendEmailDto) {
    return this.communicationsService.sendEmail(dto);
  }

  @Get('enquiry/:enquiryId')
  @ApiOperation({ summary: 'Get communication log history for an enquiry' })
  findByEnquiry(@Param('enquiryId') enquiryId: string) {
    return this.communicationsService.findByEnquiry(enquiryId);
  }
}
