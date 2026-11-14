import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/currency_formatter.dart';
import '../../shared/widgets/ai_summary/ai_summary_card.dart';

class DealershipSummaryScreen extends ConsumerStatefulWidget {
  const DealershipSummaryScreen({super.key});

  @override
  ConsumerState<DealershipSummaryScreen> createState() => _DealershipSummaryScreenState();
}

class _DealershipSummaryScreenState extends ConsumerState<DealershipSummaryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRange = 'today';
  bool _isLoading = true;

  Map<String, dynamic>? _executiveData;
  Map<String, dynamic>? _financialData;
  Map<String, dynamic>? _matrixData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final [execRes, finRes, matRes] = await Future.wait([
        dio.get('/analytics/summary/executive', queryParameters: {'range': _selectedRange}),
        dio.get('/analytics/summary/financial', queryParameters: {'range': _selectedRange}),
        dio.get('/analytics/summary/matrix', queryParameters: {'range': _selectedRange == 'today' ? 'mtd' : _selectedRange}),
      ]);

      setState(() {
        _executiveData = execRes.data;
        _financialData = finRes.data;
        _matrixData = matRes.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Dealership Summary: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dealership Summary & Analytics',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Consolidated executive, financial and branch-matrix performance',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'today', label: Text('Today')),
                        ButtonSegment(value: 'mtd', label: Text('MTD')),
                        ButtonSegment(value: '30d', label: Text('Last 30 Days')),
                      ],
                      selected: {_selectedRange},
                      onSelectionChanged: (set) {
                        setState(() => _selectedRange = set.first);
                        _loadSummary();
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadSummary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // AI Briefing
            AiSummaryCard(
              branchCode: 'all',
              range: _selectedRange,
            ),

            // Tab bar for the 3 rigid views
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.assessment_outlined, size: 18), text: 'Executive KPIs'),
                  Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Financial Breakdown'),
                  Tab(icon: Icon(Icons.grid_on_outlined, size: 18), text: 'Branch x Vehicle Matrix'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
              SizedBox(
                height: 600,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExecutiveView(),
                    _buildFinancialView(),
                    _buildMatrixView(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveView() {
    final kpis = _executiveData?['kpis'] ?? {};

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricTile('TOTAL LEADS', kpis['totalLeads']?.toString() ?? '0', Icons.leaderboard_outlined, AppColors.textPrimary),
              const SizedBox(width: 14),
              _buildMetricTile('CONVERSION RATE', '${kpis['conversionRate'] ?? 0}%', Icons.trending_up, AppColors.statusBought),
              const SizedBox(width: 14),
              _buildMetricTile('BOOKINGS / WON', kpis['bookedCount']?.toString() ?? '0', Icons.done_all, const Color(0xFF16A34A)),
              const SizedBox(width: 14),
              _buildMetricTile('CLOSED / LOST', kpis['closedLostCount']?.toString() ?? '0', Icons.cancel_outlined, AppColors.statusClosed),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricTile('FINANCE PURCHASES', '${kpis['financeCount'] ?? 0} (${kpis['financePercentage'] ?? 0}%)', Icons.credit_card, const Color(0xFF2563EB)),
              const SizedBox(width: 14),
              _buildMetricTile('CASH DEALS', kpis['cashCount']?.toString() ?? '0', Icons.payments_outlined, const Color(0xFF0D9488)),
              const SizedBox(width: 14),
              _buildMetricTile('EXCHANGE VEHICLES', kpis['exchangeCount']?.toString() ?? '0', Icons.swap_horiz, const Color(0xFF9333EA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialView() {
    final fin = _financialData?['financials'] ?? {};

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              _buildMetricTile('TOTAL QUOTE VOLUME', CurrencyFormatter.format(fin['totalQuotationValue']), Icons.account_balance, AppColors.primary),
              const SizedBox(width: 14),
              _buildMetricTile('AVERAGE DEAL SIZE', CurrencyFormatter.format(fin['avgDealSize']), Icons.analytics_outlined, const Color(0xFF2563EB)),
              const SizedBox(width: 14),
              _buildMetricTile('TOTAL QUOTATIONS', fin['quotesCount']?.toString() ?? '0', Icons.receipt_long_outlined, AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricTile('EX-SHOWROOM GROSS', CurrencyFormatter.format(fin['totalExShowroomValue']), Icons.store, const Color(0xFF475569)),
              const SizedBox(width: 14),
              _buildMetricTile('RTO ROAD TAX', CurrencyFormatter.format(fin['totalRoadTaxValue']), Icons.receipt_outlined, const Color(0xFF475569)),
              const SizedBox(width: 14),
              _buildMetricTile('INSURANCE PREMIUMS', CurrencyFormatter.format(fin['totalInsuranceValue']), Icons.security_outlined, const Color(0xFF475569)),
              const SizedBox(width: 14),
              _buildMetricTile('ACCESSORIES REVENUE', CurrencyFormatter.format(fin['totalAccessoriesValue']), Icons.extension_outlined, const Color(0xFF0D9488)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixView() {
    final matrix = (_matrixData?['matrix'] as Map<String, dynamic>?) ?? {};

    if (matrix.isEmpty) {
      return const Center(child: Text('No quotation matrix data for this period', style: TextStyle(color: AppColors.textMuted)));
    }

    final branches = matrix.keys.toList();
    final allVehicles = <String>{};
    for (final b in branches) {
      final vMap = matrix[b] as Map<String, dynamic>;
      allVehicles.addAll(vMap.keys);
    }
    final vehicles = allVehicles.toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(AppColors.surfaceMuted),
            columns: [
              const DataColumn(label: Text('BRANCH', style: TextStyle(fontWeight: FontWeight.bold))),
              ...vehicles.map((v) => DataColumn(label: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))),
            ],
            rows: branches.map((b) {
              final vMap = matrix[b] as Map<String, dynamic>;
              return DataRow(
                cells: [
                  DataCell(Text(b, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ...vehicles.map((v) {
                    final data = vMap[v];
                    if (data == null) return const DataCell(Text('-'));
                    return DataCell(
                      Text('${data['count']} (${CurrencyFormatter.format(data['totalValue'])})'),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
