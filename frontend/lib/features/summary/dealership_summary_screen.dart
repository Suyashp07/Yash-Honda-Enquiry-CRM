import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/currency_formatter.dart';
import '../auth/auth_notifier.dart';

class DealershipSummaryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const DealershipSummaryScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<DealershipSummaryScreen> createState() => _DealershipSummaryScreenState();
}

class _DealershipSummaryScreenState extends ConsumerState<DealershipSummaryScreen> {
  String _activeView = 'matrix'; // 'matrix', 'summary2', 'financial'
  String _selectedPeriod = 'today'; // 'today', 'week', 'mtd', 'ytd'
  DateTime _selectedDate = DateTime.now();
  String _selectedBranch = 'all';
  bool _swapRowsCols = false;

  bool _isLoading = true;
  Map<String, dynamic>? _summaryData;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final res = await dio.get('/analytics/summary/dealership', queryParameters: {
        'date': dateStr,
        'period': _selectedPeriod,
        'branchId': _selectedBranch,
      });

      if (!mounted) return;
      setState(() {
        _summaryData = res.data?['data'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Failed to load Dealership Summary';
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          ref.read(authStateProvider.notifier).logout();
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            context.go('/login');
          }
          return;
        } else if (e.response?.data?['message'] != null) {
          msg = e.response!.data['message'].toString();
        } else {
          msg = e.message ?? msg;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: const Color(0xFFEF4444),
            onPressed: _loadSummary,
          ),
        ),
      );
    }
  }

  void _stepDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Controls Bar (Views, Swap, Periods, Date Stepper, Branch)
        _buildTopControls(),
        const SizedBox(height: 16),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(60),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Computing Real Dealership Analytics...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else if (_summaryData == null)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('No summary data available for this range.')),
          )
        else ...[
          if (_activeView == 'matrix') _buildMatrixView(),
          if (_activeView == 'summary2') _buildSummary2View(),
          if (_activeView == 'financial') _buildFinancialView(),
        ],
        const SizedBox(height: 40),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: content,
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // View Switcher: Matrix View | Summary 2 | Financial
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewTab('matrix', 'Matrix View', Icons.table_chart_outlined, tooltip: 'Performance matrix comparing branches, walk-ins, bookings & conversion rates'),
                _buildViewTab('summary2', 'Summary 2', Icons.grid_view_outlined, tooltip: 'Executive KPI cards and model contribution analytics'),
                _buildViewTab('financial', 'Financial', Icons.currency_rupee, tooltip: 'Revenue statistics, booking advances and payment mode share'),
              ],
            ),
          ),

          // In Matrix View: Swap Rows / Cols Button
          if (_activeView == 'matrix')
            Tooltip(
              message: 'Transpose matrix dimensions (swap rows and columns between branches and metrics)',
              child: InkWell(
                onTap: () => setState(() => _swapRowsCols = !_swapRowsCols),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _swapRowsCols ? const Color(0xFFFEE2E2) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _swapRowsCols ? AppColors.primary : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 16,
                        color: _swapRowsCols ? AppColors.primary : const Color(0xFF334155),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Swap Rows / Cols',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _swapRowsCols ? AppColors.primary : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Period Switcher: Today | Week | MTD | YTD
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                {'id': 'today', 'tip': 'Analytics for today'},
                {'id': 'week', 'tip': 'Analytics for this week'},
                {'id': 'mtd', 'tip': 'Month-to-Date cumulative analytics'},
                {'id': 'ytd', 'tip': 'Year-to-Date annual metrics'},
              ].map((item) {
                final p = item['id']!;
                final isSel = _selectedPeriod == p;
                return Tooltip(
                  message: item['tip']!,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedPeriod = p);
                      _loadSummary();
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        p.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Date Stepper: Jump Today | < | Date | >
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Reset filter to today\'s date',
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedDate = DateTime.now());
                    _loadSummary();
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Jump Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'View previous period analytics',
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () => _stepDate(-1),
                ),
              ),
              Tooltip(
                message: 'Selected date: ${DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)}',
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              Tooltip(
                message: 'View next period analytics',
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: () => _stepDate(1),
                ),
              ),
            ],
          ),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Reload latest dealership metrics from database',
            onPressed: _loadSummary,
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String id, String label, IconData icon, {String? tooltip}) {
    final isSel = _activeView == id;
    final tab = InkWell(
      onTap: () => setState(() => _activeView = id),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSel ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSel ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: tab);
    }
    return tab;
  }

  // ==========================================
  // 1. MATRIX VIEW (Full Dealership Table)
  // ==========================================
  Widget _buildMatrixView() {
    final branches = (_summaryData?['branches'] as List?) ?? [];
    final asOnDate = _summaryData?['asOnDate'] ?? {};
    final totalLeads = asOnDate['totalLeads'] ?? {};
    final totalBk = asOnDate['totalBk'] ?? {};
    final conversion = asOnDate['conversion'] ?? {};

    final modeBreakup = (_summaryData?['modeBreakup'] as List?) ?? [];
    final sourceBreakup = (_summaryData?['sourceBreakup'] as List?) ?? [];
    final modelWiseLeads = (_summaryData?['modelWiseLeads'] as List?) ?? [];
    final modelWiseBk = (_summaryData?['modelWiseBk'] as List?) ?? [];
    final salesExWiseBk = (_summaryData?['salesExWiseBk'] as List?) ?? [];

    final mtdModelConv = (_summaryData?['mtdModelConv'] as List?) ?? [];
    final mtdSalesExConv = (_summaryData?['mtdSalesExConv'] as List?) ?? [];
    final mtdSourceConv = (_summaryData?['mtdSourceConv'] as List?) ?? [];
    final mtdModeConv = (_summaryData?['mtdModeConv'] as List?) ?? [];

    final date = _summaryData?['date'] ?? '';
    final monthStart = _summaryData?['monthStart'] ?? '';

    // Branch columns list
    final branchIds = [...branches.map((b) => b['id'].toString()), 'all'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header Row: Metric / Breakdown + 6 Branches + Consolidated
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'METRIC / BREAKDOWN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.5),
                    ),
                  ),
                  ...branches.map((b) {
                    final index = branches.indexOf(b) + 1;
                    return Container(
                      width: 175,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('LOCATION $index', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          Text(b['name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    );
                  }),
                  // Consolidated Column
                  Container(
                    width: 185,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      border: Border(left: BorderSide(color: Color(0xFFFDE68A), width: 2)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('CONSOLIDATED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                        Text('All 6 Dealerships', style: TextStyle(fontSize: 10, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section 1: AS ON DATE
            _buildSectionHeader('AS ON DATE ($date)'),
            _buildMatrixDataRow('TOTAL LEADS', branchIds, (id) => (totalLeads[id] ?? 0).toString(), isBold: true, highlightColor: const Color(0xFF2563EB)),
            _buildMatrixDataRow('TOTAL BK (BOOKED)', branchIds, (id) => (totalBk[id] ?? 0).toString(), isBold: true, highlightColor: const Color(0xFF16A34A)),
            _buildMatrixDataRow('CONVERSION', branchIds, (id) => (conversion[id] ?? '0.00%').toString(), isBold: true, highlightColor: AppColors.primary),

            // Section 2: MODE BREAK UP
            _buildSectionHeader('MODE BREAK UP'),
            ...modeBreakup.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 3: SOURCE
            _buildSectionHeader('SOURCE BREAKUP'),
            ...sourceBreakup.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 4: MODEL WISE LEADS
            _buildSectionHeader('MODEL WISE LEADS'),
            ...modelWiseLeads.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 5: MODEL WISE BK
            _buildSectionHeader('MODEL WISE BK'),
            ...modelWiseBk.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? 0).toString(), highlightColor: const Color(0xFF16A34A))),

            // Section 6: SALES EX WISE BK
            _buildSectionHeader('SALES EX WISE BK'),
            ...salesExWiseBk.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 7: MTD LEADS TO CONVERSION ("X LEADS / Y BK / Z% CONV")
            _buildSectionHeader('MTD LEADS TO CONVERSION ($monthStart to $date)'),
            ...mtdModelConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 8: MTD SALES EX WISE CONV
            _buildSectionHeader('MTD SALES EX WISE CONV'),
            ...mtdSalesExConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 9: SOURCE WISE CONVERSION (MTD)
            _buildSectionHeader('SOURCE WISE CONVERSION (MTD)'),
            ...mtdSourceConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 10: MODE WISE BREAKUP (MTD)
            _buildSectionHeader('MODE WISE BREAKUP (MTD)'),
            ...mtdModeConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: 1475,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFCBD5E1)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMatrixDataRow(
    String label,
    List<String> branchIds,
    String Function(String) valueGetter, {
    bool isBold = false,
    Color? highlightColor,
    bool isConvFormat = false,
  }) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          ...branchIds.map((bId) {
            final val = valueGetter(bId);
            final isAll = bId == 'all';

            return Container(
              width: isAll ? 185 : 175,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isAll ? const Color(0xFFFFFBEB) : Colors.white,
                border: const Border(left: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              alignment: Alignment.center,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: isConvFormat ? 10 : (isBold ? 13 : 11.5),
                  fontWeight: isBold || isAll ? FontWeight.w800 : FontWeight.w600,
                  color: isAll
                      ? (highlightColor ?? const Color(0xFFB45309))
                      : (highlightColor ?? const Color(0xFF1E293B)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // 2. SUMMARY 2 (Executive View & Funnel Grid)
  // ==========================================
  Widget _buildSummary2View() {
    final branches = (_summaryData?['branches'] as List?) ?? [];
    final asOnDate = _summaryData?['asOnDate'] ?? {};
    final totalLeads = asOnDate['totalLeads'] ?? {};
    final totalBk = asOnDate['totalBk'] ?? {};
    final conversion = asOnDate['conversion'] ?? {};
    final sourceBreakup = (_summaryData?['sourceBreakup'] as List?) ?? [];

    final leadsAll = totalLeads['all'] ?? 0;
    final bkAll = totalBk['all'] ?? 0;
    final convAll = conversion['all'] ?? '0.00%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Consolidated Dealership Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSOLIDATED · ALL ${branches.length} DEALERSHIPS (${_selectedPeriod.toUpperCase()})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  const Text('Click any location card below to drill down, or select All Dealerships', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  _buildStatBubble('TOTAL LEADS', leadsAll.toString(), const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _buildStatBubble('BOOKINGS', bkAll.toString(), const Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  _buildStatBubble('CONVERSION', convAll.toString(), AppColors.primary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Location Cards 6-Grid
        const Text('SHOWROOM LOCATIONS (PUNE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 110,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: branches.length,
          itemBuilder: (context, i) {
            final b = branches[i];
            final bId = b['id'].toString();
            final isSel = _selectedBranch == bId;
            final leads = totalLeads[bId] ?? 0;
            final bk = totalBk[bId] ?? 0;
            final conv = conversion[bId] ?? '0.00%';

            return InkWell(
              onTap: () {
                setState(() => _selectedBranch = isSel ? 'all' : bId);
                _loadSummary();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LOCATION ${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        Text(b['code'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    Text(b['name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$leads Leads', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                        Text('$bk Booked', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                        Text(conv, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Lead Channel Funnel
        const Text('CHANNEL & ATTRIBUTION BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            children: sourceBreakup.map((s) {
              final label = s['label'] ?? '';
              final count = (s['values']?['all'] ?? 0) as int;
              final maxLeads = leadsAll > 0 ? leadsAll : 1;
              final pct = (count / maxLeads);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        Text('$count enquiries (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: pct,
                      color: AppColors.primary,
                      backgroundColor: const Color(0xFFF1F5F9),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBubble(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ==========================================
  // 3. FINANCIAL VIEW (Sold Vehicles Revenue)
  // ==========================================
  Widget _buildFinancialView() {
    final financials = _summaryData?['financials'] ?? {};
    final totals = financials['totals'] ?? {};
    final byLocation = (financials['byLocation'] as List?) ?? [];
    final byCategory = (financials['byCategory'] as List?) ?? [];
    final byMode = (financials['byMode'] as List?) ?? [];
    final byModel = (financials['byModel'] as List?) ?? [];

    final units = totals['units'] ?? 0;
    final onRoad = totals['onRoad'] ?? 0;
    final exShowroom = totals['exShowroom'] ?? 0;
    final roadTax = totals['roadTax'] ?? 0;
    final insurance = totals['insurance'] ?? 0;
    final accessories = totals['stdAccessories'] ?? 0;
    final avgDealSize = units > 0 ? (onRoad / units).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Revenue Totals Grid
        Row(
          children: [
            Expanded(child: _buildFinancialKpi('TOTAL REVENUE', CurrencyFormatter.format(onRoad), '$units units sold', AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _buildFinancialKpi('EX-SHOWROOM', CurrencyFormatter.format(exShowroom), 'Vehicle Base Price', const Color(0xFF2563EB))),
            const SizedBox(width: 12),
            Expanded(child: _buildFinancialKpi('RTO ROAD TAX', CurrencyFormatter.format(roadTax), 'Government Tax Collected', const Color(0xFF0D9488))),
            const SizedBox(width: 12),
            Expanded(child: _buildFinancialKpi('INSURANCE', CurrencyFormatter.format(insurance), 'Comprehensive Covers', const Color(0xFF7C3AED))),
            const SizedBox(width: 12),
            Expanded(child: _buildFinancialKpi('AVG DEAL SIZE', CurrencyFormatter.format(avgDealSize), 'Std Acc: ${CurrencyFormatter.format(accessories)}', const Color(0xFFEA580C))),
          ],
        ),
        const SizedBox(height: 20),

        // Revenue by Location Table
        const Text('REVENUE BY SHOWROOM LOCATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2),
              5: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                children: [
                  _buildTableCell('LOCATION / BRANCH', isHeader: true),
                  _buildTableCell('UNITS', isHeader: true),
                  _buildTableCell('EX-SHOWROOM', isHeader: true),
                  _buildTableCell('ROAD TAX', isHeader: true),
                  _buildTableCell('INSURANCE', isHeader: true),
                  _buildTableCell('TOTAL ON-ROAD', isHeader: true),
                ],
              ),
              ...byLocation.map((b) {
                return TableRow(
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                  children: [
                    _buildTableCell('${b['name']} (${b['code']})', isBold: true),
                    _buildTableCell('${b['units']}'),
                    _buildTableCell(CurrencyFormatter.format(b['exShowroom'])),
                    _buildTableCell(CurrencyFormatter.format(b['roadTax'])),
                    _buildTableCell(CurrencyFormatter.format(b['insurance'])),
                    _buildTableCell(CurrencyFormatter.format(b['onRoad']), isBold: true, color: AppColors.primary),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // By Category & By Mode
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // By Category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CATEGORY DISTRIBUTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      children: byCategory.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat['category'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('${cat['units']} units · ${CurrencyFormatter.format(cat['onRoad'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // By Mode
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COMMERCIAL MODE SHARE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      children: byMode.map((m) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m['mode'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('${m['units']} units · ${CurrencyFormatter.format(m['onRoad'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (byModel.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('REVENUE BY VEHICLE MODEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(2.5),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                  children: [
                    _buildTableCell('MODEL NAME', isHeader: true),
                    _buildTableCell('SOLD', isHeader: true),
                    _buildTableCell('AVG ON-ROAD', isHeader: true),
                    _buildTableCell('EX-SHOWROOM', isHeader: true),
                    _buildTableCell('TOTAL REVENUE', isHeader: true),
                  ],
                ),
                ...byModel.map((m) {
                  return TableRow(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                    children: [
                      _buildTableCell('${m['modelName']} (${m['category']})', isBold: true),
                      _buildTableCell('${m['units']}'),
                      _buildTableCell(CurrencyFormatter.format(m['unitPrice'])),
                      _buildTableCell(CurrencyFormatter.format(m['exShowroom'])),
                      _buildTableCell(CurrencyFormatter.format(m['onRoad']), isBold: true, color: AppColors.primary),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinancialKpi(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isHeader || isBold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? (isHeader ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
        ),
      ),
    );
  }
}
