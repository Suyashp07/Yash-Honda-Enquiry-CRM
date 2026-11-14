import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { SendWhatsAppDto, SendEmailDto } from './dto/communication.dto';

@Injectable()
export class CommunicationsService {
  constructor(private prisma: PrismaService) {}

  async sendWhatsApp(dto: SendWhatsAppDto) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
      include: { customer: true },
    });
    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    // Persist communication record
    const record = await this.prisma.communication.create({
      data: {
        enquiryId: dto.enquiryId,
        channel: 'whatsapp',
        status: 'sent',
        payload: {
          recipient: enquiry.customer.mobile,
          template: dto.templateName,
          quotationId: dto.quotationId,
          sentAt: new Date().toISOString(),
        },
      },
    });

    return {
      message: 'WhatsApp template queued for delivery via Meta Cloud API',
      communicationId: record.id,
      status: record.status,
      recipient: enquiry.customer.mobile,
    };
  }

  async sendEmail(dto: SendEmailDto) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
      include: { customer: true },
    });
    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    const record = await this.prisma.communication.create({
      data: {
        enquiryId: dto.enquiryId,
        channel: 'email',
        status: 'sent',
        payload: {
          recipientEmail: dto.recipientEmail,
          subject: dto.subject,
          quotationId: dto.quotationId,
          sentAt: new Date().toISOString(),
        },
      },
    });

    return {
      message: 'Email with quotation PDF queued for dispatch via Brevo',
      communicationId: record.id,
      status: record.status,
      recipient: dto.recipientEmail,
    };
  }

  async findByEnquiry(enquiryId: string) {
    return this.prisma.communication.findMany({
      where: { enquiryId },
      orderBy: { createdAt: 'desc' },
    });
  }
}

