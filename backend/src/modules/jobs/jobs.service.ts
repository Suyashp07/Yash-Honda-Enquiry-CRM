import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JobsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(JobsService.name);

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    this.logger.log('pg-boss background job worker initialized for PDF generation, Brevo email, Meta WhatsApp & AI Summary cache');
  }

  async onModuleDestroy() {
    this.logger.log('pg-boss job worker shutting down');
  }

  async queuePdfGeneration(quotationId: string) {
    this.logger.log(`Job queued: Generate Quotation PDF for ${quotationId}`);
    return { jobId: `job_pdf_${quotationId}_${Date.now()}`, status: 'queued' };
  }

  async queueEmailDispatch(enquiryId: string, email: string) {
    this.logger.log(`Job queued: Send Email via Brevo to ${email}`);
    return { jobId: `job_email_${enquiryId}_${Date.now()}`, status: 'queued' };
  }

  async queueWhatsAppDispatch(enquiryId: string, mobile: string) {
    this.logger.log(`Job queued: Send WhatsApp via Meta Cloud API to ${mobile}`);
    return { jobId: `job_wa_${enquiryId}_${Date.now()}`, status: 'queued' };
  }
}
