import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/mask_util.dart';
import '../../shared/widgets/app_components.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _reportData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final Set<String> _revealedMobiles = {};

  final List<String> _reportTypes = ['pending', 'lost', 'finance', 'exchange'];
  static const Map<String, String> _reportDescriptions = {
    'pending': 'Active enquiries awaiting follow-up or booking decision.',
    'lost': 'Closed or lost enquiries with recorded outcome reasons.',
    'finance': 'Enquiries opting for vehicle finance and designated banking partners.',
    'exchange': 'Customers evaluating old two-wheelers for exchange.',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
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

  String get _currentType => _reportTypes[_tabController.index];

  Future<void> _loadReport(String type) async {
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
      final res = await dio.get('/reports/$type', queryParameters: query);
      if (!mounted) return;
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _reportData = res.data is List ? res.data as List : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ref.read(dataFreshnessErrorProvider.notifier).state = true;
      String message = 'We could not load this report. Check your connection and try again.';
      if (e is DioException && e.response?.statusCode == 403) {
        message = 'You do not have permission to view this report.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  List<dynamic> get _filteredData {
    if (_searchQuery.trim().isEmpty) return _reportData;
    final q = _searchQuery.trim().toLowerCase();
    return _reportData.where((item) {
      final customer = item['customer'] ?? {};
      final name = (customer['name'] ?? '').toString().toLowerCase();
      final mobile = (customer['mobile'] ?? '').toString().toLowerCase();
      final branch = (item['branch']?['name'] ?? '').toString().toLowerCase();
      return name.contains(q) || mobile.contains(q) || branch.contains(q);
    }).toList();
  }

  Future<void> _exportCsv(List<dynamic> rows) async {
    final buffer = StringBuffer();
    buffer.writeln('Customer,Mobile,Branch,Type,Purchase Mode,Created Date');
    for (final item in rows) {
      final customer = item['customer'] ?? {};
      final branch = item['branch'] ?? {};
      final name = (customer['name'] ?? '').toString().replaceAll(',', ' ');
      final mobile = MaskUtil.maskMobile(customer['mobile']?.toString() ?? '');
      final branchCode = (branch['code'] ?? '').toString();
      final type = (item['enquiryType'] ?? '').toString();
      final mode = (item['purchaseMode'] ?? '').toString();
      final date = DateFormatter.formatDate(item['createdAt']);
      buffer.writeln('$name,$mobile,$branchCode,$type,$mode,$date');
    }
    await downloadTextFile(buffer.toString(), 'report_$_currentType.csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Exported ${rows.length} rows to CSV.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) _loadReport(_currentType);
    });

    final gutter = Breakpoints.gutterFor(context);
    final filtered = _filteredData;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Reports',
              subtitle: _reportDescriptions[_currentType],
              actions: [
                AppButton(
                  label: 'Export CSV (${filtered.length})',
                  icon: AppIcons.download,
                  variant: AppButtonVariant.secondary,
                  onPressed: filtered.isEmpty ? null : () => _exportCsv(filtered),
                  disabledReason: 'No rows available to export',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            TabBar(
              controller: _tabController,
              isScrollable: Breakpoints.isPhone(context),
              tabs: const [
                Tab(text: 'Pending Leads'),
                Tab(text: 'Lost / Closed'),
                Tab(text: 'Finance Leads'),
                Tab(text: 'Exchange Leads'),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            FilterBar(
              resultCount: _isLoading ? null : filtered.length,
              resultLabel: 'records',
              hasActiveFilters: _searchQuery.isNotEmpty,
              onClearAll: () => setState(() => _searchQuery = ''),
              filters: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search customer, mobile, branch...',
                      prefixIcon: Icon(AppIcons.search, size: 20),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Expanded(
              child: _isLoading
                  ? const LoadingState(rows: 5)
                  : _errorMessage != null
                      ? ErrorState(
                          message: _errorMessage!,
                          onRetry: () => _loadReport(_currentType),
                        )
                      : filtered.isEmpty
                          ? EmptyState(
                              icon: AppIcons.reports,
                              title: 'No matching records',
                              message: _searchQuery.isNotEmpty
                                  ? 'Try clearing your search filter.'
                                  : 'No records found in this report for the selected branch.',
                              actionLabel: _searchQuery.isNotEmpty ? 'Clear search' : null,
                              onAction: _searchQuery.isNotEmpty
                                  ? () => setState(() => _searchQuery = '')
                                  : null,
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s8),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final id = item['id']?.toString() ?? '$index';
                                final customer = item['customer'] ?? {};
                                final branch = item['branch'] ?? {};
                                final rawMobile = customer['mobile']?.toString() ?? '';
                                final isRev = _revealedMobiles.contains(id);
                                final displayMobile =
                                    isRev ? rawMobile : MaskUtil.maskMobile(rawMobile);

                                return AppCard(
                                  child: Wrap(
                                    spacing: AppSpacing.s16,
                                    runSpacing: AppSpacing.s8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: 240,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer['name']?.toString() ?? 'Customer',
                                              style: AppTypography.bodyStrong,
                                            ),
                                            const SizedBox(height: 2),
                                            InkWell(
                                              onTap: () => setState(() {
                                                if (isRev) {
                                                  _revealedMobiles.remove(id);
                                                } else {
                                                  _revealedMobiles.add(id);
                                                }
                                              }),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '$displayMobile • ${branch['code'] ?? ''}',
                                                    style: AppTypography.caption,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    isRev ? AppIcons.hide : AppIcons.view,
                                                    size: 14,
                                                    color: AppColors.secondary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        item['enquiryType']?.toString() ?? '-',
                                        style: AppTypography.body,
                                      ),
                                      Text(
                                        item['purchaseMode']?.toString() ?? '-',
                                        style: AppTypography.bodyStrong,
                                      ),
                                      Text(
                                        DateFormatter.formatDate(item['createdAt']),
                                        style: AppTypography.caption,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
