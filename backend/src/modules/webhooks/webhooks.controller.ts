import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { WebhooksService } from './webhooks.service';

@ApiTags('webhooks')
@Controller('webhooks')
export class WebhooksController {
  constructor(private readonly webhooksService: WebhooksService) {}

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

