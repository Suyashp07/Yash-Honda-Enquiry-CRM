import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/date_formatter.dart';

class EnquiriesListScreen extends ConsumerStatefulWidget {
  const EnquiriesListScreen({super.key});

  @override
  ConsumerState<EnquiriesListScreen> createState() => _EnquiriesListScreenState();
}

class _EnquiriesListScreenState extends ConsumerState<EnquiriesListScreen> {
  List<dynamic> _enquiries = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  Future<void> _loadEnquiries() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final query = _search.trim().isEmpty ? null : {'search': _search.trim()};
      final res = await dio.get('/enquiries', queryParameters: query);

      setState(() {
        _enquiries = res.data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.statusActive;
      case 'RESOLVED':
        return AppColors.statusResolved;
      case 'CUSTOMER_BOUGHT':
        return AppColors.statusBought;
      case 'CLOSED':
        return AppColors.statusClosed;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _initiateCall(String enquiryId, String customerName) async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/telephony/call', data: {'enquiryId': enquiryId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $customerName: ${res.data['message']}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dealership Enquiries', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Manage customer enquiries, track status & initiate customer callback', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/enquiries/vehicle-picker'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Walk-in / Tele Enquiry'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search customer name or mobile number...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        setState(() => _search = val);
                        _loadEnquiries();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loadEnquiries,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // List / Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _enquiries.isEmpty
                      ? const Center(child: Text('No enquiries found.'))
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _enquiries.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final e = _enquiries[index];
                              final customer = e['customer'] ?? {};
                              final branch = e['branch'] ?? {};
                              final quote = (e['quotations'] as List?)?.firstOrNull;
                              final status = e['status'] ?? 'ACTIVE';
                              final statusColor = _getStatusColor(status);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    // Customer Details
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer['name'] ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text('${customer['mobile'] ?? ''} • ${branch['code'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),

                                    // Vehicle & Type
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(quote?['vehicle']?['name'] ?? 'No vehicle', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text('${e['enquiryType']} • ${e['purchaseMode']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),

                                    // Date
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormatter.formatDateTime(e['createdAt']),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ),

                                    // Status Badge
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.replaceAll('_', ' '),
                                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Actions: Call & Details
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.call, size: 18, color: Color(0xFF16A34A)),
                                          tooltip: 'Call Customer via Exotel',
                                          onPressed: () => _initiateCall(e['id'], customer['name'] ?? 'Customer'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

