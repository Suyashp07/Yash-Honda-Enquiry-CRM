import * as crypto from 'crypto';

export const DEFAULT_QUOTATION_VALIDITY_DAYS = 15;
export const DEFAULT_QUOTATION_TERMS =
  'Prices indicative and subject to change without prior notice. Insurance coverage as per IRDAI terms. Delivery subject to stock availability and RTO registration clearance. E&OE.';

export function escapeHtml(value: unknown): string {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function formatINR(amount: unknown): string {
  const num = Number((amount as any)?.toString?.() ?? amount) || 0;
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(num);
}

export function hasVerifiedCompanySettings(settings: any): {
  valid: boolean;
  missingFields: string[];
} {
  const missing: string[] = [];
  if (!settings?.companyName?.trim()) missing.push('Company Name');
  if (!settings?.gstNumber?.trim() || String(settings.gstNumber).includes('XXXX')) {
    missing.push('GST Number');
  }
  if (!settings?.bankName?.trim()) missing.push('Bank Name');
  if (!settings?.accountNumber?.trim()) missing.push('Account Number');
  if (!settings?.ifsc?.trim()) missing.push('IFSC Code');
  if (!settings?.upiId?.trim()) missing.push('UPI ID');
  return { valid: missing.length === 0, missingFields: missing };
}

export function reconcileQuotationTotals(quotation: any): {
  reconciled: boolean;
  computedTotal: number;
  storedTotal: number;
} {
  const items: any[] = Array.isArray(quotation?.items) ? quotation.items : [];
  const accessories: any[] = Array.isArray(quotation?.accessories) ? quotation.accessories : [];

  const itemsSum =
    items.length > 0
      ? items.reduce((sum, it) => sum + (Number(it.amount) || 0), 0)
      : (Number(quotation?.exShowroom) || 0) +
        (Number(quotation?.roadTax) || 0) +
        (Number(quotation?.insurance) || 0);

  const accessoriesSum = accessories.reduce((sum, acc) => sum + (Number(acc.amount) || 0), 0);
  const computedTotal = Math.round(itemsSum + accessoriesSum);
  const storedTotal = Math.round(Number(quotation?.grandTotal) || 0);

  return {
    reconciled: Math.abs(computedTotal - storedTotal) <= 1,
    computedTotal,
    storedTotal,
  };
}

function getSigningSecret(): string {
  return process.env.JWT_SECRET || process.env.QUOTATION_SIGN_SECRET || 'yash-honda-quote-signing-secret';
}

export function signPrintToken(quotationId: string, expiresAtEpochMs: number): string {
  return crypto
    .createHmac('sha256', getSigningSecret())
    .update(`${quotationId}:${expiresAtEpochMs}`)
    .digest('hex');
}

export function verifyPrintToken(quotationId: string, token?: string, expires?: string): boolean {
  if (!token || !expires) return false;
  const expiresMs = Number(expires);
  if (!Number.isFinite(expiresMs) || Date.now() > expiresMs) return false;
  const expected = signPrintToken(quotationId, expiresMs);
  const tokenBuf = Buffer.from(token);
  const expectedBuf = Buffer.from(expected);
  if (tokenBuf.length !== expectedBuf.length) return false;
  return crypto.timingSafeEqual(tokenBuf, expectedBuf);
}

export interface RenderQuotationOptions {
  mode: 'print' | 'email';
  validityDays?: number;
}

export function renderCanonicalQuotationHtml(
  quote: any,
  settings: any,
  options: RenderQuotationOptions = { mode: 'print' },
): string {
  const validityDays = options.validityDays ?? DEFAULT_QUOTATION_VALIDITY_DAYS;
  const createdAt = quote?.createdAt ? new Date(quote.createdAt) : new Date();
  const validUntil = new Date(createdAt.getTime() + validityDays * 24 * 60 * 60 * 1000);

  const formatDate = (d: Date) =>
    d.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

  const quoteDateStr = formatDate(createdAt);
  const validUntilStr = formatDate(validUntil);

  const customer = quote?.enquiry?.customer || {};
  const vehicle = quote?.vehicle || {};
  const branch = quote?.branch || quote?.enquiry?.branch || {};
  const enquiry = quote?.enquiry || {};

  const vehicleWing =
    vehicle.modelGroup?.name?.toLowerCase().includes('big') || vehicle.category === 'BigBike'
      ? 'BigWing'
      : vehicle.modelGroup?.name
      ? 'RedWing'
      : null;
  const wing =
    vehicleWing ||
    branch.wing ||
    (String(quote?.quoteNumber || '').startsWith('BW') ? 'BigWing' : 'RedWing');
  const isBigWing = wing === 'BigWing';

  const companyName = escapeHtml(settings?.companyName || 'Yash Honda');
  const branchName = escapeHtml(branch?.name || 'Showroom');
  const branchCode = escapeHtml(branch?.code || '');
  const branchAddress = escapeHtml(branch?.address || settings?.address || 'Address not configured');
  const gstNumber = settings?.gstNumber?.trim()
    ? escapeHtml(settings.gstNumber)
    : 'Not configured';
  const quoteNumber = escapeHtml(quote?.quoteNumber || 'DRAFT');
  const terms = escapeHtml(settings?.quotationTerms || DEFAULT_QUOTATION_TERMS);

  // Build non-duplicated line items
  const rawItems: any[] = Array.isArray(quote?.items) && quote.items.length > 0
    ? quote.items
    : [
        { label: 'Ex-Showroom Price', amount: quote?.exShowroom || 0 },
        { label: 'RTO Registration & Road Tax', amount: quote?.roadTax || 0 },
        { label: 'Comprehensive Insurance', amount: quote?.insurance || 0 },
      ];

  const itemsRows = rawItems
    .map(
      (it, idx) => `
      <tr>
        <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; color: #334155; font-size: 13px;">
          ${idx + 1}. ${escapeHtml(it.label)}
        </td>
        <td style="padding: 10px 14px; border-bottom: 1px solid #E2E8F0; text-align: right; font-weight: 600; color: #0F172A; font-size: 13px;">
          ${formatINR(it.amount)}
        </td>
      </tr>`,
    )
    .join('');

  const accessories: any[] = Array.isArray(quote?.accessories) ? quote.accessories : [];
  const accessoriesRows = accessories
    .map(
      (acc) => `
      <tr>
        <td style="padding: 8px 14px 8px 28px; border-bottom: 1px solid #F1F5F9; color: #475569; font-size: 12.5px;">
          &bull; ${escapeHtml(acc.accessory?.name || 'Accessory')}
        </td>
        <td style="padding: 8px 14px; border-bottom: 1px solid #F1F5F9; text-align: right; color: #0F172A; font-weight: 600; font-size: 12.5px;">
          ${formatINR(acc.amount)}
        </td>
      </tr>`,
    )
    .join('');

  const verification = hasVerifiedCompanySettings(settings);
  const bankSectionHtml = verification.valid
    ? `
      <table style="width: 100%; margin-bottom: 24px; border-collapse: separate; border-spacing: 12px 0;">
        <tr>
          <td style="width: 60%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px; vertical-align: top;">
            <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 6px;">
              Bank Transfer Details (NEFT / RTGS / IMPS)
            </div>
            <div style="font-size: 12px; color: #334155; line-height: 1.6;">
              <strong>Bank:</strong> ${escapeHtml(settings.bankName)}<br>
              <strong>Account Number:</strong> ${escapeHtml(settings.accountNumber)}<br>
              <strong>IFSC Code:</strong> ${escapeHtml(settings.ifsc)}<br>
              <strong>UPI ID:</strong> ${escapeHtml(settings.upiId)}
            </div>
          </td>
          <td style="width: 40%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px; vertical-align: top; text-align: center;">
            <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 6px;">
              UPI Payment
            </div>
            ${
              settings?.upiQrUrl
                ? `<img src="${escapeHtml(settings.upiQrUrl)}" alt="Verified UPI QR" style="width: 84px; height: 84px; margin: 0 auto; display: block; object-fit: contain;" />`
                : `<div style="font-size: 12px; color: #334155; padding: 12px 6px;">Pay via UPI ID:<br><strong>${escapeHtml(settings.upiId)}</strong></div>`
            }
          </td>
        </tr>
      </table>`
    : `
      <div style="margin-bottom: 24px; background: #FFFBEB; border: 1px solid #FDE68A; border-radius: 6px; padding: 12px 14px; font-size: 12px; color: #92400E;">
        <strong>Payment details not verified:</strong> Official dealership bank/GST/UPI details must be configured in Company Settings before collecting payment.
      </div>`;

  const printToolbar =
    options.mode === 'print'
      ? `
  <div class="no-print">
    <div style="font-weight: 700; font-size: 14px;">
      ${companyName} Official Quotation &bull; ${quoteNumber}
    </div>
    <div style="display: flex; gap: 12px;">
      <button class="btn-print" onclick="window.print()">Print / Save as PDF</button>
      <button onclick="window.close()" style="background: transparent; color: #CBD5E1; border: 1px solid #475569; padding: 8px 14px; border-radius: 6px; cursor: pointer; font-size: 13px;">Close</button>
    </div>
  </div>`
      : '';

  const printScript =
    options.mode === 'print'
      ? `
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.print(); }, 400);
    });
  </script>`
      : '';

  const containerStyle =
    options.mode === 'email'
      ? 'max-width: 600px; margin: 16px auto; background: #FFFFFF; padding: 24px; border-radius: 12px; border: 1px solid #E2E8F0;'
      : 'max-width: 820px; margin: 28px auto; background: #FFFFFF; padding: 40px; border-radius: 8px; border: 1px solid #E2E8F0;';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Quotation ${quoteNumber} - ${companyName}</title>
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
    }
    .btn-print {
      background: #CC0000;
      color: white;
      border: none;
      padding: 8px 18px;
      font-weight: 700;
      font-size: 13px;
      border-radius: 6px;
      cursor: pointer;
    }
    @media print {
      body { background: white; }
      .no-print { display: none !important; }
      .page-container { border: none !important; margin: 0 !important; padding: 10mm 12mm !important; max-width: 100% !important; }
      @page { size: A4; margin: 8mm; }
    }
  </style>
</head>
<body>
  ${printToolbar}
  <div class="page-container" style="${containerStyle}">
    <table style="width: 100%; background: ${isBigWing ? '#0F172A' : '#FFFFFF'}; color: ${isBigWing ? '#FFFFFF' : '#0F172A'}; border-radius: 8px; padding: 18px 20px; border: 1px solid ${isBigWing ? '#0F172A' : '#E2E8F0'}; border-bottom: 3px solid ${isBigWing ? '#F59E0B' : '#CC0000'}; margin-bottom: 22px;">
      <tr>
        <td style="vertical-align: top;">
          <div style="font-size: 22px; font-weight: 700; color: ${isBigWing ? '#FFFFFF' : '#CC0000'};">${companyName}</div>
          <div style="font-size: 12px; color: ${isBigWing ? '#FDE68A' : '#CC0000'}; margin-top: 4px; font-weight: 600;">
            Authorised ${escapeHtml(wing)} Dealer &bull; Honda Motorcycle and Scooter India Pvt. Ltd.
          </div>
          <div style="font-size: 12px; color: ${isBigWing ? '#CBD5E1' : '#475569'}; margin-top: 6px; line-height: 1.5;">
            <strong>Branch:</strong> ${branchName}${branchCode ? ` (${branchCode})` : ''}<br>
            ${branchAddress}<br>
            <strong>GSTIN:</strong> ${gstNumber}
          </div>
        </td>
        <td style="vertical-align: top; text-align: right;">
          <div style="font-size: 11px; font-weight: 700; color: ${isBigWing ? '#CBD5E1' : '#64748B'}; letter-spacing: 0.8px; text-transform: uppercase;">
            Official Quotation
          </div>
          <div style="font-size: 16px; font-weight: 700; color: ${isBigWing ? '#FFFFFF' : '#0F172A'}; margin-top: 4px; font-family: monospace;">
            #${quoteNumber}
          </div>
          <div style="font-size: 12px; color: ${isBigWing ? '#E2E8F0' : '#475569'}; margin-top: 8px; line-height: 1.5;">
            <strong>Date:</strong> ${escapeHtml(quoteDateStr)}<br>
            <strong>Valid Till:</strong> ${escapeHtml(validUntilStr)} (${validityDays} Days)
          </div>
        </td>
      </tr>
    </table>

    <table style="width: 100%; margin-bottom: 24px; border-collapse: separate; border-spacing: 12px 0;">
      <tr>
        <td style="width: 50%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 14px; vertical-align: top;">
          <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 8px;">Customer Information</div>
          <div style="font-size: 14px; font-weight: 700; color: #0F172A; margin-bottom: 4px;">${escapeHtml(customer.name || 'Valued Customer')}</div>
          <div style="font-size: 12.5px; color: #334155; line-height: 1.5;">
            <strong>Mobile:</strong> ${customer.mobile ? `+91 ${escapeHtml(customer.mobile)}` : '-'}<br>
            <strong>Email:</strong> ${escapeHtml(customer.email || 'Not Provided')}<br>
            <strong>Address:</strong> ${escapeHtml(customer.address || 'Not Provided')}
          </div>
        </td>
        <td style="width: 50%; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 14px; vertical-align: top;">
          <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 8px;">Vehicle Details</div>
          <div style="font-size: 14px; font-weight: 700; color: #0F172A; margin-bottom: 4px;">${escapeHtml(vehicle.name || 'Honda Two-Wheeler')}</div>
          <div style="font-size: 12.5px; color: #334155; line-height: 1.5;">
            <strong>Selected Colour:</strong> ${escapeHtml(quote?.colourName || '-')}<br>
            <strong>Purchase Mode:</strong> ${escapeHtml(enquiry?.purchaseMode || 'Cash')}<br>
            <strong>Executive:</strong> ${escapeHtml(enquiry?.createdBy?.name || 'Showroom Sales Team')}
          </div>
        </td>
      </tr>
    </table>

    <div style="margin-bottom: 24px;">
      <div style="font-size: 13px; font-weight: 700; color: #0F172A; margin-bottom: 8px; text-transform: uppercase;">
        Itemized On-Road Price Quotation
      </div>
      <table style="width: 100%; border-collapse: collapse; border: 1px solid #CBD5E1; border-radius: 6px; overflow: hidden;">
        <thead>
          <tr style="background: #F1F5F9; text-align: left;">
            <th style="padding: 10px 14px; font-size: 12px; font-weight: 700; color: #475569; border-bottom: 1px solid #CBD5E1;">Component / Item Description</th>
            <th style="padding: 10px 14px; font-size: 12px; font-weight: 700; color: #475569; border-bottom: 1px solid #CBD5E1; text-align: right; width: 150px;">Amount (INR)</th>
          </tr>
        </thead>
        <tbody>
          ${itemsRows}
          ${
            accessories.length > 0
              ? `
          <tr style="background: #FAFAFA;">
            <td colspan="2" style="padding: 8px 14px; font-size: 12px; font-weight: 700; color: #0F172A; border-bottom: 1px solid #E2E8F0;">
              Selected Dealer Accessories &amp; Add-ons
            </td>
          </tr>
          ${accessoriesRows}`
              : ''
          }
          <tr style="background: #FFE5E5;">
            <td style="padding: 14px; font-size: 15px; font-weight: 700; color: #990000;">GRAND TOTAL ON-ROAD PRICE</td>
            <td style="padding: 14px; font-size: 18px; font-weight: 700; color: #CC0000; text-align: right;">${formatINR(quote?.grandTotal)}</td>
          </tr>
        </tbody>
      </table>
    </div>

    ${bankSectionHtml}

    <div style="margin-bottom: 24px; background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 6px; padding: 12px 14px;">
      <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; margin-bottom: 4px;">Terms &amp; Conditions</div>
      <div style="font-size: 11.5px; color: #475569; line-height: 1.5;">${terms}</div>
    </div>

    <table style="width: 100%; margin-top: 24px;">
      <tr>
        <td style="width: 50%; vertical-align: bottom;">
          <div style="width: 180px; border-bottom: 1px solid #94A3B8; margin-bottom: 6px;"></div>
          <div style="font-size: 12px; font-weight: 600; color: #475569;">Customer Signature</div>
        </td>
        <td style="width: 50%; vertical-align: bottom; text-align: right;">
          <div style="font-size: 12px; font-weight: 700; color: #0F172A; margin-bottom: 32px;">For ${companyName}</div>
          <div style="display: inline-block; width: 180px; border-bottom: 1px solid #94A3B8; margin-bottom: 6px;"></div>
          <div style="font-size: 12px; font-weight: 600; color: #475569;">Authorized Signatory</div>
        </td>
      </tr>
    </table>
  </div>
  ${printScript}
</body>
</html>`;
}
