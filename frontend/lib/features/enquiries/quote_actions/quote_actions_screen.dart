import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/file_download.dart';
import '../../../shared/widgets/app_components.dart';

class QuoteActionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> enquiry;
  final Map<String, dynamic> quotation;

  const QuoteActionsScreen({
    super.key,
    required this.enquiry,
    required this.quotation,
  });

  @override
  ConsumerState<QuoteActionsScreen> createState() => _QuoteActionsScreenState();
}

class _QuoteActionsScreenState extends ConsumerState<QuoteActionsScreen> {
  bool _isSendingWA = false;
  bool _isSendingEmail = false;
  bool _isDownloadingPdf = false;
  bool _waSent = false;
  bool _emailSent = false;
  String? _waStatus;
  String? _emailStatus;

  String _pdfRs(num amount) =>
      CurrencyFormatter.format(amount).replaceAll('₹', 'Rs. ');

  Future<String> _getSignedPrintUrl() async {
    final q = widget.quotation;
    final quoteIdOrNum = (q['id'] ?? q['quoteNumber'] ?? '').toString();
    final dio = ref.read(dioProvider);
    final res = await dio.get('/quotations/$quoteIdOrNum/signed-print-url');
    final relUrl = res.data?['url']?.toString() ?? '';
    final baseOrigin = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$baseOrigin$relUrl';
  }

