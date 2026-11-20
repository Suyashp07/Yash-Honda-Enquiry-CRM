import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/currency_formatter.dart';

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

  Future<void> _sendWhatsApp() async {
    setState(() => _isSendingWA = true);
    final customer = widget.enquiry['customer'] ?? {};
    final mobile = customer['mobile']?.toString() ?? '';
    final custName = customer['name']?.toString() ?? 'Customer';
    final q = widget.quotation;
    final quoteNumber = q['quoteNumber'] ?? 'QUOTE';
    final grandTotal = CurrencyFormatter.format(q['grandTotal']);
    final vName = q['vehicle']?['name']?.toString() ?? 'Honda Vehicle';

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/communications/whatsapp', data: {
        'enquiryId': widget.enquiry['id'],
        'templateName': 'quotation_send',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        final mode = res.data['mode']?.toString();
        if (mode == 'live_meta') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Official quotation dispatched to customer via Meta WhatsApp!')),
          );
        } else {
          // Open WhatsApp Web/App directly with pre-filled quotation
          final text = Uri.encodeComponent(
            'Namaste $custName, thank you for visiting Yash Honda! Here is your official quotation for $vName:\n\n'
            '• Quote No: $quoteNumber\n'
            '• Grand Total: $grandTotal\n\n'
            'Our sales team will follow up with you shortly. Yash Honda Pune.',
          );
          final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9]'), '');
          final waUrl = Uri.parse('https://wa.me/91$cleanMobile?text=$text');
          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Opening WhatsApp with pre-filled quotation...')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WhatsApp send error: $e')),
        );
      }
    } finally {
      setState(() => _isSendingWA = false);
    }
  }

  Future<void> _sendEmail() async {
    final customerEmail = widget.enquiry['customer']?['email'];
    if (customerEmail == null || customerEmail.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Customer has no email address on record')),
      );
      return;
    }

    setState(() => _isSendingEmail = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/communications/email', data: {
        'enquiryId': widget.enquiry['id'],
        'recipientEmail': customerEmail,
        'subject': 'Your Official Quotation - Yash Honda Pune',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        final msg = res.data['message']?.toString() ??
            'Quotation emailed to customer via Brevo!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email send error: $e')),
        );
      }
    } finally {
      setState(() => _isSendingEmail = false);
    }
  }

  Future<void> _printQuotation() async {
    final q = widget.quotation;
    final quoteNumber = q['quoteNumber']?.toString() ?? '';
    final quoteId = q['id']?.toString() ?? quoteNumber;

    if (quoteId.isEmpty && quoteNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation identifier not found')),
      );
      return;
    }

    final identifier = quoteNumber.isNotEmpty ? quoteNumber : quoteId;
    final printUrl = '${ApiConstants.baseUrl}/quotations/$identifier/print';

    try {
      final uri = Uri.parse(printUrl);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Opening printable quotation in browser... Ready to print or save as PDF.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open print window: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quotation.isEmpty || widget.quotation['id'] == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Quotation Actions')),
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
    final customer = widget.enquiry['customer'] ?? {};
    final quoteNumber = q['quoteNumber'] ?? 'QUOTE';

    final vehicleName = q['vehicle']?['name']?.toString() ??
        ((widget.enquiry['quotations'] as List?)
                ?.firstWhere(
                  (item) => item['id'] == q['id'],
                  orElse: () => null,
                )?['vehicle']?['name']
                ?.toString() ??
            '');
    final colourName = q['colourName']?.toString() ?? '';
    final modelAndColour =
        [vehicleName, colourName].where((s) => s.isNotEmpty).join(' • ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Tooltip(
          message: 'Official quotation reference generated for this session',
          child: Text('Quotation #$quoteNumber Generated'),
        ),
        actions: [
          Tooltip(
            message: 'Create a new customer walk-in or telephonic enquiry',
            child: TextButton.icon(
              onPressed: () => context.go('/enquiries/vehicle-picker'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Enquiry'),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check,
                    size: 36, color: AppColors.statusBought),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enquiry & Quotation Created Successfully!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Tooltip(
                message: 'Official quotation reference number registered in Yash Honda database',
                child: Text(
                  'Official Quote Number: $quoteNumber',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),

              // Quote Snapshot Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Tooltip(
                        message: 'Primary customer name recorded during walk-in consultation',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Customer Name:',
                                style: TextStyle(color: AppColors.textSecondary)),
                            Text(customer['name'] ?? '',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: 'Primary contact number for WhatsApp quotation & callback reminders',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Customer Mobile:',
                                style: TextStyle(color: AppColors.textSecondary)),
                            Text(customer['mobile'] ?? '',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: 'Selected Honda two-wheeler model variant and factory paint finish',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Model & Colour:',
                                style: TextStyle(color: AppColors.textSecondary)),
                            Text(
                              modelAndColour.isEmpty
                                  ? (colourName.isEmpty ? '-' : colourName)
                                  : modelAndColour,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),
                      Tooltip(
                        message: 'On-road quotation total including Ex-showroom, RTO registration, Insurance & Accessories',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Grand Total Quotation:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w900)),
                            Text(
                              CurrencyFormatter.format(q['grandTotal']),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Actions Buttons
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Send official quotation greeting and summary PDF to customer via WhatsApp (+91 ${customer['mobile'] ?? ''})',
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSendingWA ? null : _sendWhatsApp,
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: _isSendingWA
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Send WhatsApp'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message: customer['email'] != null && customer['email'].toString().isNotEmpty
                          ? 'Send official PDF quotation directly to customer email (${customer['email']})'
                          : 'No email address registered for this customer',
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isSendingEmail ? null : _sendEmail,
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: _isSendingEmail
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Send Email'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Open official Yash Honda formatted quotation PDF in browser to print or save as file',
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _printQuotation,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print Quotation'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message: 'Return to dealership enquiries directory and pipeline overview',
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => context.go('/enquiries'),
                        child: const Text('View All Enquiries'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
