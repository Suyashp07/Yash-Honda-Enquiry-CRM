// eslint-disable-next-line @typescript-eslint/no-var-requires
const PDFDocument = require('pdfkit');

function fmtINR(amount: unknown): string {
  const num = Math.round(Number((amount as any)?.toString?.() ?? amount) || 0);
  return 'Rs. ' + num.toLocaleString('en-IN');
}

export async function generateQuotationPdfBuffer(
  quotation: any,
  enquiry: any,
  settings: any,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 40 });
    const chunks: Buffer[] = [];
    doc.on('data', (chunk: Buffer) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    const wing =
      quotation?.vehicle?.modelGroup?.name ||
      quotation?.branch?.wing ||
      (String(quotation?.quoteNumber || '').startsWith('BW') ? 'BigWing' : 'RedWing');
    const isBigWing = wing === 'BigWing';
    const accent = isBigWing ? '#B45309' : '#CC0000';
    const companyName = settings?.companyName || 'Yash Honda';
    const branchName = quotation?.branch?.name || enquiry?.branch?.name || 'Pune';
    const branchAddress =
      quotation?.branch?.address || settings?.address || 'Pune, Maharashtra';
    const gstin = settings?.gstNumber || '-';
    const quoteNumber = quotation?.quoteNumber || 'DRAFT';
    const quoteDate = new Date(quotation?.createdAt || Date.now()).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

    // Header Banner
    if (isBigWing) {
      doc.roundedRect(40, 36, 515, 84, 8).fill('#0F172A');
      doc.fillColor('#FDE68A').fontSize(20).font('Helvetica-Bold').text(companyName, 56, 50);
      doc
        .fillColor('#F59E0B')
        .fontSize(9.5)
        .font('Helvetica-Bold')
        .text('Authorised Honda BigWing Dealer', 56, 74);
      doc
        .fillColor('#CBD5E1')
        .fontSize(8.5)
        .font('Helvetica')
        .text(`Branch: ${branchName} | ${branchAddress} | GSTIN: ${gstin}`, 56, 90, {
          width: 320,
        });
      doc
        .fillColor('#94A3B8')
        .fontSize(8)
        .font('Helvetica-Bold')
        .text('OFFICIAL QUOTATION', 390, 52, { width: 150, align: 'right' });
      doc
        .fillColor('#FFFFFF')
        .fontSize(12)
        .font('Helvetica-Bold')
        .text(`#${quoteNumber}`, 390, 66, { width: 150, align: 'right' });
      doc
        .fillColor('#CBD5E1')
        .fontSize(8.5)
        .font('Helvetica')
        .text(`Date: ${quoteDate}`, 390, 86, { width: 150, align: 'right' });
    } else {
      doc.roundedRect(40, 36, 515, 84, 8).lineWidth(1).strokeColor('#E2E8F0').stroke();
      doc.fillColor('#CC0000').fontSize(20).font('Helvetica-Bold').text(companyName, 56, 50);
      doc
        .fillColor('#CC0000')
        .fontSize(9.5)
        .font('Helvetica-Bold')
        .text('Authorised Honda RedWing Dealer', 56, 74);
      doc
        .fillColor('#475569')
        .fontSize(8.5)
        .font('Helvetica')
        .text(`Branch: ${branchName} | ${branchAddress} | GSTIN: ${gstin}`, 56, 90, {
          width: 320,
        });
      doc
        .fillColor('#64748B')
        .fontSize(8)
        .font('Helvetica-Bold')
        .text('OFFICIAL QUOTATION', 390, 52, { width: 150, align: 'right' });
      doc
        .fillColor('#0F172A')
        .fontSize(12)
        .font('Helvetica-Bold')
        .text(`#${quoteNumber}`, 390, 66, { width: 150, align: 'right' });
      doc
        .fillColor('#475569')
        .fontSize(8.5)
        .font('Helvetica')
        .text(`Date: ${quoteDate}`, 390, 86, { width: 150, align: 'right' });
    }

    let y = 138;
    const customer = enquiry?.customer || {};
    doc.fillColor('#0F172A').fontSize(10.5).font('Helvetica-Bold').text('Customer & Vehicle Details', 40, y);
    y += 16;
    doc
      .fillColor('#334155')
      .fontSize(9.5)
      .font('Helvetica')
      .text(`Customer: ${customer.name || 'Valued Customer'}`, 40, y)
      .text(`Mobile: ${customer.mobile || '-'}`, 300, y);
    y += 15;
    doc
      .text(`Email: ${customer.email || '-'}`, 40, y)
      .text(`Payment Mode: ${enquiry?.purchaseMode || 'Cash'}`, 300, y);
    y += 15;
    doc
      .font('Helvetica-Bold')
      .fillColor('#0F172A')
      .text(
        `Vehicle: ${quotation?.vehicle?.name || 'Honda Two-Wheeler'} (${quotation?.colourName || 'Standard'})`,
        40,
        y,
      );
    y += 22;

    // Price Breakdown Table Header
    doc.rect(40, y, 515, 22).fill('#F1F5F9');
    doc
      .fillColor('#0F172A')
      .fontSize(9)
      .font('Helvetica-Bold')
      .text('Particulars', 50, y + 6)
      .text('Amount', 420, y + 6, { width: 125, align: 'right' });
    y += 26;

    const addLine = (label: string, amount: unknown) => {
      doc.fillColor('#334155').fontSize(9.5).font('Helvetica').text(label, 50, y);
      doc
        .fillColor('#0F172A')
        .font('Helvetica-Bold')
        .text(fmtINR(amount), 420, y, { width: 125, align: 'right' });
      y += 18;
      doc
        .moveTo(40, y - 4)
        .lineTo(555, y - 4)
        .lineWidth(0.5)
        .strokeColor('#E2E8F0')
        .stroke();
    };

    const items: any[] = Array.isArray(quotation?.items) ? quotation.items : [];
    if (items.length > 0) {
      for (const it of items) {
        addLine(it.label || 'Vehicle Charge', it.amount);
      }
    } else {
      addLine('Ex-Showroom Price', quotation?.exShowroom || 0);
      addLine('RTO Registration & Road Tax', quotation?.roadTax || 0);
      addLine('Comprehensive Insurance', quotation?.insurance || 0);
    }

    const accessories: any[] = Array.isArray(quotation?.accessories)
      ? quotation.accessories
      : [];
    for (const acc of accessories) {
      addLine(acc.accessory?.name || 'Accessory', acc.amount);
    }

    y += 6;
    doc.rect(40, y, 515, 28).fill(isBigWing ? '#0F172A' : '#FEF2F2');
    doc
      .fillColor(isBigWing ? '#FDE68A' : accent)
      .fontSize(12)
      .font('Helvetica-Bold')
      .text('Grand Total (On-Road)', 50, y + 8)
      .text(fmtINR(quotation?.grandTotal || 0), 400, y + 8, {
        width: 145,
        align: 'right',
      });

    y += 44;
    if (settings?.bankName || settings?.upiId) {
      doc
        .fillColor('#0F172A')
        .fontSize(9.5)
        .font('Helvetica-Bold')
        .text('Bank & Payment Details', 40, y);
      y += 14;
      doc
        .fillColor('#475569')
        .fontSize(8.5)
        .font('Helvetica')
        .text(
          `Bank: ${settings?.bankName || '-'}  |  A/C: ${settings?.accountNumber || '-'}  |  IFSC: ${settings?.ifsc || '-'}  |  UPI: ${settings?.upiId || '-'}`,
          40,
          y,
          { width: 515 },
        );
      y += 22;
    }

    doc
      .fillColor('#64748B')
      .fontSize(7.5)
      .font('Helvetica')
      .text(
        'Prices indicative and subject to change without prior notice. Valid for 15 days from quotation date. E&OE.',
        40,
        y,
        { width: 515 },
      );

    doc.end();
  });
}
