import { Controller, Get, Post, Body, Query, HttpCode, HttpStatus, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { WebhooksService } from './webhooks.service';

@ApiTags('webhooks')
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly webhooksService: WebhooksService) {}

  @Get('whatsapp')
  @ApiOperation({ summary: 'Meta WhatsApp Webhook Verification Handshake (hub.challenge)' })
  verifyWhatsApp(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') token: string,
    @Query('hub.challenge') challenge: string,
  ) {
    const verifyToken = process.env.META_WA_WEBHOOK_VERIFY_TOKEN || 'yash_honda_whatsapp_webhook_token';
    if (mode === 'subscribe' && token === verifyToken) {
      return challenge;
    }
    throw new ForbiddenException('Invalid verification token');
  }

  @Post('exotel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Inbound callback webhook for Exotel telephony events' })
  handleExotel(@Body() body: any) {
    return this.webhooksService.handleExotel(body);
  }

  @Post('whatsapp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Inbound webhook for Meta WhatsApp delivery and read events' })
  handleWhatsApp(@Body() body: any) {
    return this.webhooksService.handleWhatsApp(body);
  }

  @Post('brevo')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Inbound webhook for Brevo transactional email events' })
  handleBrevo(@Body() body: any) {
    return this.webhooksService.handleBrevo(body);
  }
}

