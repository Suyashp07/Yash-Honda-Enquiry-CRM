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
    try {
      const entry = payload?.entry?.[0];
      const change = entry?.changes?.[0];
      const value = change?.value;
      const statusObj = value?.statuses?.[0];

      if (statusObj) {
        const messageId = statusObj.id;
        const status = statusObj.status; // sent, delivered, read, failed

        const communications = await this.prisma.communication.findMany({
          where: { channel: 'whatsapp' },
          orderBy: { createdAt: 'desc' },
          take: 20,
        });

        for (const comm of communications) {
          const p: any = comm.payload;
          if (p?.metaMessageId === messageId) {
            await this.prisma.communication.update({
              where: { id: comm.id },
              data: {
                status,
                payload: { ...p, lastMetaStatus: status, updatedAt: new Date().toISOString() },
              },
            });
            this.logger.log(`Updated WhatsApp communication ${comm.id} to status: ${status}`);
            break;
          }
        }
      }
    } catch (e: any) {
      this.logger.error(`Error processing WhatsApp webhook: ${e.message}`);
    }

    return { received: true };
  }

  async handleBrevo(payload: any) {
    this.logger.log(`Inbound Brevo Webhook: ${JSON.stringify(payload)}`);
    return { received: true };
  }
}