  Future<void> _sendWhatsApp() async {
    final customer = widget.enquiry['customer'] ?? {};
    final mobile = customer['mobile']?.toString() ?? '';
    final custName = customer['name']?.toString() ?? 'Customer';
    final q = widget.quotation;
    final quoteNumber = q['quoteNumber'] ?? 'QUOTE';
    final grandTotal = CurrencyFormatter.format(q['grandTotal']);
    final vName = q['vehicle']?['name']?.toString() ?? 'Honda Vehicle';

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm WhatsApp Dispatch',
      message:
          'Send Quotation #$quoteNumber ($grandTotal) for $vName to $custName (+91 $mobile)?',
      confirmLabel: 'Send WhatsApp',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSendingWA = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/communications/whatsapp', data: {
        'enquiryId': widget.enquiry['id'],
        'templateName': 'quotation_send',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        final mode = res.data['mode']?.toString();
        final status = res.data['status']?.toString() ?? 'accepted';
        setState(() {
          _waSent = status != 'failed';
          _waStatus = status;
        });
        if (mode == 'live_meta') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.info,
              content:
                  Text('Quotation accepted by Meta WhatsApp (awaiting delivery webhook).'),
            ),
          );
        } else {
          final signedUrl = await _getSignedPrintUrl();
          final brochureUrl =
              widget.quotation['vehicle']?['brochureUrl']?.toString() ?? '';
          final text = Uri.encodeComponent(
            'Namaste $custName, thank you for visiting Yash Honda! Here is your official quotation for $vName:\n\n'
            '• Quote No: $quoteNumber\n'
            '• Grand Total: $grandTotal\n'
            '• Quotation PDF / Print: $signedUrl\n'
            '${brochureUrl.isNotEmpty ? '• Official Vehicle Brochure (PDF): $brochureUrl\n' : ''}\n'
            'Our sales team will follow up with you shortly. Yash Honda Pune.',
          );
          final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
          final waUrl = Uri.parse('https://wa.me/91$cleanMobile?text=$text');
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.warning,
                content:
                    Text('Simulated API send recorded; opening WhatsApp composer.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _waStatus = 'failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Could not send WhatsApp quotation: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingWA = false);
    }
  }

  Future<void> _sendEmail() async {
    var customerEmail = widget.enquiry['customer']?['email']?.toString() ?? '';
    if (customerEmail.trim().isEmpty || !customerEmail.contains('@')) {
      final emailCtrl = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Enter Customer Email',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'customer@example.com',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
              child: const Text('Send Quote'),
            ),
          ],
        ),
      );
      if (entered == null || !entered.contains('@')) return;
      customerEmail = entered;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm Email Dispatch',
      message:
          'Send Quotation #${widget.quotation['quoteNumber'] ?? ''} (${CurrencyFormatter.format(widget.quotation['grandTotal'])}) to $customerEmail?',
      confirmLabel: 'Send Email',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSendingEmail = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/communications/email', data: {
        'enquiryId': widget.enquiry['id'],
        'recipientEmail': customerEmail,
        'subject':
            'Your Official Quotation (#${widget.quotation['quoteNumber'] ?? ''}) - Yash Honda Pune',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        final ok = res.data is Map && res.data['success'] == true;
        final status = (res.data is Map ? res.data['status']?.toString() : null) ??
            (ok ? 'accepted' : 'failed');
        setState(() {
          _emailSent = ok;
          _emailStatus = status;
        });
        final msg = res.data['message']?.toString() ??
            (ok ? 'Quotation accepted for email delivery.' : 'Failed to send email.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: !ok
                ? AppColors.danger
                : (status == 'simulated' ? AppColors.warning : AppColors.info),
            content: Text(msg),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Email send error.';
        if (e is DioException && e.response?.data is Map) {
          final rawMsg = (e.response!.data as Map)['message'];
          msg = rawMsg is List ? rawMsg.join(', ') : (rawMsg?.toString() ?? msg);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  Future<void> _printQuotation() async {
    final q = widget.quotation;
    final quoteNumber = q['quoteNumber']?.toString() ?? '';
    final quoteId = q['id']?.toString() ?? quoteNumber;
    final identifier = quoteNumber.isNotEmpty ? quoteNumber : quoteId;
    if (identifier.isEmpty) return;

    final printUrl = '${ApiConstants.baseUrl}/quotations/$identifier/print';
    try {
      final uri = Uri.parse(printUrl);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open print window: $e')),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    try {
      final q = widget.quotation;
      final e = widget.enquiry;
      final customer = e['customer'] ?? {};
      final branch = e['branch'] ?? {};
      final vehicle = q['vehicle'] ?? {};
      final quoteNo = q['quoteNumber']?.toString() ?? 'QUOTE';
      final isBigWing = quoteNo.toUpperCase().startsWith('BW') ||
          (vehicle['category']?.toString() == 'BigBike') ||
          (branch['wing']?.toString().toLowerCase().contains('big') ?? false);

      final wingColorHex = isBigWing ? '#E2E8F0' : '#DC2626';
      final wingSvg = '''
<svg viewBox="0 0 100 60" xmlns="http://www.w3.org/2000/svg">
  <polygon points="6,55 96,55 78,47 14,47" fill="$wingColorHex"/>
  <path d="M14,44 Q32,8 98,6 L93,13 Q36,16 24,44 Z" fill="$wingColorHex"/>
  <path d="M18,44 Q36,18 92,16 L87,23 Q40,26 28,44 Z" fill="$wingColorHex"/>
  <path d="M22,44 Q40,28 86,26 L81,33 Q44,36 32,44 Z" fill="$wingColorHex"/>
  <path d="M26,44 Q44,38 80,36 L75,43 Q48,45 36,44 Z" fill="$wingColorHex"/>
</svg>
''';

      final items = (q['items'] as List? ?? []);
      final accs = (q['accessories'] as List? ?? []);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: isBigWing
                      ? PdfColor.fromHex('#0F172A')
                      : PdfColors.white,
                  border: isBigWing
                      ? null
                      : pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'YASH HONDA',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColors.white
                                : PdfColor.fromHex('#DC2626'),
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          isBigWing
                              ? 'Authorised Honda BigWing Dealer'
                              : 'Authorised Honda RedWing Dealer',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColor.fromHex('#F59E0B')
                                : PdfColor.fromHex('#DC2626'),
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Quotation #$quoteNo',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColor.fromHex('#CBD5E1')
                                : PdfColor.fromHex('#475569'),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.SvgImage(svg: wingSvg, width: 46, height: 28),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Customer: ${customer['name'] ?? '-'}  |  Mobile: ${customer['mobile'] ?? '-'}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Vehicle: ${vehicle['name'] ?? '-'} (${q['colourName'] ?? '-'})',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
                children: [
                  for (final it in items)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(it['label']?.toString() ?? '',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            _pdfRs(num.tryParse(it['amount']?.toString() ?? '0') ?? 0),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ]),
                  for (final a in accs)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            a['accessory']?['name']?.toString() ?? 'Add-on',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            _pdfRs(num.tryParse(a['amount']?.toString() ?? '0') ?? 0),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ]),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: isBigWing
                      ? PdfColor.fromHex('#FFFBEB')
                      : PdfColor.fromHex('#FEF2F2'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Grand Total Quotation',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      _pdfRs(num.tryParse(q['grandTotal']?.toString() ?? '0') ?? 0),
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: isBigWing
                            ? PdfColor.fromHex('#D97706')
                            : PdfColor.fromHex('#DC2626'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      final bytes = await doc.save();
      downloadFileBytes(bytes, 'Quotation-$quoteNo.pdf', 'application/pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Downloaded Quotation-$quoteNo.pdf'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotation.isEmpty || widget.quotation['id'] == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('No active quotation in session.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/enquiries'),
                child: const Text('View All Enquiries'),
              ),
            ],
          ),
        ),
      );
    }

    final q = widget.quotation;
    final e = widget.enquiry;
    final customer = e['customer'] ?? {};
    final branch = e['branch'] ?? {};
    final quoteNumber = q['quoteNumber']?.toString() ?? 'QUOTE';
    final isBigWing = quoteNumber.toUpperCase().startsWith('BW') ||
        (branch['wing']?.toString().toLowerCase().contains('big') ?? false);

    final vehicleName = q['vehicle']?['name']?.toString() ??
        ((e['quotations'] as List?)
                ?.firstWhere(
                  (item) => item['id'] == q['id'],
                  orElse: () => null,
                )?['vehicle']?['name']
                ?.toString() ??
            'Honda Vehicle');
    final colourName = q['colourName']?.toString() ?? '-';
    final items = (q['items'] as List? ?? []);
    final accessories = (q['accessories'] as List? ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Confirmation Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 28, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enquiry & Quotation Created',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isBigWing
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isBigWing ? 'BigWing' : 'RedWing',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isBigWing
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Quote #$quoteNumber',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: quoteNumber));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Copied $quoteNumber to clipboard')),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded,
                                      size: 15, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/enquiries'),
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        label: const Text('View Enquiry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2-Column Content: Left Summary Breakdown | Right Dispatch Hub
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 740;
                    final breakdownCard = Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUOTATION BREAKDOWN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _infoRow('Customer', customer['name']?.toString() ?? '-'),
                          _infoRow('Mobile', customer['mobile']?.toString() ?? '-'),
                          if ((customer['email']?.toString() ?? '').isNotEmpty)
                            _infoRow('Email', customer['email'].toString()),
                          _infoRow(
                              'Branch', branch['name']?.toString() ?? 'Showroom'),
                          _infoRow('Vehicle', '$vehicleName • $colourName'),
                          _infoRow('Purchase Mode',
                              e['purchaseMode']?.toString() ?? 'Cash'),
                          const Divider(height: 24),
                          if (items.isNotEmpty || accessories.isNotEmpty) ...[
                            for (final it in items)
                              _priceRow(
                                it['label']?.toString() ?? 'Item',
                                CurrencyFormatter.format(it['amount']),
                              ),
                            for (final a in accessories)
                              _priceRow(
                                a['accessory']?['name']?.toString() ?? 'Add-on',
                                CurrencyFormatter.format(a['amount']),
                              ),
                            const Divider(height: 20),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total Quotation',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(q['grandTotal']),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: isBigWing
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    final actionsCard = Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'SHARE & DOWNLOAD',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSendingWA ? null : _sendWhatsApp,
                            icon: Icon(
                                _waSent
                                    ? Icons.check_circle_outline
                                    : Icons.chat_outlined,
                                size: 18),
                            label: Text(_isSendingWA
                                ? 'Sending WhatsApp...'
                                : _waSent
                                    ? 'WhatsApp Dispatched'
                                    : 'Send via WhatsApp'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSendingEmail ? null : _sendEmail,
                            icon: Icon(
                                _emailSent
                                    ? Icons.mark_email_read_outlined
                                    : Icons.email_outlined,
                                size: 18),
                            label: Text(_isSendingEmail
                                ? 'Sending Email...'
                                : _emailSent
                                    ? 'Email Sent'
                                    : 'Send via Email'),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isDownloadingPdf ? null : _downloadPdf,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(_isDownloadingPdf
                                ? 'Preparing PDF...'
                                : 'Download PDF Quotation'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _printQuotation,
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: const Text('Print Official Quote'),
                          ),
                          const Divider(height: 28),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.go('/enquiries'),
                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                            label: const Text('View All Enquiries'),
                          ),
                        ],
                      ),
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: breakdownCard),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: actionsCard),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        breakdownCard,
                        const SizedBox(height: 16),
                        actionsCard,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Flexible(
            child: Text(val,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
          Text(amount,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
