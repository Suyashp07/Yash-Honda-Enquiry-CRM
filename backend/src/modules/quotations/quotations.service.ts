import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CalculateQuotationDto, CreateQuotationDto } from './dto/quotation.dto';

@Injectable()
export class QuotationsService {
  constructor(private prisma: PrismaService) { }

  async calculate(dto: CalculateQuotationDto) {
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: dto.vehicleId },
      include: { modelGroup: true },
    });
    if (!vehicle || vehicle.status !== 'Active') {
      throw new NotFoundException('Vehicle not found or inactive');
    }

    const branch = await this.prisma.branch.findUnique({
      where: { id: dto.branchId },
    });
    if (!branch || branch.status !== 'Active') {
      throw new NotFoundException('Branch not found or inactive');
    }

    const settings = await this.prisma.companySettings.findFirst();

    // Line items breakdown
    const exShowroom = Number(vehicle.exShowroomPrice);
    const onRoad = Number(vehicle.onRoadPrice);
    const stdAccessories = 1800;

    // Approximate RTO Road Tax & Insurance distribution from stored onRoad delta
    const diff = Math.max(0, onRoad - exShowroom - stdAccessories);
    const roadTax = Math.round(diff * 0.613143);
    const insurance = Math.max(0, diff - roadTax);

    const items: Array<{ label: string; amount: number }> = [
      { label: 'Ex-Showroom Price', amount: exShowroom },
      { label: 'RTO Registration & Road Tax', amount: roadTax },
      { label: 'Comprehensive Insurance', amount: insurance },
      { label: 'Standard Accessories', amount: stdAccessories },
    ];

    // Hypothecation charge if Finance
    if (dto.purchaseMode?.toLowerCase() === 'finance' && settings) {
      if (settings.hypothecationCharge && Number(settings.hypothecationCharge) > 0) {
        items.push({
          label: 'Bank Hypothecation Loan Endorsement',
          amount: Number(settings.hypothecationCharge),
        });
      }
    }

    // Process accessories
    const accessoriesBreakdown: Array<{
      accessoryId: string;
      name: string;
      amount: number;
      isPriceEditable: boolean;
    }> = [];

    if (dto.accessories && dto.accessories.length > 0) {
      for (const item of dto.accessories) {
        const acc = await this.prisma.accessory.findUnique({
          where: { id: item.accessoryId },
        });
        if (!acc || acc.status !== 'Active') continue;

        let finalPrice = Number(acc.defaultPrice);
        if (acc.isPriceEditable && item.amount !== undefined) {
          finalPrice = Number(item.amount);
        }

        accessoriesBreakdown.push({
          accessoryId: acc.id,
          name: acc.name,
          amount: finalPrice,
          isPriceEditable: acc.isPriceEditable,
        });
      }
    }

    const itemsTotal = items.reduce((sum, it) => sum + it.amount, 0);
    const accessoriesTotal = accessoriesBreakdown.reduce((sum, it) => sum + it.amount, 0);
    const grandTotal = itemsTotal + accessoriesTotal;

    return {
      vehicle: {
        id: vehicle.id,
        code: vehicle.code,
        name: vehicle.name,
        category: vehicle.category,
        modelGroup: vehicle.modelGroup.name,
        quotePrefix: vehicle.modelGroup.quotePrefix,
      },
      branch: {
        id: branch.id,
        code: branch.code,
        name: branch.name,
      },
      colourName: dto.colourName,
      purchaseMode: dto.purchaseMode,
      exShowroom,
      roadTax,
      insurance,
      stdAccessories,
      items,
      accessories: accessoriesBreakdown,
      itemsTotal,
      accessoriesTotal,
      grandTotal,
    };
  }

  async generateQuoteNumber(quotePrefix: string, branchCode: string, tx: any = this.prisma) {
    // BigWing branch quotes always start with BWQ, RedWing with RWQ
    let prefix = quotePrefix;
    if (branchCode.startsWith('BW')) {
      prefix = 'BWQ';
    } else if (branchCode.startsWith('RW')) {
      prefix = 'RWQ';
    }

    // Count existing quotations for this branch
    const count = await tx.quotation.count({
      where: {
        branch: { code: branchCode },
      },
    });
    const sequence = String(count + 1).padStart(5, '0');
    return `${prefix}-${branchCode}-${sequence}`;
  }

  async create(dto: CreateQuotationDto, prismaTx?: any) {
    const runInTx = async (tx: any) => {
      const calc = await this.calculate(dto);
      const quoteNumber = await this.generateQuoteNumber(
        calc.vehicle.quotePrefix,
        calc.branch.code,
        tx,
      );

      const quotation = await tx.quotation.create({
        data: {
          quoteNumber,
          enquiryId: dto.enquiryId,
          branchId: dto.branchId,
          vehicleId: dto.vehicleId,
          colourName: dto.colourName,
          exShowroom: calc.exShowroom,
          roadTax: calc.roadTax,
          insurance: calc.insurance,
          grandTotal: calc.grandTotal,
          pdfR2Key: `quotes/${quoteNumber}.pdf`,
          items: {
            create: calc.items.map((it) => ({
              vehicleId: dto.vehicleId,
              label: it.label,
              amount: it.amount,
            })),
          },
          accessories: {
            create: calc.accessories.map((acc) => ({
              accessoryId: acc.accessoryId,
              amount: acc.amount,
            })),
          },
        },
        include: {
          items: true,
          accessories: {
            include: { accessory: true },
          },
          vehicle: {
            include: { modelGroup: true },
          },
          branch: true,
          enquiry: {
            include: { customer: true },
          },
        },
      });

      return quotation;
    };

    if (prismaTx) {
      return runInTx(prismaTx);
    } else {
      return this.prisma.$transaction(runInTx);
    }
  }

  async findAll(branchId?: string) {
    return this.prisma.quotation.findMany({
      where: branchId ? { branchId } : undefined,
      include: {
        vehicle: true,
        branch: true,
        enquiry: {
          include: { customer: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async findOne(idOrQuoteNumber: string) {
    const quote = await this.prisma.quotation.findFirst({
      where: {
        OR: [
          { id: idOrQuoteNumber },
          { quoteNumber: idOrQuoteNumber },
        ],
      },
      include: {
        items: true,
        accessories: {
          include: { accessory: true },
        },
        vehicle: {
          include: { modelGroup: true },
        },
        branch: true,
        enquiry: {
          include: {
            customer: true,
            createdBy: { select: { id: true, name: true, mobile: true } },
          },
        },
      },
    });
    if (!quote) {
      throw new NotFoundException(`Quotation ${idOrQuoteNumber} not found`);
    }
    return quote;
  }

  async generatePrintableHtml(idOrQuoteNumber: string): Promise<string> {
    const quote = await this.findOne(idOrQuoteNumber);
    const rawSettings = await this.prisma.companySettings.findFirst();
    const settings: any = rawSettings || {
      companyName: 'Yash Honda',
      gstNumber: '24XXXXXXXXXXXZ5',
      address: 'Suryaloknagri Society Pune Hadapsar Pune 411013',
      quotationTerms:
        'Prices indicative and subject to change. Insurance as applicable. Delivery subject to availability. E&OE.',
      bankName: 'HDFC Bank',
      accountNumber: '50200098765432',
      ifsc: 'HDFC0001234',
      upiId: 'yashhonda@hdfcbank',
    };

    const formatINR = (amt: any): string => {
      const num = Number(amt?.toString?.() ?? amt) || 0;
      return new Intl.NumberFormat('en-IN', {
        style: 'currency',
        currency: 'INR',
        maximumFractionDigits: 0,
      }).format(num);
    };

    const quoteDate = new Date(quote.createdAt).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });
    const validUntilDate = new Date(
      new Date(quote.createdAt).getTime() + 15 * 24 * 60 * 60 * 1000,
    ).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

    const customer: any = quote.enquiry?.customer || {};
    const vehicle: any = quote.vehicle || {};
    const branch: any = quote.branch || {};
    const wing = branch.wing || (quote.quoteNumber.startsWith('BW') ? 'BigWing' : 'RedWing');
    const wingColor = wing === 'BigWing' ? '#1E293B' : '#CC0000';
    const isBigWing = wing === 'BigWing';

    const items = quote.items || [];
    const accessories = quote.accessories || [];

    const itemsRows = items
      .map(
        (it: any, idx: number) => `
        <tr>
          <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; color: #475569; font-size: 13px;">${4 + idx}. ${it.label}</td>
          <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; text-align: right; font-weight: 600; color: #1E293B; font-size: 13px;">${formatINR(it.amount)}</td>
        </tr>`,
      )
      .join('');

    const accessoriesRows = accessories
      .map(
        (acc: any) => `
        <tr>
          <td style="padding: 8px 14px 8px 28px; border-bottom: 1px solid #F1F5F9; color: #64748B; font-size: 12.5px;">• ${acc.accessory?.name || 'Accessory'}</td>
          <td style="padding: 8px 14px; border-bottom: 1px solid #F1F5F9; text-align: right; color: #334155; font-size: 12.5px;">${formatINR(acc.amount)}</td>
        </tr>`,
      )
      .join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Quotation ${quote.quoteNumber} - Yash Honda</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #F8FAFC;
      color: #0F172A;
      -webkit-font-smoothing: antialiased;
    }
    .no-print {
      background: #0F172A;
      color: white;
      padding: 12px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 1000;
      box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    }
    .btn-print {
      background: #DC2626;
      color: white;
      border: none;
      padding: 8px 18px;
      font-weight: 700;
      font-size: 13px;
      border-radius: 6px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }
    .btn-print:hover { background: #B91C1C; }
    .page-container {
      max-width: 820px;
      margin: 28px auto;
      background: #FFFFFF;
      padding: 40px;
      border-radius: 8px;
      border: 1px solid #E2E8F0;
      box-shadow: 0 4px 16px rgba(0,0,0,0.04);
    }
    @media print {
      body { background: white; }
      .no-print { display: none !important; }
      .page-container {
        border: none;
        box-shadow: none;
        margin: 0;
        padding: 10mm 12mm;
        max-width: 100%;
      }
      @page {
        size: A4;
        margin: 8mm;
      }
    }
  </style>
</head>
<body>
  <!-- Print Top Control Bar (Hidden during actual print) -->
  <div class="no-print">
    <div style="font-weight: 700; font-size: 14px; letter-spacing: -0.2px;">
      Yash Honda Official Quotation • ${quote.quoteNumber}
    </div>
    <div style="display: flex; gap: 12px;">
      <button class="btn-print" onclick="window.print()">
        <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4H7v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"></path>
        </svg>
        Print / Save as PDF
      </button>
      <button onclick="window.close()" style="background: transparent; color: #94A3B8; border: 1px solid #334155; padding: 8px 14px; border-radius: 6px; cursor: pointer; font-size: 13px;">
        Close
      </button>
    </div>
  </div>

  <div class="page-container">
    <!-- Header -->
    <table style="width: 100%; border-bottom: 2px solid ${wingColor}; padding-bottom: 18px; margin-bottom: 22px;">
      <tr>
        <td style="vertical-align: top;">
          <div style="display: flex; align-items: center; gap: 12px;">
            ${settings.logoUrl ? `<img src="${settings.logoUrl}" alt="${settings.companyName || 'Yash Honda'}" style="max-height: 44px; max-width: 140px; object-fit: contain;" />` : ''}
            <div style="font-size: 26px; font-weight: 900; color: #CC0000; letter-spacing: -0.5px;">${settings.companyName || 'Yash Honda'}</div>
            <span style="background: ${isBigWing ? '#0F172A' : '#FEE2E2'}; color: ${isBigWing ? '#F8FAFC' : '#DC2626'}; font-size: 11px; font-weight: 800; padding: 3px 8px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.5px;">
              ${wing}
            </span>
          </div>
          <div style="font-size: 12px; color: #475569; margin-top: 4px; font-weight: 500;">
            Authorized Dealer • Honda Motorcycle and Scooter India Pvt. Ltd.
          </div>
          <div style="font-size: 11.5px; color: #64748B; margin-top: 4px; line-height: 1.4;">
            <strong>Branch:</strong> ${branch.name || 'Phursungi Showroom'} (${branch.code || ''})<br>
            ${branch.address || settings.address}<br>
            <strong>GSTIN:</strong> ${settings.gstNumber || '24XXXXXXXXXXXZ5'}
          </div>
        </td>
        <td style="vertical-align: top; text-align: right;">
          <div style="font-size: 11px; font-weight: 800; color: #64748B; letter-spacing: 1px; text-transform: uppercase;">
            Official Quotation
          </div>
          <div style="font-size: 16px; font-weight: 800; color: #0F172A; margin-top: 2px; font-family: monospace;">
            #${quote.quoteNumber}
          </div>
          <div style="font-size: 11.5px; color: #475569; margin-top: 8px;">
            <strong>Date:</strong> ${quoteDate}<br>
            <strong>Valid Till:</strong> ${validUntilDate}
          </div>
        </td>
      </tr>
    </table>

    <!-- Customer & Vehicle Info Grid -->
    <table style="width: 100%; margin-bottom: 24px; border-collapse: separate; border-spacing: 12px 0;">
      <tr>
        <td style="width: 50%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 14px; vertical-align: top;">
          <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;">
            Customer Information
          </div>
          <div style="font-size: 14px; font-weight: 700; color: #0F172A; margin-bottom: 4px;">
            ${customer.name || 'Valued Customer'}
          </div>
          <div style="font-size: 12.5px; color: #334155; line-height: 1.5;">
            <strong>Mobile:</strong> +91 ${customer.mobile || '-'}<br>
            <strong>Email:</strong> ${customer.email || 'Not Provided'}<br>
            <strong>Address:</strong> ${customer.address || 'Pune, Maharashtra'}
          </div>
        </td>

        <td style="width: 50%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 14px; vertical-align: top;">
          <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;">
            Vehicle Details
          </div>
          <div style="font-size: 14px; font-weight: 700; color: #0F172A; margin-bottom: 4px;">
            ${vehicle.name || 'Honda Two-Wheeler'}
          </div>
          <div style="font-size: 12.5px; color: #334155; line-height: 1.5;">
            <strong>Selected Colour:</strong> ${quote.colourName || '-'}<br>
            <strong>Category:</strong> ${vehicle.category || 'Motorcycle'}<br>
            <strong>Executive:</strong> ${quote.enquiry?.createdBy?.name || 'Showroom Sales Team'}
          </div>
        </td>
      </tr>
    </table>

    <!-- Price Breakdown Table -->
    <div style="margin-bottom: 24px;">
      <div style="font-size: 13px; font-weight: 800; color: #0F172A; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px;">
        Itemized On-Road Price Quotation
      </div>
      <table style="width: 100%; border-collapse: collapse; border: 1px solid #CBD5E1; border-radius: 6px; overflow: hidden;">
        <thead>
          <tr style="background: #F1F5F9; text-align: left;">
            <th style="padding: 10px 14px; font-size: 12px; font-weight: 700; color: #475569; border-bottom: 1px solid #CBD5E1;">Component / Item Description</th>
            <th style="padding: 10px 14px; font-size: 12px; font-weight: 700; color: #475569; border-bottom: 1px solid #CBD5E1; text-align: right; width: 140px;">Amount (INR)</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; font-size: 13px; color: #1E293B;">1. Ex-Showroom Price</td>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; text-align: right; font-weight: 600; font-size: 13px; color: #1E293B;">${formatINR(quote.exShowroom)}</td>
          </tr>
          <tr>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; font-size: 13px; color: #1E293B;">2. RTO Registration & Road Tax</td>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; text-align: right; font-weight: 600; font-size: 13px; color: #1E293B;">${formatINR(quote.roadTax)}</td>
          </tr>
          <tr>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; font-size: 13px; color: #1E293B;">3. Comprehensive Insurance (1-Yr OD + 5-Yr TP)</td>
            <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; text-align: right; font-weight: 600; font-size: 13px; color: #1E293B;">${formatINR(quote.insurance)}</td>
          </tr>
          ${itemsRows}
          ${accessories.length > 0 ? `
          <tr style="background: #FAFAFA;">
            <td colspan="2" style="padding: 8px 14px; font-size: 12px; font-weight: 700; color: #0F172A; border-bottom: 1px solid #E2E8F0;">
              Selected Dealer Accessories & Add-ons
            </td>
          </tr>
          ${accessoriesRows}
          ` : ''}
          <tr style="background: #FFF1F2;">
            <td style="padding: 14px; font-size: 15px; font-weight: 900; color: #991B1B;">
              GRAND TOTAL ON-ROAD PRICE
            </td>
            <td style="padding: 14px; font-size: 18px; font-weight: 900; color: #DC2626; text-align: right;">
              ${formatINR(quote.grandTotal)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Bank Details & Payment Info -->
    <table style="width: 100%; margin-bottom: 24px; border-collapse: separate; border-spacing: 12px 0;">
      <tr>
        <td style="width: 60%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px; vertical-align: top;">
          <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; margin-bottom: 6px;">
            Bank Transfer Details (NEFT / RTGS / IMPS)
          </div>
          <div style="font-size: 12px; color: #334155; line-height: 1.5;">
            <strong>Bank:</strong> ${settings.bankName || 'HDFC Bank'}<br>
            <strong>Account Number:</strong> ${settings.accountNumber || '50200098765432'}<br>
            <strong>IFSC Code:</strong> ${settings.ifsc || 'HDFC0001234'}<br>
            <strong>UPI ID:</strong> ${settings.upiId || 'yashhonda@hdfcbank'}
          </div>
        </td>
        <td style="width: 40%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px; vertical-align: top; text-align: center;">
          <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; margin-bottom: 6px;">
            Scan & Pay via UPI
          </div>
          <img src="${settings.upiQrUrl || `https://api.qrserver.com/v1/create-qr-code/?size=90x90&data=upi://pay?pa=${encodeURIComponent(settings.upiId || 'yashhonda@hdfcbank')}%26pn=${encodeURIComponent(settings.companyName || 'Yash Honda')}%26am=${quote.grandTotal}`}" alt="UPI QR" style="width: 80px; height: 80px; margin: 0 auto; display: block; object-fit: contain;" />
        </td>
      </tr>
    </table>

    <!-- Terms & Conditions -->
    <div style="margin-bottom: 30px; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px;">
      <div style="font-size: 11px; font-weight: 800; color: #64748B; text-transform: uppercase; margin-bottom: 4px;">
        Terms & Conditions
      </div>
      <div style="font-size: 11.5px; color: #475569; line-height: 1.5;">
        ${settings.quotationTerms || 'Prices indicative and subject to change. Delivery subject to vehicle availability. RTO charges and taxes as per prevailing government rules.'}
      </div>
    </div>

    <!-- Signatures -->
    <table style="width: 100%; margin-top: 40px; padding-top: 20px;">
      <tr>
        <td style="width: 50%; vertical-align: bottom;">
          <div style="width: 180px; border-bottom: 1px solid #94A3B8; margin-bottom: 6px;"></div>
          <div style="font-size: 12px; font-weight: 600; color: #475569;">Customer Signature</div>
        </td>
        <td style="width: 50%; vertical-align: bottom; text-align: right;">
          <div style="font-size: 12px; font-weight: 700; color: #0F172A; margin-bottom: 40px;">For Yash Honda</div>
          <div style="display: inline-block; width: 180px; border-bottom: 1px solid #94A3B8; margin-bottom: 6px;"></div>
          <div style="font-size: 12px; font-weight: 600; color: #475569;">Authorized Signatory</div>
        </td>
      </tr>
    </table>
  </div>

  <script>
    // Automatically trigger browser print dialog on load
    window.addEventListener('load', function() {
      setTimeout(function() {
        window.print();
      }, 400);
    });
  </script>
</body>
</html>`;
  }
}

