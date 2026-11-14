import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class WebhooksService {
  private readonly logger = new Logger(WebhooksService.name);

  constructor(private prisma: PrismaService) {}

  async handleExotel(payload: any) {
    this.logger.log(`Inbound Exotel Webhook: ${JSON.stringify(payload)}`);
    const { CallSid, Status, RecordingUrl, DialCallDuration } = payload;

    if (CallSid) {
      await this.prisma.call.updateMany({
        where: { providerCallId: CallSid },
        data: {
          status: Status?.toLowerCase() || 'completed',
          durationSeconds: DialCallDuration ? parseInt(DialCallDuration, 10) : undefined,
          recordingR2Key: RecordingUrl ? `recordings/${CallSid}.mp3` : undefined,
          recordingStatus: RecordingUrl ? 'uploaded' : undefined,
        },
      });
    }

    return { received: true };
  }

  async handleWhatsApp(payload: any) {
    this.logger.log(`Inbound WhatsApp Webhook: ${JSON.stringify(payload)}`);
    return { received: true };
  }

  async handleBrevo(payload: any) {
    this.logger.log(`Inbound Brevo Webhook: ${JSON.stringify(payload)}`);
    return { received: true };
  }
}
