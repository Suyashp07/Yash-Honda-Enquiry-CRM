import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/mask_util.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_components.dart';
import '../auth/auth_notifier.dart';

class EnquiriesListScreen extends ConsumerStatefulWidget {
  const EnquiriesListScreen({super.key});

  @override
  ConsumerState<EnquiriesListScreen> createState() =>
      _EnquiriesListScreenState();
}

class _EnquiriesListScreenState extends ConsumerState<EnquiriesListScreen> {
  List<dynamic> _enquiries = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _activeTab = 'All';
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  final Set<String> _revealedMobiles = {};
  final Set<String> _revealedEmails = {};
  bool _filterFollowUpsDue = false;
  String _filterType = 'All';
  String _filterPurchaseMode = 'All';
  String _filterBranchName = 'All';

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();

  final List<String> _tabs = [
    'All',
    'Open',
    'Booked',
    'Closed',
    'Lost to competitor'
  ];

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _verticalScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEnquiries({bool showFeedback = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final activeBranch = ref.read(selectedBranchIdProvider);
      final query = <String, dynamic>{};
      if (activeBranch.isNotEmpty && activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }
      final res = await dio.get('/enquiries', queryParameters: query);

      if (!mounted) return;
      final list = (res.data as List?) ?? [];
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _enquiries = list;
        _isLoading = false;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Loaded ${list.length} enquiries.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ref.read(dataFreshnessErrorProvider.notifier).state = true;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load enquiries. Check your connection and try again.';
      });
      if (e is DioException && e.response?.statusCode == 401) {
        ref.read(authStateProvider.notifier).logout();
        context.go('/login');
      } else if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reload enquiries: $e')),
        );
      }
    }
  }

  int get _followUpsDueCount {
    int count = 0;
    final now = DateTime.now();
    for (final e in _enquiries) {
      final followUps = (e['followUps'] as List?) ?? [];
      for (final f in followUps) {
        if (f['completedAt'] == null) {
          final sched = DateTime.tryParse(f['scheduledAt']?.toString() ?? '');
          if (sched != null &&
              sched.isBefore(now.add(const Duration(days: 1)))) {
            count++;
            break;
          }
        }
      }
    }
    return count;
  }

  List<dynamic> get _filteredEnquiries {
    return _enquiries.where((e) {
      final status = (e['status'] ?? 'ACTIVE').toString().toUpperCase();
      final customer = e['customer'] ?? {};
      final name = (customer['name'] ?? '').toString().toLowerCase();
      final mobile = (customer['mobile'] ?? '').toString().toLowerCase();
      final quote = (e['quotations'] as List?)?.firstOrNull ?? {};
      final quoteNo = (quote['quoteNumber'] ?? '').toString().toLowerCase();
      final model = (quote['vehicle']?['name'] ?? '').toString().toLowerCase();

      // Search match
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = name.contains(q) ||
            mobile.contains(q) ||
            quoteNo.contains(q) ||
            model.contains(q);
        if (!matches) return false;
      }

      // Tab filter
      if (_activeTab == 'Open') {
        if (status != 'ACTIVE') return false;
      } else if (_activeTab == 'Booked') {
        if (status != 'CUSTOMER_BOUGHT' && status != 'RESOLVED') return false;
      } else if (_activeTab == 'Closed') {
        if (status != 'CLOSED') return false;
      } else if (_activeTab == 'Lost to competitor' || _activeTab == 'Other Dealer') {
        if (status != 'OTHER_DEALER' &&
            !(e['remarks']?.toString().toLowerCase().contains('other dealer') ??
                false) &&
            !(e['remarks']?.toString().toLowerCase().contains('competitor') ??
                false)) {
          return false;
        }
      }

      // Follow-ups due filter
      if (_filterFollowUpsDue) {
        final followUps = (e['followUps'] as List?) ?? [];
        if (followUps.isEmpty) return false;
      }

      if (_filterType != 'All') {
        final t = (e['enquiryType'] ?? '').toString();
        if (t != _filterType) return false;
      }

      if (_filterPurchaseMode != 'All') {
        final pm = (e['purchaseMode'] ?? '').toString();
        if (pm != _filterPurchaseMode) return false;
      }

      if (_filterBranchName != 'All') {
        final bn = (e['branch']?['name'] ?? '').toString();
        if (bn != _filterBranchName) return false;
      }

      return true;
    }).toList();
  }

  String _csvEsc(dynamic val) {
    final s = (val ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  void _exportCsv() {
    final rows = _selectedIds.isNotEmpty
        ? _filteredEnquiries
            .where((e) => _selectedIds.contains(e['id'].toString()))
            .toList()
        : _filteredEnquiries;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No enquiries to export.')),
      );
      return;
    }

    final buf = StringBuffer();
    buf.writeln(
        'Name,Mobile,Email,Type,Source,Branch,Area,Model,Colour,Payment Mode,Exchange,Buying,Date,Status,Remarks');
    for (final e in rows) {
      final customer = e['customer'] ?? {};
      final quote = (e['quotations'] as List?)?.firstOrNull ?? {};
      final vehicle = quote['vehicle'] ?? {};
      buf.writeln([
        _csvEsc(customer['name']),
        _csvEsc(customer['mobile']),
        _csvEsc(customer['email']),
        _csvEsc(e['enquiryType']),
        _csvEsc(e['leadSource']?['name']),
        _csvEsc(e['branch']?['name']),
        _csvEsc(customer['area']?['name']),
        _csvEsc(vehicle['name']),
        _csvEsc(quote['colourName']),
        _csvEsc(e['purchaseMode']),
        _csvEsc(e['exchange']),
        _csvEsc(e['buyingWhen']),
        _csvEsc(DateFormatter.formatDate(e['createdAt'])),
        _csvEsc(_mapStatusToDisplay((e['status'] ?? 'ACTIVE').toString())),
        _csvEsc(e['remarks']),
      ].join(','));
    }

    final bytes = Uint8List.fromList(utf8.encode(buf.toString()));
    downloadFileBytes(
        bytes, 'yash_honda_enquiries.csv', 'text/csv;charset=utf-8');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text(
            'Exported ${rows.length} enquiries to yash_honda_enquiries.csv'),
      ),
    );
  }

  Future<void> _printDirectory() async {
    final rows = _filteredEnquiries;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No enquiries to print.')),
      );
      return;
    }

    try {
      String esc(dynamic v) => (v ?? '')
          .toString()
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');

      final rowsHtml = rows.take(100).map((e) {
        final c = e['customer'] ?? {};
        final q = (e['quotations'] as List?)?.firstOrNull ?? {};
        final v = q['vehicle'] ?? {};
        final name = esc(c['name'] ?? '-');
        final mobile = esc(MaskUtil.maskMobile((c['mobile'] ?? '').toString()));
        final type = esc(e['enquiryType'] ?? '-');
        final branch = esc(e['branch']?['name'] ?? '-');
        final model = esc(v['name'] ?? '-');
        final mode = esc(e['purchaseMode'] ?? '-');
        final date = esc(DateFormatter.formatDate(e['createdAt']));
        final status = esc(_mapStatusToDisplay((e['status'] ?? 'ACTIVE').toString()));
        return '<tr><td>$name</td><td>$mobile</td><td>$type</td><td>$branch</td><td>$model</td><td>$mode</td><td>$date</td><td>$status</td></tr>';
      }).join('');

      final htmlDoc = '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Yash Honda - Enquiries Directory</title>
<style>
  body { font-family: Arial, sans-serif; color: #0F172A; margin: 24px; }
  h1 { font-size: 18px; margin: 0 0 4px 0; color: #CC0000; }
  p { font-size: 12px; color: #475569; margin: 0 0 16px 0; }
  table { width: 100%; border-collapse: collapse; font-size: 11.5px; }
  th, td { border: 1px solid #CBD5E1; padding: 6px 8px; text-align: left; }
  th { background: #F1F5F9; font-weight: 700; }
  @page { size: A4 landscape; margin: 10mm; }
</style>
</head>
<body>
  <h1>Yash Honda — Enquiries Directory</h1>
  <p>Tab: ${esc(_activeTab)} &bull; Printed ${rows.take(100).length} of ${rows.length} enquiries</p>
  <table>
    <thead>
      <tr><th>Name</th><th>Mobile</th><th>Type</th><th>Branch</th><th>Model</th><th>Payment</th><th>Date</th><th>Status</th></tr>
    </thead>
    <tbody>$rowsHtml</tbody>
  </table>
  <script>window.addEventListener('load', function(){ setTimeout(function(){ window.print(); }, 250); });</script>
</body>
</html>''';

      printHtmlDocument(htmlDoc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print enquiries: $e')),
        );
      }
    }
  }

  Future<void> _showFilterDialog() async {
    final branches = <String>{'All'};
    final types = <String>{'All'};
    final modes = <String>{'All'};
    for (final e in _enquiries) {
      final b = (e['branch']?['name'] ?? '').toString();
      if (b.isNotEmpty) branches.add(b);
      final t = (e['enquiryType'] ?? '').toString();
      if (t.isNotEmpty) types.add(t);
      final m = (e['purchaseMode'] ?? '').toString();
      if (m.isNotEmpty) modes.add(m);
    }

    String tmpType = types.contains(_filterType) ? _filterType : 'All';
    String tmpMode =
        modes.contains(_filterPurchaseMode) ? _filterPurchaseMode : 'All';
    String tmpBranch =
        branches.contains(_filterBranchName) ? _filterBranchName : 'All';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Filter Enquiries',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tmpBranch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: branches
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => tmpBranch = v ?? 'All'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tmpType,
                  decoration: const InputDecoration(labelText: 'Enquiry Type'),
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => tmpType = v ?? 'All'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tmpMode,
                  decoration: const InputDecoration(labelText: 'Purchase Mode'),
                  items: modes
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => tmpMode = v ?? 'All'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filterBranchName = 'All';
                  _filterType = 'All';
                  _filterPurchaseMode = 'All';
                });
                Navigator.pop(ctx);
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _filterBranchName = tmpBranch;
                  _filterType = tmpType;
                  _filterPurchaseMode = tmpMode;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  String _mapStatusToDisplay(String status) {
    switch (status.toUpperCase()) {
      case 'CUSTOMER_BOUGHT':
      case 'RESOLVED':
        return 'Booked';
      case 'CLOSED':
        return 'Closed';
      case 'OTHER_DEALER':
        return 'Other Dealer';
      case 'ACTIVE':
      default:
        return 'Open';
    }
  }

  String _mapDisplayToBackendStatus(String display) {
    switch (display) {
      case 'Booked':
        return 'CUSTOMER_BOUGHT';
      case 'Closed':
        return 'CLOSED';
      case 'Other Dealer':
        return 'CLOSED';
      case 'Open':
      default:
        return 'ACTIVE';
    }
  }

  Future<void> _updateStatus(String enquiryId, String newDisplayStatus) async {
    final backendStatus = _mapDisplayToBackendStatus(newDisplayStatus);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/enquiries/$enquiryId/status', data: {
        'status': backendStatus,
        'remarks': 'Status updated from leads table to $newDisplayStatus',
      });
      setState(() {
        final idx = _enquiries.indexWhere((e) => e['id'] == enquiryId);
        if (idx != -1) {
          _enquiries[idx]['status'] = backendStatus;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newDisplayStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteEnquiry(String enquiryId, String customerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Enquiry',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete enquiry for $customerName? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/enquiries/$enquiryId');
      setState(() {
        _enquiries.removeWhere((e) => e['id'] == enquiryId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enquiry deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _initiateCall(String enquiryId, String customerName) async {
    try {
      final dio = ref.read(dioProvider);
      final res =
          await dio.post('/telephony/call', data: {'enquiryId': enquiryId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Calling $customerName: ${res.data['message']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call error: $e')),
        );
      }
    }
  }

  void _showScheduleFollowUp(Map<String, dynamic> enquiry) {
    final remarksCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay pickedTime = const TimeOfDay(hour: 11, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Schedule Follow-up: ${enquiry['customer']?['name'] ?? 'Customer'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    size: 20, color: Color(0xFFDC2626)),
                title: Text('Date: ${DateFormatter.formatDate(pickedDate)}'),
                trailing: TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setDlgState(() => pickedDate = d);
                  },
                  child: const Text('Change Date'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time,
                    size: 20, color: Color(0xFFDC2626)),
                title: Text('Time: ${pickedTime.format(context)}'),
                trailing: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: pickedTime,
                    );
                    if (t != null) setDlgState(() => pickedTime = t);
                  },
                  child: const Text('Change Time'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Notes',
                  hintText: 'e.g. Discuss loan approval & delivery date',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final scheduledDateTime = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                try {
                  final dio = ref.read(dioProvider);
                  await dio.post('/follow-ups', data: {
                    'enquiryId': enquiry['id'],
                    'scheduledAt': scheduledDateTime.toIso8601String(),
                    'remarks': remarksCtrl.text.trim().isEmpty
                        ? 'Follow-up call'
                        : remarksCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadEnquiries();
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Follow-up scheduled successfully!')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error scheduling follow-up: $e')),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuotationModal(
      Map<String, dynamic> enquiry, Map<String, dynamic> quote) {
    final quoteNumber = quote['quoteNumber'] ?? 'QUOTE';
    final vehicle = quote['vehicle'] ?? {};
    final vName = vehicle['name'] ?? 'Honda Vehicle';
    final colour = quote['colourName'] ?? '-';
    final customer = enquiry['customer'] ?? {};
    final grandTotal = CurrencyFormatter.format(quote['grandTotal']);
    final items = (quote['items'] as List?) ?? [];
    final accessories = (quote['accessories'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quotation #$quoteNumber',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 17)),
                Text(
                    '${customer['name'] ?? ''} • ${MaskUtil.maskMobile(customer['mobile']?.toString())}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('Colour: $colour',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      Text(grandTotal,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Price Breakdown',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                if (quote['exShowroom'] != null)
                  _buildPriceRow('Ex-Showroom Price',
                      CurrencyFormatter.format(quote['exShowroom'])),
                if (quote['roadTax'] != null)
                  _buildPriceRow('RTO / Road Tax',
                      CurrencyFormatter.format(quote['roadTax'])),
                if (quote['insurance'] != null)
                  _buildPriceRow('Comprehensive Insurance',
                      CurrencyFormatter.format(quote['insurance'])),
                ...items.map((it) => _buildPriceRow(it['label'] ?? 'Charge',
                    CurrencyFormatter.format(it['amount']))),
                if (accessories.isNotEmpty) ...[
                  const Divider(height: 16),
                  const Text('Accessories Included',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...accessories.map((acc) => _buildPriceRow(
                        acc['accessory']?['name'] ?? acc['name'] ?? 'Accessory',
                        CurrencyFormatter.format(acc['amount']),
                      )),
                ],
                const Divider(height: 20),
                _buildPriceRow('Grand Total Quotation', grandTotal,
                    isBold: true, color: const Color(0xFFDC2626)),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              final idOrNum =
                  quoteNumber.isNotEmpty ? quoteNumber : (quote['id'] ?? '');
              if (idOrNum.toString().isNotEmpty) {
                final uri = Uri.parse(
                    '${ApiConstants.baseUrl}/quotations/$idOrNum/print');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.print_outlined, size: 16),
            label: const Text('Print Quotation'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final mobile = (customer['mobile'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'[^0-9]'), '');
              final text = Uri.encodeComponent(
                'Namaste ${customer['name'] ?? ''}, here is your quotation for $vName ($colour):\n'
                'Quote No: $quoteNumber\nGrand Total: $grandTotal\nYash Honda Pune.',
              );
              await launchUrl(Uri.parse('https://wa.me/91$mobile?text=$text'),
                  mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.chat_outlined,
                size: 16, color: Color(0xFF16A34A)),
            label: const Text('WhatsApp',
                style: TextStyle(color: Color(0xFF16A34A))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
                  color: const Color(0xFF475569))),
          Text(amount,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  void _showEnquiryDetails(Map<String, dynamic> enquiry) {
    final customer = enquiry['customer'] ?? {};
    final quote = (enquiry['quotations'] as List?)?.firstOrNull ?? {};
    final vehicle = quote['vehicle'] ?? {};
    final status = (enquiry['status'] ?? 'ACTIVE').toString();
    final followUps = (enquiry['followUps'] as List?) ?? [];
    final quoteNumber = quote['quoteNumber'] ?? 'N/A';
    final enqId = enquiry['id']?.toString() ?? '';

    bool dialogMobileRevealed = _revealedMobiles.contains(enqId);
    bool dialogEmailRevealed = _revealedEmails.contains(enqId);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final rawMobile = customer['mobile']?.toString() ?? '-';
          final rawEmail = customer['email']?.toString() ?? '-';
          final hasMobile = rawMobile != '-' && rawMobile.isNotEmpty;
          final hasEmail = rawEmail != '-' && rawEmail.isNotEmpty;
          final mobileDisplay = (dialogMobileRevealed || !hasMobile)
              ? rawMobile
              : MaskUtil.maskMobile(rawMobile);
          final emailDisplay = (dialogEmailRevealed || !hasEmail)
              ? rawEmail
              : MaskUtil.maskEmail(rawEmail);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(24),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer['name'] ?? 'Enquiry Details',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${enquiry['branch']?['name'] ?? 'Yash Honda'} • ${DateFormatter.formatDate(enquiry['createdAt'])}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                _buildStatusBadge(_mapStatusToDisplay(status)),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 20),

                    // Customer info card with tap-to-reveal sensitive data
                    _buildSectionHeader(
                        'Customer Information', Icons.person_outline),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          // Mobile with click to reveal
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mobile',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () {
                                    if (hasMobile) {
                                      setDialogState(() =>
                                          dialogMobileRevealed =
                                              !dialogMobileRevealed);
                                      setState(() {
                                        if (dialogMobileRevealed) {
                                          _revealedMobiles.add(enqId);
                                        } else {
                                          _revealedMobiles.remove(enqId);
                                        }
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          mobileDisplay,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: dialogMobileRevealed
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: dialogMobileRevealed
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF475569),
                                            letterSpacing:
                                                dialogMobileRevealed ? 0 : 0.6,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (hasMobile) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          dialogMobileRevealed
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 13,
                                          color: dialogMobileRevealed
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Email with click to reveal
                          SizedBox(
                            width: 155,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Email',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () {
                                    if (hasEmail) {
                                      setDialogState(() => dialogEmailRevealed =
                                          !dialogEmailRevealed);
                                      setState(() {
                                        if (dialogEmailRevealed) {
                                          _revealedEmails.add(enqId);
                                        } else {
                                          _revealedEmails.remove(enqId);
                                        }
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          emailDisplay,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: dialogEmailRevealed
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: dialogEmailRevealed
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (hasEmail) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          dialogEmailRevealed
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 13,
                                          color: dialogEmailRevealed
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Area',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  customer['area']?['name'] ?? '-',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Address',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  customer['address'] ?? '-',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle & Quote
                    _buildSectionHeader(
                        'Vehicle & Quotation', Icons.two_wheeler_outlined),
                    const SizedBox(height: 8),
                    _buildInfoGrid([
                      {'label': 'Model', 'val': vehicle['name'] ?? '-'},
                      {'label': 'Colour', 'val': quote['colourName'] ?? '-'},
                      {'label': 'Official Quote No', 'val': quoteNumber},
                      {
                        'label': 'Grand Total',
                        'val': CurrencyFormatter.format(quote['grandTotal'])
                      },
                    ]),
                    const SizedBox(height: 16),

                    // Purchase & Finance
                    _buildSectionHeader('Purchase & Finance Details',
                        Icons.credit_card_outlined),
                    const SizedBox(height: 8),
                    _buildInfoGrid([
                      {
                        'label': 'Purchase Mode',
                        'val': enquiry['purchaseMode'] ?? '-'
                      },
                      {
                        'label': 'Financier',
                        'val': enquiry['financier']?['name'] ?? '-'
                      },
                      {
                        'label': 'Buying Timeline',
                        'val': enquiry['buyingWhen'] ?? '-'
                      },
                      {'label': 'Exchange', 'val': enquiry['exchange'] ?? 'No'},
                    ]),
                    const SizedBox(height: 16),

                    // Sales & Attribution
                    _buildSectionHeader('Attribution & Sales Rep',
                        Icons.assignment_ind_outlined),
                    const SizedBox(height: 8),
                    _buildInfoGrid([
                      {
                        'label': 'Sales Executive',
                        'val': enquiry['assignedTo']?['name'] ??
                            enquiry['createdBy']?['name'] ??
                            '-'
                      },
                      {
                        'label': 'Lead Source',
                        'val': enquiry['leadSource']?['name'] ??
                            enquiry['enquiryType'] ??
                            '-'
                      },
                      {
                        'label': 'Enquiry Type',
                        'val': enquiry['enquiryType'] ?? '-'
                      },
                      {'label': 'Consent', 'val': 'Yes'},
                    ]),

                    if (enquiry['remarks'] != null &&
                        enquiry['remarks'].toString().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Remarks', Icons.notes_outlined),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(enquiry['remarks'].toString(),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF334155))),
                      ),
                    ],

                    const SizedBox(height: 16),
                    _buildSectionHeader('Follow-ups (${followUps.length})',
                        Icons.access_time_outlined),
                    const SizedBox(height: 6),
                    if (followUps.isEmpty)
                      const Text('No follow-up logged yet.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic))
                    else
                      ...followUps.take(3).map((f) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_note,
                                    size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                    DateFormatter.formatDateTime(
                                        f['scheduledAt']),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(
                                        f['remarks'] ?? 'Scheduled call',
                                        style: const TextStyle(fontSize: 11))),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showScheduleFollowUp(enquiry);
                },
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Add Follow-up'),
              ),
              if (quote['id'] != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showQuotationModal(enquiry, quote);
                  },
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('View Quotation'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFFDC2626)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildInfoGrid(List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: items.map((it) {
          return SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it['label']!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(it['val']!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    Color dot;

    switch (status) {
      case 'Booked':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        dot = const Color(0xFF059669);
        break;
      case 'Closed':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        dot = const Color(0xFFDC2626);
        break;
      case 'Other Dealer':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        dot = const Color(0xFF64748B);
        break;
      case 'Open':
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        dot = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(Map<String, dynamic> enquiry) {
    final curStatus = _mapStatusToDisplay(enquiry['status'] ?? 'ACTIVE');

    return PopupMenuButton<String>(
      tooltip: 'Change Status',
      onSelected: (val) => _updateStatus(enquiry['id'], val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: curStatus == 'Booked'
              ? const Color(0xFFECFDF5)
              : (curStatus == 'Closed'
                  ? const Color(0xFFFEF2F2)
                  : (curStatus == 'Other Dealer'
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFEFF6FF))),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: curStatus == 'Booked'
                ? const Color(0xFFA7F3D0)
                : (curStatus == 'Closed'
                    ? const Color(0xFFFECACA)
                    : (curStatus == 'Other Dealer'
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFBFDBFE))),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: curStatus == 'Booked'
                    ? const Color(0xFF059669)
                    : (curStatus == 'Closed'
                        ? const Color(0xFFDC2626)
                        : (curStatus == 'Other Dealer'
                            ? const Color(0xFF64748B)
                            : const Color(0xFF2563EB))),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              curStatus,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: curStatus == 'Booked'
                    ? const Color(0xFF059669)
                    : (curStatus == 'Closed'
                        ? const Color(0xFFDC2626)
                        : (curStatus == 'Other Dealer'
                            ? const Color(0xFF64748B)
                            : const Color(0xFF2563EB))),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: curStatus == 'Booked'
                  ? const Color(0xFF059669)
                  : (curStatus == 'Closed'
                      ? const Color(0xFFDC2626)
                      : (curStatus == 'Other Dealer'
                          ? const Color(0xFF64748B)
                          : const Color(0xFF2563EB))),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _buildPopupItem('Open', const Color(0xFF2563EB)),
        _buildPopupItem('Booked', const Color(0xFF059669)),
        _buildPopupItem('Closed', const Color(0xFFDC2626)),
        _buildPopupItem('Other Dealer', const Color(0xFF64748B)),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String label, Color color) {
    return PopupMenuItem<String>(
      value: label,
      height: 32,
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) {
        _loadEnquiries();
      }
    });

    final filtered = _filteredEnquiries;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls: Tabs on Left + Search & Action Icons on Right
            Row(
              children: [
                // Filter Tabs (All, Open, Booked, Closed, Other Dealer)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: _tabs.map((tab) {
                      final isSelected =
                          _activeTab == tab && !_filterFollowUpsDue;
                      String tabTooltip = 'View all enquiries';
                      if (tab == 'Open')
                        tabTooltip =
                            'Active leads currently in progress or quotation stage';
                      if (tab == 'Booked')
                        tabTooltip =
                            'Confirmed bookings with vehicle token advances';
                      if (tab == 'Closed')
                        tabTooltip = 'Discontinued or lost enquiry leads';
                      if (tab == 'Other Dealer')
                        tabTooltip =
                            'Leads who purchased from rival dealerships';

                      return Tooltip(
                        message: tabTooltip,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _activeTab = tab;
                              _filterFollowUpsDue = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Spacer(),

                // Follow-ups due pill
                Tooltip(
                  message:
                      'Filter to view only customer leads with follow-up calls due today or pending',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _filterFollowUpsDue = !_filterFollowUpsDue;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filterFollowUpsDue
                            ? const Color(0xFFD97706)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                            color: _filterFollowUpsDue
                                ? Colors.white
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_followUpsDueCount follow-ups due',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _filterFollowUpsDue
                                  ? Colors.white
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Search box (clean single-layer Material input)
                Tooltip(
                  message:
                      'Quick search enquiries by customer name, 10-digit mobile, or quotation number',
                  child: SizedBox(
                    width: 250,
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Search name, mobile or quote...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 10, right: 6),
                          child: Icon(Icons.search,
                              size: 16, color: Color(0xFF64748B)),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    size: 15, color: Color(0xFF94A3B8)),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFDC2626), width: 1.4),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter icon button
                _buildSquareIconButton(Icons.tune, _showFilterDialog,
                    tooltip:
                        'Filter enquiries by branch, type, or purchase mode'),
                const SizedBox(width: 6),

                // Export icon button
                _buildSquareIconButton(Icons.file_download_outlined, _exportCsv,
                    tooltip:
                        'Export filtered customer enquiries to CSV / Excel spreadsheet'),
                const SizedBox(width: 6),

                // Print icon button
                _buildSquareIconButton(Icons.print_outlined, _printDirectory,
                    tooltip: 'Download printable PDF directory summary report'),
                const SizedBox(width: 6),

                // Refresh / View icon button
                _buildSquareIconButton(
                    Icons.refresh, () => _loadEnquiries(showFeedback: true),
                    tooltip: 'Reload latest enquiries from database'),
              ],
            ),
            const SizedBox(height: 16),

            // Full Data Table matching prototype screenshots
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFDC2626)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined,
                                  size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              const Text('No enquiries found in this view',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569))),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white),
                                onPressed: () =>
                                    context.go('/enquiries/vehicle-picker'),
                                child: const Text('+ New Enquiry'),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x04000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Scrollbar(
                              controller: _verticalScrollCtrl,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              thickness: 9,
                              radius: const Radius.circular(6),
                              child: SingleChildScrollView(
                                controller: _verticalScrollCtrl,
                                scrollDirection: Axis.vertical,
                                padding: const EdgeInsets.only(right: 12),
                                child: Scrollbar(
                                  controller: _horizontalScrollCtrl,
                                  thumbVisibility: true,
                                  interactive: true,
                                  thickness: 7,
                                  radius: const Radius.circular(6),
                                  notificationPredicate: (n) => n.depth == 0,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollCtrl,
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: DataTable(
                                  showCheckboxColumn: false,
                                  columnSpacing: 18,
                                  headingRowHeight: 40,
                                  dataRowMinHeight: 44,
                                  dataRowMaxHeight: 48,
                                  headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8FAFC)),
                                  columns: [
                                    DataColumn(
                                      label: Checkbox(
                                        value: _selectedIds.length ==
                                                filtered.length &&
                                            filtered.isNotEmpty,
                                        activeColor: const Color(0xFFDC2626),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedIds.addAll(filtered.map(
                                                  (e) => e['id'].toString()));
                                            } else {
                                              _selectedIds.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const DataColumn(
                                        label: Text('No.', style: _headerStyle),
                                        tooltip:
                                            'Lead index & quotation revision number'),
                                    const DataColumn(
                                        label:
                                            Text('Name', style: _headerStyle),
                                        tooltip:
                                            'Customer full name (Click to open enquiry card)'),
                                    DataColumn(
                                      label: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (_revealedMobiles.length ==
                                                    filtered.length &&
                                                filtered.isNotEmpty) {
                                              _revealedMobiles.clear();
                                            } else {
                                              _revealedMobiles.addAll(
                                                  filtered.map((e) =>
                                                      e['id'].toString()));
                                            }
                                          });
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Mobile',
                                                style: _headerStyle),
                                            const SizedBox(width: 4),
                                            Icon(
                                              (_revealedMobiles.length ==
                                                          filtered.length &&
                                                      filtered.isNotEmpty)
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              size: 13,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ],
                                        ),
                                      ),
                                      tooltip:
                                          'Customer mobile contact number (Masked for privacy • Click to toggle reveal/hide all)',
                                    ),
                                    DataColumn(
                                      label: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (_revealedEmails.length ==
                                                    filtered.length &&
                                                filtered.isNotEmpty) {
                                              _revealedEmails.clear();
                                            } else {
                                              _revealedEmails.addAll(
                                                  filtered.map((e) =>
                                                      e['id'].toString()));
                                            }
                                          });
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Email',
                                                style: _headerStyle),
                                            const SizedBox(width: 4),
                                            Icon(
                                              (_revealedEmails.length ==
                                                          filtered.length &&
                                                      filtered.isNotEmpty)
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              size: 13,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ],
                                        ),
                                      ),
                                      tooltip:
                                          'Customer email address (Masked for privacy • Click to toggle reveal/hide all)',
                                    ),
                                    const DataColumn(
                                        label:
                                            Text('Type', style: _headerStyle),
                                        tooltip:
                                            'Customer enquiry channel: Walk-in or Telephonic inquiry'),
                                    const DataColumn(
                                        label:
                                            Text('Source', style: _headerStyle),
                                        tooltip:
                                            'Marketing acquisition channel (Walk-in, BikeWale, Digital Ads, etc.)'),
                                    const DataColumn(
                                        label:
                                            Text('Branch', style: _headerStyle),
                                        tooltip:
                                            'Dealership showroom branch where this enquiry was generated'),
                                    const DataColumn(
                                        label:
                                            Text('Area', style: _headerStyle),
                                        tooltip:
                                            'Customer residential/work locality in Pune'),
                                    const DataColumn(
                                        label: Text('Model(s)',
                                            style: _headerStyle),
                                        tooltip:
                                            'Interested Honda motorcycle or scooter model'),
                                    const DataColumn(
                                        label:
                                            Text('Mode', style: _headerStyle),
                                        tooltip:
                                            'Preferred payment mode (Cash, Bank Finance, etc.)'),
                                    const DataColumn(
                                        label: Text('Financier',
                                            style: _headerStyle),
                                        tooltip:
                                            'Financing bank or NBFC provider'),
                                    const DataColumn(
                                        label:
                                            Text('Exch', style: _headerStyle),
                                        tooltip:
                                            'Pre-owned two-wheeler exchange evaluation'),
                                    const DataColumn(
                                        label: Text('Old vehicle',
                                            style: _headerStyle),
                                        tooltip:
                                            'Make & model of customer trade-in vehicle'),
                                    const DataColumn(
                                        label: Text('Kms', style: _headerStyle),
                                        tooltip:
                                            'Odometer mileage on exchange vehicle'),
                                    const DataColumn(
                                        label:
                                            Text('Owner', style: _headerStyle),
                                        tooltip:
                                            'Exchange vehicle RC ownership transfer tier'),
                                    const DataColumn(
                                        label: Text('Exch value',
                                            style: _headerStyle),
                                        tooltip:
                                            'Evaluated trade-in valuation in Rupees'),
                                    const DataColumn(
                                        label: Text('Consent',
                                            style: _headerStyle),
                                        tooltip:
                                            'Customer DPDP privacy & contact consent'),
                                    const DataColumn(
                                        label: Text('Sales Exec',
                                            style: _headerStyle),
                                        tooltip:
                                            'Showroom sales representative handling this customer'),
                                    const DataColumn(
                                        label:
                                            Text('Buying', style: _headerStyle),
                                        tooltip:
                                            'Customer anticipated purchase timeline'),
                                    const DataColumn(
                                        label: Text('Enq. Date',
                                            style: _headerStyle),
                                        tooltip:
                                            'Initial enquiry registration timestamp'),
                                    const DataColumn(
                                        label:
                                            Text('Status', style: _headerStyle),
                                        tooltip:
                                            'Lead stage (Click to transition status)'),
                                    const DataColumn(
                                        label: Text('Remarks',
                                            style: _headerStyle),
                                        tooltip:
                                            'Consultation notes & follow-up comments'),
                                    const DataColumn(
                                        label: Text('Actions',
                                            style: _headerStyle),
                                        tooltip:
                                            'Quotation, telephony call, schedule callback & delete'),
                                  ],
                                  rows: filtered.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final e = entry.value;
                                    final id = e['id'].toString();
                                    final isSelected =
                                        _selectedIds.contains(id);

                                    final customer = e['customer'] ?? {};
                                    final quote = (e['quotations'] as List?)
                                            ?.firstOrNull ??
                                        {};
                                    final vehicle = quote['vehicle'] ?? {};
                                    final statusDisplay = _mapStatusToDisplay(
                                        e['status'] ?? 'ACTIVE');

                                    // Row tinting matching prototype
                                    Color rowBg = Colors.white;
                                    if (statusDisplay == 'Booked') {
                                      rowBg = const Color(
                                          0xFFF0FDF4); // light green
                                    } else if (statusDisplay == 'Closed') {
                                      rowBg =
                                          const Color(0xFFFEF2F2); // light red
                                    }

                                    final isExchange = (e['exchange']
                                            ?.toString()
                                            .toLowerCase()
                                            .contains('yes') ??
                                        false);
                                    final revCount =
                                        (e['quotations'] as List?)?.length ?? 1;

                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith<
                                          Color>((states) {
                                        if (states
                                            .contains(WidgetState.hovered)) {
                                          return const Color(0xFFF1F5F9);
                                        }
                                        return rowBg;
                                      }),
                                      onSelectChanged: (_) =>
                                          _showEnquiryDetails(e),
                                      cells: [
                                        // Checkbox
                                        DataCell(
                                          Checkbox(
                                            value: isSelected,
                                            activeColor:
                                                const Color(0xFFDC2626),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedIds.add(id);
                                                } else {
                                                  _selectedIds.remove(id);
                                                }
                                              });
                                            },
                                          ),
                                        ),

                                        // No. (e.g. 93/2)
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Lead #${filtered.length - idx} • Quotation Revision $revCount',
                                              child: Text(
                                                  '${filtered.length - idx}/$revCount',
                                                  style: const TextStyle(
                                                      fontSize: 13.5,
                                                      color: Color(0xFF94A3B8))),
                                            ),
                                          ),

                                          // Name
                                          DataCell(
                                            InkWell(
                                              onTap: () => _showEnquiryDetails(e),
                                              child: Text(
                                                customer['name'] ?? '-',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                          ),

                                        // Mobile (Masked by default • Click to reveal)
                                        DataCell(
                                          Builder(
                                            builder: (context) {
                                              final rawMobile =
                                                  customer['mobile']
                                                          ?.toString() ??
                                                      '-';
                                              final hasMobile =
                                                  rawMobile != '-' &&
                                                      rawMobile.isNotEmpty;
                                              final isRevealed =
                                                  _revealedMobiles.contains(id);
                                              final displayMobile =
                                                  (isRevealed || !hasMobile)
                                                      ? rawMobile
                                                      : MaskUtil.maskMobile(
                                                          rawMobile);

                                              return InkWell(
                                                onTap: () {
                                                  if (hasMobile) {
                                                    setState(() {
                                                      if (isRevealed) {
                                                        _revealedMobiles
                                                            .remove(id);
                                                      } else {
                                                        _revealedMobiles
                                                            .add(id);
                                                      }
                                                    });
                                                  }
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Tooltip(
                                                  message: !hasMobile
                                                      ? 'No mobile number recorded'
                                                      : isRevealed
                                                          ? 'Phone: $rawMobile\nClick to mask (protect sensitive data)'
                                                          : 'Phone: $displayMobile\nClick to reveal customer phone number',
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4,
                                                        horizontal: 2),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          displayMobile,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                isRevealed
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .w500,
                                                            color: isRevealed
                                                                ? const Color(
                                                                    0xFF0F172A)
                                                                : const Color(
                                                                    0xFF475569),
                                                            letterSpacing:
                                                                isRevealed
                                                                    ? 0
                                                                    : 0.6,
                                                          ),
                                                        ),
                                                        if (hasMobile) ...[
                                                          const SizedBox(
                                                              width: 5),
                                                          Icon(
                                                            isRevealed
                                                                ? Icons
                                                                    .visibility_outlined
                                                                : Icons
                                                                    .visibility_off_outlined,
                                                            size: 13,
                                                            color: isRevealed
                                                                ? const Color(
                                                                    0xFFDC2626)
                                                                : const Color(
                                                                    0xFF94A3B8),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        // Email (Masked by default • Click to reveal)
                                        DataCell(
                                          Builder(
                                            builder: (context) {
                                              final rawEmail = customer['email']
                                                      ?.toString() ??
                                                  '-';
                                              final hasEmail =
                                                  rawEmail != '-' &&
                                                      rawEmail.isNotEmpty;
                                              final isRevealed =
                                                  _revealedEmails.contains(id);
                                              final displayEmail =
                                                  (isRevealed || !hasEmail)
                                                      ? rawEmail
                                                      : MaskUtil.maskEmail(
                                                          rawEmail);

                                              return InkWell(
                                                onTap: () {
                                                  if (hasEmail) {
                                                    setState(() {
                                                      if (isRevealed) {
                                                        _revealedEmails
                                                            .remove(id);
                                                      } else {
                                                        _revealedEmails.add(id);
                                                      }
                                                    });
                                                  }
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Tooltip(
                                                  message: !hasEmail
                                                      ? 'No email recorded'
                                                      : isRevealed
                                                          ? 'Email: $rawEmail\nClick to mask (protect sensitive data)'
                                                          : 'Email: $displayEmail\nClick to reveal customer email address',
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4,
                                                        horizontal: 2),
                                                    child: SizedBox(
                                                      width: 155,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              displayEmail,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: isRevealed
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .w400,
                                                                color: isRevealed
                                                                    ? const Color(
                                                                        0xFF0F172A)
                                                                    : const Color(
                                                                        0xFF64748B),
                                                                letterSpacing:
                                                                    isRevealed
                                                                        ? 0
                                                                        : 0.3,
                                                              ),
                                                            ),
                                                          ),
                                                          if (hasEmail) ...[
                                                            const SizedBox(
                                                                width: 5),
                                                            Icon(
                                                              isRevealed
                                                                  ? Icons
                                                                      .visibility_outlined
                                                                  : Icons
                                                                      .visibility_off_outlined,
                                                              size: 13,
                                                              color: isRevealed
                                                                  ? const Color(
                                                                      0xFFDC2626)
                                                                  : const Color(
                                                                      0xFF94A3B8),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        // Type
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Inquiry Channel: ${e['enquiryType'] ?? 'Walkin'}',
                                            child: Text(
                                                e['enquiryType'] ?? 'Walkin',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B))),
                                          ),
                                        ),

                                        // Source
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Lead Source: ${e['leadSource']?['name'] ?? e['enquiryType'] ?? 'Walk-in'}',
                                            child: Text(
                                                e['leadSource']?['name'] ??
                                                    e['enquiryType'] ??
                                                    'Walk-in',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B))),
                                          ),
                                        ),

                                        // Branch
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFBFDBFE)),
                                            ),
                                            child: Text(
                                              e['branch']?['name'] ??
                                                  'Showroom',
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1D4ED8)),
                                            ),
                                          ),
                                        ),

                                        // Area
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Locality: ${customer['area']?['name'] ?? 'Hadapsar'}',
                                            child: Text(
                                                customer['area']?['name'] ??
                                                    'Hadapsar',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B))),
                                          ),
                                        ),

                                        // Model(s)
                                        DataCell(
                                          Text(
                                            vehicle['name'] ?? 'Activa 110 Dlx',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF0F172A)),
                                          ),
                                        ),

                                        // Mode
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Payment Mode: ${e['purchaseMode'] ?? 'Cash'}\n${e['financier']?['name'] != null ? 'Financier: ${e['financier']['name']}' : ''}',
                                            child: Text(
                                                e['purchaseMode'] ?? 'Cash',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B))),
                                          ),
                                        ),

                                        // Financier
                                        DataCell(
                                          Tooltip(
                                            message:
                                                'Financier Partner: ${e['financier']?['name'] ?? 'Not financed'}',
                                            child: Text(
                                                e['financier']?['name'] ?? '-',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF475569))),
                                          ),
                                        ),

                                        // Exch (red Yes if true)
                                        DataCell(
                                          Text(
                                            isExchange ? 'Yes' : '-',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isExchange
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                              color: isExchange
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),

                                        // Old vehicle
                                        DataCell(Text(
                                            isExchange
                                                ? (e['oldVehicle'] ?? 'Activa')
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF475569)))),

                                        // Kms
                                        DataCell(Text(
                                            isExchange ? '25000' : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF475569)))),

                                        // Owner
                                        DataCell(Text(
                                            isExchange ? '1st Owner' : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF475569)))),

                                        // Exch value
                                        DataCell(Text(
                                            isExchange ? '25000.00' : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF475569)))),

                                        // Consent (red Yes)
                                        const DataCell(Text('Yes',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFDC2626)))),

                                        // Sales Exec
                                        DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              e['assignedTo']?['name'] ??
                                                  e['createdBy']?['name'] ??
                                                  'Big Wing Sales Exec',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF1E293B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),

                                        // Buying
                                        DataCell(Text(
                                            e['buyingWhen'] ?? 'This week',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF1E293B)))),

                                        // Enq. Date
                                        DataCell(Text(
                                            DateFormatter.formatDate(
                                                e['createdAt']),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF475569)))),

                                        // Status dropdown
                                        DataCell(_buildStatusDropdown(e)),

                                        // Remarks
                                        DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              e['remarks'] ?? '-',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),

                                        // Actions: Quote [$] R1/R2, Call, Follow-up, Delete
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Quotation button [$] R2
                                              Tooltip(
                                                message:
                                                    'View quotation revision R$revCount • Grand Total: ${quote['grandTotal'] != null ? CurrencyFormatter.format(quote['grandTotal']) : 'Pending'}',
                                                child: InkWell(
                                                  onTap: () {
                                                    if (quote['id'] != null) {
                                                      _showQuotationModal(
                                                          e, quote);
                                                    } else {
                                                      _showEnquiryDetails(e);
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFCBD5E1)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .currency_rupee,
                                                            size: 11,
                                                            color: Color(
                                                                0xFF334155)),
                                                        Text(
                                                          'R$revCount',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: Color(
                                                                  0xFF334155)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),

                                              // Phone Call icon
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.phone_outlined,
                                                    size: 15,
                                                    color: Color(0xFF64748B)),
                                                tooltip:
                                                    'Call Customer via Exotel',
                                                splashRadius: 14,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () => _initiateCall(
                                                    id,
                                                    customer['name'] ??
                                                        'Customer'),
                                              ),

                                              // Follow-up history icon
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.history_rounded,
                                                    size: 16,
                                                    color: Color(0xFF64748B)),
                                                tooltip:
                                                    'Schedule / View Follow-ups',
                                                splashRadius: 14,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _showScheduleFollowUp(e),
                                              ),

                                              // Delete icon
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 15,
                                                    color: Color(0xFFEF4444)),
                                                tooltip: 'Delete Enquiry',
                                                splashRadius: 14,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () => _deleteEnquiry(
                                                    id,
                                                    customer['name'] ??
                                                        'Customer'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareIconButton(IconData icon, VoidCallback onTap,
      {String? tooltip}) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: const Color(0xFF475569)),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w700,
  color: Color(0xFF64748B),
);
