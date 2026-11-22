import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../auth/auth_notifier.dart';

class DealershipSummaryScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const DealershipSummaryScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<DealershipSummaryScreen> createState() => _DealershipSummaryScreenState();
}

class _DealershipSummaryScreenState extends ConsumerState<DealershipSummaryScreen> {
  String _activeView = 'matrix'; // 'matrix', 'summary2'
  String _selectedPeriod = 'today'; // 'today', 'week', 'mtd', 'ytd'
  DateTime _selectedDate = DateTime.now();
  String _selectedBranch = 'all';
  bool _swapRowsCols = false;
  String _transposedFilter = 'all';

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
          return;
        }
        msg = e.response?.data?['message'] ?? e.message ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _stepDate(int deltaDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: deltaDays));
    });
    _loadSummary();
  }

  void _handlePrint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dealership Summary Report formatted for printing.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar Controls
            _buildTopControls(),
            const SizedBox(height: 16),

            // Active View Content
            if (_isLoading)
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Calculating dealership analytics...', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            else if (_summaryData == null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(child: Text('No summary data available for this range.')),
              )
            else ...[
              if (_activeView == 'matrix') _buildMatrixView(),
              if (_activeView == 'summary2') _buildSummary2View(),
            ],
          ],
        ),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
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

          // Print & Refresh
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Print summary view',
                child: InkWell(
                  onTap: _handlePrint,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 6),
                        Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Reload latest dealership metrics from database',
                onPressed: _loadSummary,
              ),
            ],
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSel ? Colors.white : const Color(0xFF334155),
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

    if (_swapRowsCols) {
      return _buildTransposedMatrix(
        branches: branches,
        branchIds: branchIds,
        totalLeads: totalLeads,
        totalBk: totalBk,
        conversion: conversion,
        modeBreakup: modeBreakup,
        sourceBreakup: sourceBreakup,
        modelWiseLeads: modelWiseLeads,
        modelWiseBk: modelWiseBk,
        salesExWiseBk: salesExWiseBk,
        mtdModelConv: mtdModelConv,
        mtdSalesExConv: mtdSalesExConv,
        mtdSourceConv: mtdSourceConv,
        mtdModeConv: mtdModeConv,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
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
                        Text('All Dealerships', style: TextStyle(fontSize: 10, color: Color(0xFF92400E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section 1: AS ON DATE
            _buildSectionHeader('AS ON DATE ($date)'),
            _buildMatrixDataRow('TOTAL LEADS', branches, branchIds, (id) => (totalLeads[id] ?? 0).toString(), isBold: true, highlightColor: const Color(0xFF2563EB)),
            _buildMatrixDataRow('TOTAL BK', branches, branchIds, (id) => (totalBk[id] ?? 0).toString(), isBold: true, highlightColor: const Color(0xFF16A34A)),
            _buildMatrixDataRow('CONVERSION', branches, branchIds, (id) => (conversion[id] ?? '0.00%').toString(), isBold: true, highlightColor: const Color(0xFFDC2626)),

            // Section 2: MODE BREAK UP
            _buildSectionHeader('MODE BREAK UP'),
            ...modeBreakup.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 3: SOURCE
            _buildSectionHeader('SOURCE'),
            ...sourceBreakup.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 4: MODEL WISE LEADS
            _buildSectionHeader('MODEL WISE LEADS'),
            ...modelWiseLeads.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 5: MODEL WISE BK
            _buildSectionHeader('MODEL WISE BK'),
            ...modelWiseBk.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? 0).toString(), highlightColor: const Color(0xFF16A34A))),

            // Section 6: SALES EX WISE BK
            _buildSectionHeader('SALES EX WISE BK'),
            ...salesExWiseBk.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? 0).toString())),

            // Section 7: MTD LEADS TO CONVERSION
            _buildSectionHeader('MTD LEADS TO CONVERSION ($monthStart TO $date)'),
            ...mtdModelConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 8: MTD SALES EX WISE CONV
            _buildSectionHeader('MTD SALES EX WISE CONV'),
            ...mtdSalesExConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 9: SOURCE WISE CONVERSION (MTD)
            _buildSectionHeader('SOURCE WISE CONVERSION (MTD)'),
            ...mtdSourceConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),

            // Section 10: MODE WISE BREAKUP (MTD)
            _buildSectionHeader('MODE WISE BREAKUP (MTD)'),
            ...mtdModeConv.map((row) => _buildMatrixDataRow(row['label'] ?? '', branches, branchIds, (id) => (row['values']?[id] ?? '-').toString(), isConvFormat: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransposedMatrix({
    required List branches,
    required List<String> branchIds,
    required Map totalLeads,
    required Map totalBk,
    required Map conversion,
    required List modeBreakup,
    required List sourceBreakup,
    required List modelWiseLeads,
    required List modelWiseBk,
    required List salesExWiseBk,
    required List mtdModelConv,
    required List mtdSalesExConv,
    required List mtdSourceConv,
    required List mtdModeConv,
  }) {
    // Build list of all available transposed metric columns
    final List<Map<String, dynamic>> allColumns = [
      // 1. Core KPIs
      {
        'section': 'core',
        'sectionTitle': 'AS ON DATE',
        'label': 'TOTAL LEADS',
        'width': 120.0,
        'getValue': (String id) => (totalLeads[id] ?? 0).toString(),
        'color': const Color(0xFF2563EB),
        'isBold': true,
      },
      {
        'section': 'core',
        'sectionTitle': 'AS ON DATE',
        'label': 'TOTAL BK',
        'width': 110.0,
        'getValue': (String id) => (totalBk[id] ?? 0).toString(),
        'color': const Color(0xFF16A34A),
        'isBold': true,
      },
      {
        'section': 'core',
        'sectionTitle': 'AS ON DATE',
        'label': 'CONVERSION',
        'width': 120.0,
        'getValue': (String id) => (conversion[id] ?? '0.00%').toString(),
        'color': const Color(0xFFDC2626),
        'isBold': true,
      },

      // 2. Modes
      ...modeBreakup.map((row) => {
        'section': 'mode',
        'sectionTitle': 'MODE BREAK UP',
        'label': (row['label'] ?? '').toString(),
        'width': 110.0,
        'getValue': (String id) => (row['values']?[id] ?? 0).toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 3. Sources
      ...sourceBreakup.map((row) => {
        'section': 'source',
        'sectionTitle': 'SOURCE',
        'label': (row['label'] ?? '').toString(),
        'width': 150.0,
        'getValue': (String id) => (row['values']?[id] ?? 0).toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 4. Model Wise Leads
      ...modelWiseLeads.map((row) => {
        'section': 'model',
        'sectionTitle': 'MODEL LEADS',
        'label': (row['label'] ?? '').toString(),
        'width': 140.0,
        'getValue': (String id) => (row['values']?[id] ?? 0).toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 5. Model Wise Bookings
      ...modelWiseBk.map((row) => {
        'section': 'model',
        'sectionTitle': 'MODEL BK',
        'label': '${row['label'] ?? ''} (BK)',
        'width': 140.0,
        'getValue': (String id) => (row['values']?[id] ?? 0).toString(),
        'color': const Color(0xFF16A34A),
        'isBold': true,
      }),

      // 6. Sales Executive Wise Bookings
      ...salesExWiseBk.map((row) => {
        'section': 'sales',
        'sectionTitle': 'SALES EX BK',
        'label': (row['label'] ?? '').toString(),
        'width': 145.0,
        'getValue': (String id) => (row['values']?[id] ?? 0).toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 7. MTD Model Conversion
      ...mtdModelConv.map((row) => {
        'section': 'mtd',
        'sectionTitle': 'MTD MODEL CONV',
        'label': '${row['label'] ?? ''} (MTD)',
        'width': 155.0,
        'getValue': (String id) => (row['values']?[id] ?? '-').toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 8. MTD Sales Executive Conversion
      ...mtdSalesExConv.map((row) => {
        'section': 'mtd',
        'sectionTitle': 'MTD REP CONV',
        'label': '${row['label'] ?? ''} (MTD)',
        'width': 155.0,
        'getValue': (String id) => (row['values']?[id] ?? '-').toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 9. MTD Source Conversion
      ...mtdSourceConv.map((row) => {
        'section': 'mtd',
        'sectionTitle': 'MTD SOURCE CONV',
        'label': '${row['label'] ?? ''} (MTD)',
        'width': 160.0,
        'getValue': (String id) => (row['values']?[id] ?? '-').toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),

      // 10. MTD Mode Conversion
      ...mtdModeConv.map((row) => {
        'section': 'mtd',
        'sectionTitle': 'MTD MODE CONV',
        'label': '${row['label'] ?? ''} (MTD)',
        'width': 150.0,
        'getValue': (String id) => (row['values']?[id] ?? '-').toString(),
        'color': const Color(0xFF0F172A),
        'isBold': false,
      }),
    ];

    final filteredColumns = _transposedFilter == 'all'
        ? allColumns
        : allColumns.where((col) => col['section'] == _transposedFilter).toList();

    final filterTabs = [
      {'id': 'all', 'label': 'All Details (${allColumns.length})'},
      {'id': 'core', 'label': 'Core KPIs (3)'},
      {'id': 'mode', 'label': 'Payment Modes (${modeBreakup.length})'},
      {'id': 'source', 'label': 'Lead Sources (${sourceBreakup.length})'},
      {'id': 'model', 'label': 'Models (${modelWiseLeads.length + modelWiseBk.length})'},
      {'id': 'sales', 'label': 'Sales Reps (${salesExWiseBk.length})'},
      {'id': 'mtd', 'label': 'MTD Conversions (${mtdModelConv.length + mtdSalesExConv.length + mtdSourceConv.length + mtdModeConv.length})'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Filter Bar above transposed matrix
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('FILTER METRICS: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  ...filterTabs.map((tab) {
                    final isSelected = _transposedFilter == tab['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _transposedFilter = tab['id'] as String),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFDC2626) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            tab['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Transposed Matrix Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transposed Header: LOCATION + All Filtered Columns
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LOCATION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                            Text('Showroom Branch', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      ...filteredColumns.map((col) {
                        return Container(
                          width: col['width'] as double,
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (col['sectionTitle'] ?? '').toString(),
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (col['label'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: col['color'] as Color? ?? const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Data Rows: 1 Row per Branch + Consolidated
                ...branchIds.map((bId) {
                  final isAll = bId == 'all';
                  final b = branches.firstWhere(
                    (element) => element['id'].toString() == bId,
                    orElse: () => {'name': 'Consolidated Dealerships', 'code': 'ALL'},
                  );
                  final bName = isAll ? 'CONSOLIDATED (All Dealerships)' : (b['name'] ?? '');
                  final bCode = isAll ? '' : (b['code'] ?? '');

                  return Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isAll ? const Color(0xFFFEF3C7) : Colors.white,
                      border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isAll ? FontWeight.w900 : FontWeight.w600,
                                    color: isAll ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (bCode.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bCode,
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...filteredColumns.map((col) {
                          final getter = col['getValue'] as String Function(String);
                          final val = getter(bId);
                          final isBold = isAll || (col['isBold'] as bool? ?? false);
                          final color = isAll
                              ? const Color(0xFFB45309)
                              : (col['color'] as Color? ?? const Color(0xFF334155));

                          return Container(
                            width: col['width'] as double,
                            decoration: const BoxDecoration(
                              border: Border(left: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            child: Text(
                              val,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                                color: color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _findBreakupVal(List list, String label, String bId) {
    final item = list.firstWhere((e) => (e['label'] ?? '').toString().toUpperCase() == label.toUpperCase(), orElse: () => null);
    if (item == null) return 0;
    return (item['values']?[bId] ?? 0) as int;
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: 1515,
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
    List branches,
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
            final bName = isAll
                ? 'All Dealerships'
                : (branches.firstWhere((b) => b['id'].toString() == bId, orElse: () => {'name': ''})['name'] ?? '');

            return Container(
              width: isAll ? 185 : 175,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isAll ? const Color(0xFFFFFBEB) : Colors.white,
                border: const Border(left: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              alignment: Alignment.center,
              child: isConvFormat
                  ? _buildConvPillCell(bName, label, val)
                  : Text(
                      val,
                      style: TextStyle(
                        fontSize: isBold ? 13 : 11.5,
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

  Widget _buildConvPillCell(String branchName, String rowLabel, String val) {
    // Expected formats: "X LEADS / Y BK / Z% CONV" or "XL / YBK / Z%"
    final parts = val.split('/');
    if (parts.length >= 3) {
      final leadsStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
      final bkStr = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      final convStr = parts[2].replaceAll(RegExp(r'[^0-9]'), '');

      final tooltipMsg = '$branchName • $rowLabel: $val';

      return Tooltip(
        message: tooltipMsg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge('${leadsStr.padLeft(2, '0')}L', const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
            const SizedBox(width: 4),
            _buildBadge('${bkStr.padLeft(2, '0')}BK', const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
            const SizedBox(width: 4),
            _buildBadge('${convStr.padLeft(2, '0')}%', const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
          ],
        ),
      );
    }

    return Text(val, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)));
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
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
    final modeBreakup = (_summaryData?['modeBreakup'] as List?) ?? [];
    final modelWiseLeads = (_summaryData?['modelWiseLeads'] as List?) ?? [];
    final modelWiseBk = (_summaryData?['modelWiseBk'] as List?) ?? [];
    final mtdModelConv = (_summaryData?['mtdModelConv'] as List?) ?? [];
    final salesExWiseBk = (_summaryData?['salesExWiseBk'] as List?) ?? [];
    final mtdSalesExConv = (_summaryData?['mtdSalesExConv'] as List?) ?? [];

    final leadsAll = (totalLeads['all'] ?? 0) as int;
    final bkAll = (totalBk['all'] ?? 0) as int;
    final convAll = (conversion['all'] ?? '0.00%').toString();

    // Calculate source breakdowns for today
    final walkIns = _findBreakupVal(sourceBreakup, 'WALK IN', 'all');
    final calls = _findBreakupVal(sourceBreakup, 'TELE', 'all');
    final online = _findBreakupVal(sourceBreakup, 'ONLINE', 'all');
    final referrals = _findBreakupVal(sourceBreakup, 'REFERRAL', 'all');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Consolidated Dealership Top Card (matching Screenshot 5)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONSOLIDATED · ALL ${branches.length} DEALERSHIPS (${_selectedPeriod.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Click any location card below to drill down, or click here for all locations',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    '$convAll Conv',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Metrics Row: Total Leads | Walk-ins | Calls | Online | Referrals | Booked / Sold
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLargeKpi('Total Leads', leadsAll.toString(), const Color(0xFF0F172A)),
                  _buildLargeKpi('Walk-ins', walkIns.toString(), const Color(0xFF2563EB)),
                  _buildLargeKpi('Calls', calls.toString(), const Color(0xFF0D9488)),
                  _buildLargeKpi('Online', online.toString(), const Color(0xFFF59E0B)),
                  _buildLargeKpi('Referrals', referrals.toString(), const Color(0xFF8B5CF6)),
                  _buildLargeKpi('Booked / Sold', bkAll.toString(), const Color(0xFF16A34A)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. 6 Location Cards Row (matching Screenshot 5)
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: List.generate(branches.length, (i) {
                final b = branches[i];
                final bId = b['id'].toString();
                final isSel = _selectedBranch == bId;
                final leads = totalLeads[bId] ?? 0;
                final conv = conversion[bId] ?? '0.00%';
                final bWalk = _findBreakupVal(sourceBreakup, 'WALK IN', bId);
                final bCalls = _findBreakupVal(sourceBreakup, 'TELE', bId);
                final bRef = _findBreakupVal(sourceBreakup, 'REFERRAL', bId);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < branches.length - 1 ? 12 : 0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedBranch = isSel ? 'all' : bId);
                        _loadSummary();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFFFEF2F2) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: isSel ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('LOCATION ${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                Text(conv, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFDC2626))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniSubKpi('$leads', 'Total'),
                                _buildMiniSubKpi('$bWalk', 'Walk'),
                                _buildMiniSubKpi('$bCalls', 'Calls'),
                                _buildMiniSubKpi('$bRef', 'Ref'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 20),

        // 3. Middle Dual Charts Row: Leads vs Bookings & Source/Payment Mix
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Dealership Leads vs Bookings
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('DEALERSHIP LEADS VS BOOKINGS (TODAY)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Row(
                          children: [
                            _buildLegendItem('Leads', const Color(0xFF2563EB)),
                            const SizedBox(width: 10),
                            _buildLegendItem('Booked', const Color(0xFF16A34A)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...branches.map((b) {
                      final bId = b['id'].toString();
                      final index = branches.indexOf(b) + 1;
                      final l = (totalLeads[bId] ?? 0) as int;
                      final bk = (totalBk[bId] ?? 0) as int;
                      final c = conversion[bId] ?? '0.00%';
                      const maxVal = 12.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('LOC $index · ${b['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                Text('${l}L / ${bk}BK ($c)', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Stack(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // Leads bar
                                FractionallySizedBox(
                                  widthFactor: (l / maxVal).clamp(0.05, 1.0),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                // Bookings bar
                                FractionallySizedBox(
                                  widthFactor: (bk / maxVal).clamp(0.02, 1.0),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right Card: Source & Payment Mix
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SOURCE & PAYMENT MIX (TODAY)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('All Locations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Enquiry Sources Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Enquiry Sources', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        Text('$leadsAll total leads', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSegmentedBar([
                      {'val': walkIns, 'color': const Color(0xFF2563EB)},
                      {'val': calls, 'color': const Color(0xFF0D9488)},
                      {'val': online, 'color': const Color(0xFFF59E0B)},
                      {'val': referrals, 'color': const Color(0xFF8B5CF6)},
                    ], leadsAll),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildLegendItem('WALK IN $walkIns (${leadsAll > 0 ? ((walkIns / leadsAll) * 100).round() : 0}%)', const Color(0xFF2563EB)),
                        _buildLegendItem('TELE $calls (${leadsAll > 0 ? ((calls / leadsAll) * 100).round() : 0}%)', const Color(0xFF0D9488)),
                        _buildLegendItem('ONLINE $online (${leadsAll > 0 ? ((online / leadsAll) * 100).round() : 0}%)', const Color(0xFFF59E0B)),
                        _buildLegendItem('REFERRAL $referrals (${leadsAll > 0 ? ((referrals / leadsAll) * 100).round() : 0}%)', const Color(0xFF8B5CF6)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Payment Modes Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Modes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                        Text('$leadsAll total leads', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSegmentedBar([
                      {'val': _findBreakupVal(modeBreakup, 'CASH', 'all'), 'color': const Color(0xFF16A34A)},
                      {'val': _findBreakupVal(modeBreakup, 'FINANCE', 'all'), 'color': const Color(0xFF2563EB)},
                      {'val': _findBreakupVal(modeBreakup, 'EXCHANGE', 'all'), 'color': const Color(0xFFEA580C)},
                    ], leadsAll),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildLegendItem('CASH ${_findBreakupVal(modeBreakup, "CASH", "all")} (${leadsAll > 0 ? ((_findBreakupVal(modeBreakup, "CASH", "all") / leadsAll) * 100).round() : 0}%)', const Color(0xFF16A34A)),
                        _buildLegendItem('FINANCE ${_findBreakupVal(modeBreakup, "FINANCE", "all")} (${leadsAll > 0 ? ((_findBreakupVal(modeBreakup, "FINANCE", "all") / leadsAll) * 100).round() : 0}%)', const Color(0xFF2563EB)),
                        _buildLegendItem('EXCHANGE ${_findBreakupVal(modeBreakup, "EXCHANGE", "all")} (${leadsAll > 0 ? ((_findBreakupVal(modeBreakup, "EXCHANGE", "all") / leadsAll) * 100).round() : 0}%)', const Color(0xFFEA580C)),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 3 KPI Highlights at bottom of Card
                    Row(
                      children: [
                        Expanded(
                          child: _buildMixHighlightCard(
                            'TOP SOURCE',
                            'WALK IN (${leadsAll > 0 ? ((walkIns / leadsAll) * 100).round() : 0}%)',
                            const Color(0xFFEFF6FF),
                            const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMixHighlightCard(
                            'FINANCE PENETRATION',
                            '${leadsAll > 0 ? ((_findBreakupVal(modeBreakup, "FINANCE", "all") / leadsAll) * 100).round() : 0}% (${_findBreakupVal(modeBreakup, "FINANCE", "all")})',
                            const Color(0xFFEFF6FF),
                            const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMixHighlightCard(
                            'EXCHANGE RATE',
                            '${leadsAll > 0 ? ((_findBreakupVal(modeBreakup, "EXCHANGE", "all") / leadsAll) * 100).round() : 0}% (${_findBreakupVal(modeBreakup, "EXCHANGE", "all")})',
                            const Color(0xFFFFF7ED),
                            const Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Bottom Dual Tables Row: Model Performance & Sales Exec Performance (Image 6)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Table: Model-Wise Performance
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MODEL-WISE PERFORMANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('TODAY & MTD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(2.2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                          children: [
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Text('MODEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('TODAY LEADS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('TODAY BK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('MTD (L / BK / CONV)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                          ],
                        ),
                        ...modelWiseLeads.map((m) {
                          final label = m['label'] ?? '';
                          final tLeads = (m['values']?['all'] ?? 0) as int;
                          final bkItem = modelWiseBk.firstWhere((e) => e['label'] == label, orElse: () => null);
                          final tBk = (bkItem?['values']?['all'] ?? 0) as int;

                          final mtdItem = mtdModelConv.firstWhere((e) => e['label'] == label, orElse: () => null);
                          final mtdVal = (mtdItem?['values']?['all'] ?? '-').toString();

                          return TableRow(
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('$tLeads', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('$tBk', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: _buildMtdShortText(mtdVal))),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Right Table: Sales Executive Performance
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SALES EXECUTIVE PERFORMANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('TODAY BK & MTD Conv', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.4),
                        3: FlexColumnWidth(1.2),
                        4: FlexColumnWidth(1.2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                          children: [
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Text('SALES REP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('TODAY BK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('MTD LEADS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('MTD BK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                            Padding(padding: EdgeInsets.only(bottom: 8), child: Center(child: Text('CONV %', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))))),
                          ],
                        ),
                        ...salesExWiseBk.map((rep) {
                          final label = rep['label'] ?? '';
                          final todayBk = (rep['values']?['all'] ?? 0) as int;

                          final mtdItem = mtdSalesExConv.firstWhere((e) => e['label'] == label, orElse: () => null);
                          final mtdRaw = (mtdItem?['values']?['all'] ?? '').toString();
                          final parts = mtdRaw.split('/');
                          final mtdL = parts.isNotEmpty ? parts[0].replaceAll(RegExp(r'[^0-9]'), '') : '0';
                          final mtdB = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '0';
                          final mtdC = parts.length > 2 ? parts[2].replaceAll(RegExp(r'[^0-9]'), '') : '0';

                          return TableRow(
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('$todayBk', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(mtdL, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text(mtdB, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('$mtdC%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))))),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMtdShortText(String raw) {
    final parts = raw.split('/');
    if (parts.length >= 3) {
      final l = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
      final b = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      final c = parts[2].replaceAll(RegExp(r'[^0-9]'), '');
      return Text(
        '$l / $b  $c%',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
      );
    }
    return Text(raw, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)));
  }

  Widget _buildSegmentedBar(List<Map<String, dynamic>> segments, int total) {
    final safeTotal = total > 0 ? total : 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 10,
        color: const Color(0xFFF1F5F9),
        child: Row(
          children: segments.map((seg) {
            final val = (seg['val'] as int?) ?? 0;
            final flex = (val / safeTotal * 1000).round();
            if (flex <= 0) return const SizedBox.shrink();
            return Expanded(
              flex: flex,
              child: Container(color: seg['color'] as Color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMixHighlightCard(String title, String val, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg)),
        ],
      ),
    );
  }

  Widget _buildLargeKpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildMiniSubKpi(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ],
    );
  }

}
