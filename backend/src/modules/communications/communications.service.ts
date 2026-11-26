import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { SendWhatsAppDto, SendEmailDto } from './dto/communication.dto';
import {
  renderCanonicalQuotationHtml,
  reconcileQuotationTotals,
  hasVerifiedCompanySettings,
  formatINR as canonicalFormatINR,
} from '../quotations/quotation-renderer';
import { generateQuotationPdfBuffer } from '../quotations/quotation-pdf';

@Injectable()
export class CommunicationsService {
  private readonly logger = new Logger(CommunicationsService.name);

  constructor(private prisma: PrismaService) {}

  private formatINR(amount: number | string | any): string {
    return canonicalFormatINR(amount);
  }

  /**
   * Generate official, responsive HTML Quotation Email Template via canonical renderer
   */
  generateQuotationHtml(quotation: any, enquiry: any, settings: any): string {
    const quoteWithEnquiry = {
      ...quotation,
      enquiry: enquiry || quotation?.enquiry,
    };
    return renderCanonicalQuotationHtml(quoteWithEnquiry, settings, { mode: 'email' });
  }

  /**
   * Preview generated HTML quotation for testing in browser / iframe
   */
  async previewQuotationHtml(quotationId: string): Promise<string> {
    const quotation = await this.prisma.quotation.findUnique({
      where: { id: quotationId },
      include: {
        items: true,
        accessories: { include: { accessory: true } },
        vehicle: { include: { modelGroup: true } },
        branch: true,
        enquiry: {
          include: { customer: true, branch: true },
        },
      },
    });

    if (!quotation) {
      throw new NotFoundException(`Quotation with ID ${quotationId} not found`);
    }

    const settings: any = (await this.prisma.companySettings.findFirst()) || {};
    return this.generateQuotationHtml(quotation, quotation.enquiry, settings);
  }

