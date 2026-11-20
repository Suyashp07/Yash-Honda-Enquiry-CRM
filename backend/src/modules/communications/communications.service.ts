import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { SendWhatsAppDto, SendEmailDto } from './dto/communication.dto';

@Injectable()
export class CommunicationsService {
  private readonly logger = new Logger(CommunicationsService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Helper to format numbers in Indian Rupee currency (₹)
   */
  private formatINR(amount: number | string | any): string {
    const val = Number(amount) || 0;
    return '₹' + val.toLocaleString('en-IN');
  }

  /**
   * Generate official, responsive HTML Quotation Email Template
   */
  generateQuotationHtml(quotation: any, enquiry: any, settings: any): string {
    const customer = enquiry.customer || {};
    const vehicle = quotation.vehicle || {};
    const branch = quotation.branch || enquiry.branch || {};
    const items = quotation.items || [];
    const accessories = quotation.accessories || [];

    const quoteNumber = quotation.quoteNumber || 'DRAFT';
    const quoteDate = new Date(quotation.createdAt || Date.now()).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

    const companyName = settings?.companyName || 'Yash Honda';
    const address = settings?.address || 'Suryaloknagri Society, Hadapsar, Pune 411013';
    const gstNumber = settings?.gstNumber || '24XXXXXXXXXXXZ5';
    const bankName = settings?.bankName || 'HDFC Bank';
    const accountNumber = settings?.accountNumber || '50200098765432';
    const ifsc = settings?.ifsc || 'HDFC0001234';
    const upiId = settings?.upiId || 'yashhonda@hdfcbank';

    // Build line items rows
    const itemsHtml = items
      .map(
        (it: any) => `
        <tr>
          <td style="padding: 10px 14px; border-bottom: 1px solid #F1F5F9; color: #334155; font-size: 13px;">
            ${it.label}
          </td>
          <td style="padding: 10px 14px; border-bottom: 1px solid #F1F5F9; text-align: right; font-weight: 600; color: #0F172A; font-size: 13px;">
            ${this.formatINR(it.amount)}
          </td>
        </tr>`,
      )
      .join('');

    // Build accessories rows
    const accessoriesHtml = accessories
      .map(
        (acc: any) => `
        <tr>
          <td style="padding: 10px 14px; border-bottom: 1px solid #F1F5F9; color: #475569; font-size: 13px;">
            <span style="display: inline-block; width: 6px; height: 6px; background-color: #CC0000; border-radius: 50%; margin-right: 8px;"></span>
            ${acc.accessory?.name || 'Accessory Item'}
          </td>
          <td style="padding: 10px 14px; border-bottom: 1px solid #F1F5F9; text-align: right; font-weight: 600; color: #0F172A; font-size: 13px;">
            ${this.formatINR(acc.amount)}
          </td>
        </tr>`,
      )
      .join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Official Honda Quotation - ${vehicle.name || 'Vehicle'}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0F172A;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #F8FAFC; padding: 24px 0;">
    <tr>
      <td align="center">
        <!-- Main Email Container (600px standard) -->
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #FFFFFF; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.06); border: 1px solid #E2E8F0;">
          
          <!-- Top Red Header Bar -->
          <tr>
            <td style="background-color: #CC0000; padding: 22px 28px; text-align: left;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td>
                    <h1 style="margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 900; letter-spacing: -0.5px;">
                      ${companyName}
                    </h1>
                    <p style="margin: 3px 0 0 0; color: #FEE2E2; font-size: 12px; font-weight: 500;">
                      Authorised Honda Two-Wheeler Dealership &bull; Pune
                    </p>
                  </td>
                  <td align="right">
                    <span style="background-color: rgba(255,255,255,0.2); color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 4px; text-transform: uppercase;">
                      Official Quote
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Showroom Sub-header -->
          <tr>
            <td style="padding: 14px 28px; background-color: #FAFAFA; border-bottom: 1px solid #E2E8F0; font-size: 11.5px; color: #64748B;">
              <strong>${branch.name || 'Showroom'}</strong> &bull; ${address} &bull; GSTIN: <strong>${gstNumber}</strong>
            </td>
          </tr>

          <!-- Quote Details Ribbon -->
          <tr>
            <td style="padding: 24px 28px 16px 28px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td width="50%" valign="top">
                    <p style="margin: 0; font-size: 11px; text-transform: uppercase; color: #94A3B8; font-weight: 700;">Customer Details</p>
                    <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 800; color: #0F172A;">${customer.name || 'Valued Customer'}</p>
                    <p style="margin: 2px 0 0 0; font-size: 12px; color: #475569;">Mobile: <strong>${customer.mobile || '-'}</strong></p>
                    ${customer.email ? `<p style="margin: 2px 0 0 0; font-size: 12px; color: #475569;">Email: ${customer.email}</p>` : ''}
                  </td>
                  <td width="50%" valign="top" align="right">
                    <p style="margin: 0; font-size: 11px; text-transform: uppercase; color: #94A3B8; font-weight: 700;">Quotation Reference</p>
                    <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 800; color: #CC0000;">${quoteNumber}</p>
                    <p style="margin: 2px 0 0 0; font-size: 12px; color: #475569;">Date: <strong>${quoteDate}</strong></p>
                    <p style="margin: 2px 0 0 0; font-size: 12px; color: #16A34A; font-weight: 600;">Validity: 7 Days</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Vehicle Banner Box -->
          <tr>
            <td style="padding: 0 28px 16px 28px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #FEF2F2; border-left: 4px solid #CC0000; border-radius: 6px; padding: 14px 18px;">
                <tr>
                  <td>
                    <span style="font-size: 11px; text-transform: uppercase; font-weight: 700; color: #991B1B;">Vehicle Model</span>
                    <h2 style="margin: 2px 0 0 0; font-size: 18px; font-weight: 800; color: #991B1B;">
                      ${vehicle.name || 'Honda Motorcycle / Scooter'}
                    </h2>
                    <p style="margin: 4px 0 0 0; font-size: 12.5px; color: #7F1D1D;">
                      Colour: <strong>${quotation.colourName || 'Standard'}</strong> &bull; Purchase Mode: <strong>${enquiry.purchaseMode || 'Cash'}</strong>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Line Items Table -->
          <tr>
            <td style="padding: 0 28px 16px 28px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border: 1px solid #E2E8F0; border-radius: 8px; overflow: hidden;">
                <thead>
                  <tr style="background-color: #F8FAFC;">
                    <th align="left" style="padding: 10px 14px; font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">
                      Item Description
                    </th>
                    <th align="right" style="padding: 10px 14px; font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">
                      Amount (₹)
                    </th>
                  </tr>
                </thead>
                <tbody>
                  ${itemsHtml}
                  ${accessoriesHtml}
                </tbody>
                <tfoot>
                  <tr style="background-color: #FFF5F5;">
                    <td style="padding: 14px; font-size: 15px; font-weight: 800; color: #CC0000;">
                      Grand Total (On-Road Price)
                    </td>
                    <td style="padding: 14px; text-align: right; font-size: 18px; font-weight: 900; color: #CC0000;">
                      ${this.formatINR(quotation.grandTotal)}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </td>
          </tr>

          <!-- Payment & Banking Details -->
          <tr>
            <td style="padding: 0 28px 20px 28px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 16px 20px;">
                <tr>
                  <td width="65%" valign="top">
                    <p style="margin: 0 0 8px 0; font-size: 12px; font-weight: 700; color: #0F172A; text-transform: uppercase;">
                      Official Bank Account for Booking
                    </p>
                    <p style="margin: 2px 0; font-size: 12px; color: #334155;">Bank: <strong>${bankName}</strong></p>
                    <p style="margin: 2px 0; font-size: 12px; color: #334155;">Account Number: <strong>${accountNumber}</strong></p>
                    <p style="margin: 2px 0; font-size: 12px; color: #334155;">IFSC Code: <strong>${ifsc}</strong></p>
                    <p style="margin: 2px 0; font-size: 12px; color: #334155;">UPI ID: <strong>${upiId}</strong></p>
                  </td>
                  <td width="35%" align="center" valign="middle" style="border-left: 1px solid #E2E8F0; padding-left: 14px;">
                    <p style="margin: 0; font-size: 11px; font-weight: 700; color: #64748B;">Instant UPI Payment</p>
                    <div style="margin-top: 6px; padding: 6px; background-color: #FFFFFF; border: 1px solid #CBD5E1; border-radius: 6px; display: inline-block;">
                      <span style="font-size: 24px;">📱</span>
                      <p style="margin: 2px 0 0 0; font-size: 9px; font-weight: bold; color: #0F172A;">Scan / Pay via UPI</p>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Terms and Footer -->
          <tr>
            <td style="padding: 16px 28px 24px 28px; background-color: #FAFAFA; border-top: 1px solid #E2E8F0;">
              <p style="margin: 0 0 6px 0; font-size: 10.5px; color: #94A3B8; text-transform: uppercase; font-weight: 700;">Terms & Conditions</p>
              <p style="margin: 0 0 12px 0; font-size: 11px; color: #64748B; line-height: 1.4;">
                ${settings?.quotationTerms || 'Prices indicative and subject to change without prior notice. Insurance coverage as per IRDAI terms. Delivery subject to stock availability and RTO registration clearance. E&OE.'}
              </p>
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top: 1px solid #E2E8F0; padding-top: 12px;">
                <tr>
                  <td style="font-size: 11px; color: #64748B;">
                    <strong>Yash Honda Dealership Network &bull; Pune</strong><br>
                    Helpline: +91 98888 88888 &bull; Email: ${settings?.senderEmail || 'quotes@yashhonda.com'}
                  </td>
                  <td align="right" style="font-size: 11px; color: #94A3B8;">
                    Generated by Yash Honda CRM
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
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
    const subject =
      dto.subject ||
      `Official Yash Honda Quotation - ${quotation.vehicle?.name || 'Honda'} (${quotation.quoteNumber})`;
    const htmlContent = this.generateQuotationHtml(quotation, enquiry, settings);

    const brevoApiKey = process.env.BREVO_API_KEY?.trim();
    const senderEmail = process.env.BREVO_SENDER_EMAIL?.trim() || 'quotes@yashhonda.com';
    const senderName = settings.companyName || 'Yash Honda Pune';

    let deliveryStatus = 'sent';
    const responsePayload: any = {
      recipientEmail,
      subject,
      quotationId: quotation.id,
      quoteNumber: quotation.quoteNumber,
      sentAt: new Date().toISOString(),
    };

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
          }),
        });

        const resJson = await brevoRes.json();
        if (brevoRes.ok) {
          deliveryStatus = 'delivered';
          responsePayload.brevoMessageId = resJson.messageId;
          responsePayload.mode = 'live_brevo';
          this.logger.log(`Brevo email dispatched successfully! MessageId: ${resJson.messageId}`);
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
      // Mock / Preview Mode
      deliveryStatus = 'delivered';
      responsePayload.mode = 'simulated';
      responsePayload.note =
        'Brevo API Key not configured in .env. Quotation HTML rendered and email simulated successfully.';
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
          : responsePayload.mode === 'live_brevo'
          ? `Quotation ${quotation.quoteNumber} emailed successfully via Brevo!`
          : `Quotation email generated and simulated successfully (Add BREVO_API_KEY to send to real inboxes).`,
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

    const recipientMobile = enquiry.customer?.mobile;
    const metaWaToken = process.env.META_WA_ACCESS_TOKEN?.trim();
    const phoneId = process.env.META_WA_PHONE_NUMBER_ID?.trim();

    let status = 'sent';
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
          status = 'delivered';
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
      status = 'delivered';
      payload.mode = 'simulated';
      payload.note = 'Meta WhatsApp Access Token not configured in .env. Simulated successfully.';
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
          : payload.mode === 'live_meta'
          ? 'Quotation WhatsApp dispatched via Meta Cloud API!'
          : 'Quotation WhatsApp message simulated successfully (Meta Cloud credentials ready to connect).',
    };
  }

  async findByEnquiry(enquiryId: string) {
    return this.prisma.communication.findMany({
      where: { enquiryId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
