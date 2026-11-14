import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/communications/whatsapp', data: {
        'enquiryId': widget.enquiry['id'],
        'templateName': 'quotation_send',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Official quotation dispatched to customer WhatsApp!')),
        );
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
        const SnackBar(content: Text('Customer has no email address on record')),
      );
      return;
    }

    setState(() => _isSendingEmail = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/communications/email', data: {
        'enquiryId': widget.enquiry['id'],
        'recipientEmail': customerEmail,
        'subject': 'Your Official Quotation - Yash Honda Pune',
        'quotationId': widget.quotation['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation PDF emailed to customer via Brevo!')),
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
              const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('No active quotation in session.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quotation #$quoteNumber Generated'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/enquiries/vehicle-picker'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Enquiry'),
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
                child: const Icon(Icons.check, size: 36, color: AppColors.statusBought),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enquiry & Quotation Created Successfully!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Official Quote Number: $quoteNumber',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 24),

              // Quote Snapshot Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Customer Name:', style: TextStyle(color: AppColors.textSecondary)),
                          Text(customer['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Customer Mobile:', style: TextStyle(color: AppColors.textSecondary)),
                          Text(customer['mobile'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Model & Colour:', style: TextStyle(color: AppColors.textSecondary)),
                          Text('${q['colourName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total Quotation:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(
                            CurrencyFormatter.format(q['grandTotal']),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ],
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
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSendingWA ? null : _sendWhatsApp,
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: _isSendingWA
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSendingEmail ? null : _sendEmail,
                      icon: const Icon(Icons.email_outlined, size: 18),
                      label: _isSendingEmail
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading PDF: ${q['pdfR2Key']}')),
                        );
                      },
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print Quotation'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => context.go('/enquiries'),
                      child: const Text('View All Enquiries'),
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