  /**
   * Send Email with Quotation details via Brevo (or simulated dispatch)
   */
  async sendEmail(dto: SendEmailDto) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
      include: {
        customer: true,
        branch: true,
        quotations: {
          include: {
            items: true,
            accessories: { include: { accessory: true } },
            vehicle: { include: { modelGroup: true } },
            branch: true,
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    const quotation = dto.quotationId
      ? enquiry.quotations.find((q) => q.id === dto.quotationId) || enquiry.quotations[0]
      : enquiry.quotations[0];

    if (!quotation) {
      throw new NotFoundException('No quotation found for this enquiry to email');
    }

    const recipientEmail = dto.recipientEmail || enquiry.customer?.email;
    if (!recipientEmail || !recipientEmail.includes('@')) {
      throw new BadRequestException('A valid recipient email address is required');
    }

    const settings: any = (await this.prisma.companySettings.findFirst()) || {};
    const reconciliation = reconcileQuotationTotals(quotation);
    if (!reconciliation.reconciled) {
      throw new BadRequestException(
        `Quotation totals do not reconcile (computed ${reconciliation.computedTotal}, stored ${reconciliation.storedTotal}). Please recalculate before sending.`,
      );
    }
    const verification = hasVerifiedCompanySettings(settings);
    if (!verification.valid) {
      throw new BadRequestException(
        `Cannot send customer quotation until Company Settings are verified. Missing: ${verification.missingFields.join(', ')}.`,
      );
    }

    const subject =
      dto.subject ||
      `Official ${settings.companyName || 'Yash Honda'} Quotation - ${quotation.vehicle?.name || 'Honda'} (${quotation.quoteNumber})`;
    const htmlContent = this.generateQuotationHtml(quotation, enquiry, settings);
    const textContent = [
      `${settings.companyName || 'Yash Honda'} - Official Quotation #${quotation.quoteNumber}`,
      `Customer: ${enquiry.customer?.name || 'Customer'}`,
      `Vehicle: ${quotation.vehicle?.name || 'Honda'} (${quotation.colourName || 'Standard'})`,
      `Grand Total (On-Road): ${this.formatINR(quotation.grandTotal)}`,
      `Valid for 15 days from quotation date.`,
    ].join('\n');

    const brevoApiKey = process.env.BREVO_API_KEY?.trim().replace(/^["']|["']$/g, '');
    const rawSender = process.env.BREVO_SENDER_EMAIL?.trim().replace(/^["']|["']$/g, '');
    const senderEmail =
      rawSender && rawSender.includes('@')
        ? rawSender
        : settings?.email && String(settings.email).includes('@')
        ? String(settings.email).trim()
        : 'quotes@yashhonda.com';
    const senderName = settings.companyName || 'Yash Honda Pune';

    let deliveryStatus = 'sent';
    const responsePayload: any = {
      recipientEmail,
      subject,
      quotationId: quotation.id,
      quoteNumber: quotation.quoteNumber,
      sentAt: new Date().toISOString(),
    };

    // Build 2 PDF attachments: (1) Generated Quotation PDF + (2) Official Vehicle Brochure PDF
    const attachments: Array<{ name: string; content: string }> = [];
    try {
      const quotePdfBuf = await generateQuotationPdfBuffer(quotation, enquiry, settings);
      attachments.push({
        name: `Quotation_${quotation.quoteNumber}.pdf`,
        content: quotePdfBuf.toString('base64'),
      });
    } catch (pdfErr: any) {
      this.logger.warn(`Could not generate quotation PDF buffer: ${pdfErr.message}`);
    }

    const brochureUrl = quotation.vehicle?.brochureUrl?.toString()?.trim();
    if (brochureUrl && /^https?:\/\//i.test(brochureUrl)) {
      try {
        const bRes = await fetch(brochureUrl, { signal: AbortSignal.timeout(8000) });
        if (bRes.ok) {
          const bBuf = Buffer.from(await bRes.arrayBuffer());
          const safeModel = (quotation.vehicle?.name || 'Honda_Vehicle')
            .replace(/[^a-zA-Z0-9_-]+/g, '_');
          attachments.push({
            name: `${safeModel}_Brochure.pdf`,
            content: bBuf.toString('base64'),
          });
        }
      } catch (bErr: any) {
        this.logger.warn(`Could not fetch brochure PDF (${brochureUrl}): ${bErr.message}`);
      }
    }
    responsePayload.attachments = attachments.map((a) => a.name);

    if (brevoApiKey && brevoApiKey.length > 10) {
      this.logger.log(`Dispatching live Brevo transactional email to: ${recipientEmail}`);
      try {
        const brevoRes = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: {
            'api-key': brevoApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: JSON.stringify({
            sender: { name: senderName, email: senderEmail },
            to: [{ email: recipientEmail, name: enquiry.customer?.name || 'Customer' }],
            subject,
            htmlContent,
            textContent,
            ...(attachments.length > 0 ? { attachment: attachments } : {}),
          }),
        });

        const resJson = await brevoRes.json();
        if (brevoRes.ok) {
          deliveryStatus = 'accepted';
          responsePayload.brevoMessageId = resJson.messageId;
          responsePayload.mode = 'live_brevo';
          this.logger.log(`Brevo email accepted for delivery! MessageId: ${resJson.messageId}`);
        } else {
          deliveryStatus = 'failed';
          responsePayload.brevoError = resJson;
          responsePayload.mode = 'live_brevo_error';
          this.logger.error(`Brevo email dispatch failed: ${JSON.stringify(resJson)}`);
        }
      } catch (err: any) {
        deliveryStatus = 'failed';
        responsePayload.error = err.message;
        this.logger.error(`Network error calling Brevo API: ${err.message}`);
      }
    } else {
      // Simulated Mode (must NOT be labeled delivered)
      deliveryStatus = 'simulated';
      responsePayload.mode = 'simulated';
      responsePayload.note =
        'Brevo API Key not configured. Quotation HTML rendered and simulated; no real email was sent.';
      this.logger.log(`[SIMULATED BREVO EMAIL] To: ${recipientEmail} | Subject: ${subject}`);
    }

    // Persist communication log entry
    const record = await this.prisma.communication.create({
      data: {
        enquiryId: dto.enquiryId,
        channel: 'email',
        status: deliveryStatus,
        payload: responsePayload,
      },
    });

    return {
      success: deliveryStatus !== 'failed',
      status: deliveryStatus,
      communicationId: record.id,
      recipient: recipientEmail,
      quoteNumber: quotation.quoteNumber,
      mode: responsePayload.mode,
      message:
        deliveryStatus === 'failed'
          ? `Brevo email failed: ${JSON.stringify(responsePayload.brevoError || responsePayload.error)}`
          : deliveryStatus === 'accepted'
          ? `Quotation ${quotation.quoteNumber} accepted by email provider (awaiting delivery confirmation).`
          : `Simulated send recorded (BREVO_API_KEY not configured — no real email delivered).`,
    };
  }

  /**
   * Send WhatsApp notification via Meta Cloud API (or simulated dispatch)
   */
  async sendWhatsApp(dto: SendWhatsAppDto) {
    const enquiry = await this.prisma.enquiry.findUnique({
      where: { id: dto.enquiryId },
      include: {
        customer: true,
        branch: true,
        quotations: {
          include: {
            vehicle: true,
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!enquiry) {
      throw new NotFoundException(`Enquiry with ID ${dto.enquiryId} not found`);
    }

    const quotation = dto.quotationId
      ? enquiry.quotations.find((q) => q.id === dto.quotationId) || enquiry.quotations[0]
      : enquiry.quotations[0];

    const settings: any = (await this.prisma.companySettings.findFirst()) || {};
    if (quotation) {
      const reconciliation = reconcileQuotationTotals(quotation);
      if (!reconciliation.reconciled) {
        throw new BadRequestException(
          `Quotation totals do not reconcile (computed ${reconciliation.computedTotal}, stored ${reconciliation.storedTotal}).`,
        );
      }
      const verification = hasVerifiedCompanySettings(settings);
      if (!verification.valid) {
        throw new BadRequestException(
          `Cannot send WhatsApp quotation until Company Settings are verified. Missing: ${verification.missingFields.join(', ')}.`,
        );
      }
    }

    const recipientMobile = enquiry.customer?.mobile;
    const metaWaToken = process.env.META_WA_ACCESS_TOKEN?.trim();
    const phoneId = process.env.META_WA_PHONE_NUMBER_ID?.trim();

    let status = 'queued';
    const payload: any = {
      recipient: recipientMobile,
      template: dto.templateName,
      quotationId: quotation?.id,
      quoteNumber: quotation?.quoteNumber,
      sentAt: new Date().toISOString(),
    };

    if (metaWaToken && phoneId && metaWaToken.length > 10) {
      // Live Meta WhatsApp Cloud API call
      try {
        const waRes = await fetch(`https://graph.facebook.com/v19.0/${phoneId}/messages`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${metaWaToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: recipientMobile.startsWith('+') ? recipientMobile : `+91${recipientMobile}`,
            type: 'template',
            template: {
              name: dto.templateName || 'quotation_send',
              language: { code: 'en_US' },
              components: [
                {
                  type: 'body',
                  parameters: [
                    { type: 'text', text: enquiry.customer?.name || 'Customer' },
                    { type: 'text', text: quotation?.vehicle?.name || 'Honda Vehicle' },
                    { type: 'text', text: this.formatINR(quotation?.grandTotal || 0) },
                    { type: 'text', text: quotation?.quoteNumber || 'DRAFT' },
                  ],
                },
              ],
            },
          }),
        });

        const resJson = await waRes.json();
        if (waRes.ok) {
          status = 'accepted';
          payload.metaMessageId = resJson.messages?.[0]?.id;
          payload.mode = 'live_meta';
        } else {
          status = 'failed';
          payload.metaError = resJson;
          payload.mode = 'live_meta_error';
        }
      } catch (err: any) {
        status = 'failed';
        payload.error = err.message;
      }
    } else {
      status = 'simulated';
      payload.mode = 'simulated';
      payload.note = 'Meta WhatsApp Access Token not configured. Simulated only; no real message sent.';
      this.logger.log(`[SIMULATED WHATSAPP DISPATCH] To: ${recipientMobile} | Template: ${dto.templateName}`);
    }

    const record = await this.prisma.communication.create({
      data: {
        enquiryId: dto.enquiryId,
        channel: 'whatsapp',
        status,
        payload,
      },
    });

    return {
      success: status !== 'failed',
      communicationId: record.id,
      status,
      recipient: recipientMobile,
      mode: payload.mode,
      message:
        status === 'failed'
          ? `Meta WhatsApp API error: ${JSON.stringify(payload.metaError || payload.error)}`
          : status === 'accepted'
          ? 'WhatsApp message accepted by Meta Cloud API (awaiting delivery webhook).'
          : 'Simulated WhatsApp send recorded (Meta Cloud credentials not configured — no real message delivered).',
    };
  }

  async findByEnquiry(enquiryId: string) {
    return this.prisma.communication.findMany({
      where: { enquiryId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
