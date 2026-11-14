import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/date_formatter.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _reportData = [];
  bool _isLoading = true;

  final List<String> _reportTypes = ['pending', 'lost', 'finance', 'exchange'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadReport(_reportTypes[_tabController.index]);
      }
    });
    _loadReport('pending');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport(String type) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/reports/$type');
      setState(() {
        _reportData = res.data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
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
            const Text('Dealership Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Executive funnel and operational lead audit reports', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Pending Leads'),
                Tab(text: 'Lost / Closed'),
                Tab(text: 'Finance Leads'),
                Tab(text: 'Exchange Leads'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reportData.isEmpty
                      ? const Center(child: Text('No records found for this report.'))
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _reportData.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _reportData[index];
                              final customer = item['customer'] ?? {};
                              final branch = item['branch'] ?? {};

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer['name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('${customer['mobile'] ?? ''} • ${branch['code'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(item['enquiryType'] ?? '', style: const TextStyle(fontSize: 13)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(item['purchaseMode'] ?? '', style: const TextStyle(fontSize: 13)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(DateFormatter.formatDate(item['createdAt']), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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

