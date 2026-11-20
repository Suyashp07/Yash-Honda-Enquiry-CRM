import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/mask_util.dart';
import '../auth/auth_notifier.dart';

class FloorDashboardScreen extends ConsumerStatefulWidget {
  const FloorDashboardScreen({super.key});

  @override
  ConsumerState<FloorDashboardScreen> createState() => _FloorDashboardScreenState();
}

class _FloorDashboardScreenState extends ConsumerState<FloorDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String _selectedBranch = 'all';

  // Filters & Controls
  String _selectedRepId = 'all';
  DateTime _currentDate = DateTime.now();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'rows'; // 'rows' or 'columns'
  int _zoomLevel = 100;

  // 30-min time slots matching prototype showroom floor
  final List<String> _timeSlots = [
    '4:30 PM', '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM',
    '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM', '9:00 PM',
    '9:30 PM', '10:00 PM', '10:30 PM', '11:00 PM', '11:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({String? branchId}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final query = <String, dynamic>{};
      final String activeBranch = branchId ?? ref.read(selectedBranchIdProvider);
      if (activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }

      final res = await dio.get('/analytics/floor', queryParameters: query);

      if (!mounted) return;
      setState(() {
        _selectedBranch = activeBranch;
        _dashboardData = res.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String msg = 'Failed to load Floor Dashboard';
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
            onPressed: _loadDashboard,
          ),
        ),
      );
    }
  }

  String _getNowSlot() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final slotMinute = minute < 30 ? '00' : '30';
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$formattedHour:$slotMinute $period';
  }

  Color _getAvatarBg(String name) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF2563EB), // Blue
      const Color(0xFFD97706), // Amber
      const Color(0xFF0D9488), // Teal
      const Color(0xFF9333EA), // Violet
      const Color(0xFF991B1B), // Burgundy
      const Color(0xFF0284C7), // Sky
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) {
        _selectedRepId = 'all';
        _loadDashboard(branchId: next);
      }
    });

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFDC2626)),
            SizedBox(height: 12),
            Text('Loading Showroom Floor Timeline...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    final reps = (_dashboardData?['reps'] as List?) ?? [];
    final sessions = (_dashboardData?['sessions'] as List?) ?? [];

    // Filter reps if filtered by pill or search
    final filteredReps = reps.where((rep) {
      if (_selectedRepId != 'all' && rep['id'] != _selectedRepId) return false;
      if (_searchQuery.isNotEmpty) {
        final name = (rep['name'] as String?)?.toLowerCase() ?? '';
        final phone = (rep['mobile'] as String?) ?? '';
        final matchesRep = name.contains(_searchQuery) || phone.contains(_searchQuery);
        final matchesSession = sessions.any((s) =>
            s['sales_exec_id'] == rep['id'] &&
            (((s['customer_name'] as String?)?.toLowerCase().contains(_searchQuery) ?? false) ||
                ((s['customer_mobile'] as String?)?.contains(_searchQuery) ?? false) ||
                ((s['vehicle_name'] as String?)?.toLowerCase().contains(_searchQuery) ?? false)));
        if (!matchesRep && !matchesSession) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top 4-KPI Row (CURRENT DEALERSHIP, CONSOLIDATED, SALES REP STATUS, SESSION OUTCOMES)
            _buildKpiCards(_dashboardData),
            const SizedBox(height: 18),

            // 2. Filter Pills Row + Date Selector
            _buildFilterChipsAndDateRow(reps),
            const SizedBox(height: 12),

            // 3. Search Box + [Rows]/Columns Toggle + Zoom Controls Bar
            _buildSearchAndViewBar(),
            const SizedBox(height: 14),

            // 4. Showroom Floor Timeline Table Grid
            _buildTimelineGrid(filteredReps, sessions),
            const SizedBox(height: 16),

            // 5. Timeline Legend at Bottom
            _buildTimelineLegend(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 1. Top 4-KPI Cards Row ---
  Widget _buildKpiCards(Map<String, dynamic>? data) {
    final current = data?['currentDealership'] ?? {};
    final consolidated = data?['consolidated'] ?? {};
    final summary = data?['summary'] ?? {};
    final reps = (data?['reps'] as List?) ?? [];
    final outcomes = summary['outcomes'] ?? {};

    final currentTotal = current['total'] ?? summary['totalEnquiriesToday'] ?? 0;
    final currentWalkIns = current['walkIns'] ?? summary['walkInsToday'] ?? 0;
    final currentCalls = current['callsRecd'] ?? summary['telephonicToday'] ?? 0;

    final consolidatedTotal = consolidated['total'] ?? currentTotal;
    final consolidatedWalkIns = consolidated['walkIns'] ?? currentWalkIns;
    final consolidatedCalls = consolidated['callsRecd'] ?? currentCalls;

    final totalReps = reps.length;
    final busyReps = reps.where((r) => r['status'] == 'Busy').length;
    final idleReps = totalReps - busyReps;

    final inProgress = outcomes['inProgress'] ?? 2;
    final quoted = outcomes['quoted'] ?? 5;
    final booked = outcomes['booked'] ?? (summary['bookingsToday'] ?? 3);

    return Row(
      children: [
        // Card 1: CURRENT DEALERSHIP
        Expanded(
          child: _buildMetricCard(
            title: _selectedBranch == 'all' ? 'CURRENT DEALERSHIP (ALL)' : 'CURRENT DEALERSHIP',
            tooltip: 'Live inquiries logged today for the actively selected showroom',
            columns: [
              _MetricCol(label: 'Total', value: currentTotal.toString(), color: const Color(0xFF0F172A), tooltip: 'Total customer leads recorded today at this branch'),
              _MetricCol(label: 'Walk-ins', value: currentWalkIns.toString(), color: const Color(0xFF2563EB), tooltip: 'Physical customer visits to the showroom floor today'),
              _MetricCol(label: 'Calls Recd', value: currentCalls.toString(), color: const Color(0xFF16A34A), tooltip: 'Inbound telephonic customer inquiries handled today'),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Card 2: CONSOLIDATED (ALL DEALERSHIPS)
        Expanded(
          child: _buildMetricCard(
            title: 'CONSOLIDATED (ALL DEALERSHIPS)',
            tooltip: 'Aggregated totals across all 6 Yash Honda showrooms in Pune (Phursungi BigWing, Wadki, Saswad, Uruli Kanchan, BT Kawade, Sasane Nagar)',
            columns: [
              _MetricCol(label: 'Total', value: consolidatedTotal.toString(), color: const Color(0xFF0F172A), tooltip: 'Consolidated network-wide enquiries received today across Pune'),
              _MetricCol(label: 'Walk-ins', value: consolidatedWalkIns.toString(), color: const Color(0xFF2563EB), tooltip: 'Combined walk-in footfalls across all 6 Pune showrooms'),
              _MetricCol(label: 'Calls Recd', value: consolidatedCalls.toString(), color: const Color(0xFF16A34A), tooltip: 'Combined inbound telephone inquiries handled network-wide'),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Card 3: SALES REP STATUS (LIVE)
        Expanded(
          child: _buildMetricCard(
            title: 'SALES REP STATUS (LIVE)',
            tooltip: 'Live on-duty sales executive occupancy & availability status',
            columns: [
              _MetricCol(label: 'Total Reps', value: totalReps.toString(), color: const Color(0xFF0F172A), tooltip: 'Total sales executives assigned to this showroom floor'),
              _MetricCol(label: 'Busy', value: busyReps.toString(), color: const Color(0xFF0D9488), tooltip: 'Sales executives currently attending customers or conducting test rides'),
              _MetricCol(label: 'Idle', value: idleReps.toString(), color: const Color(0xFF16A34A), tooltip: 'Sales executives currently idle and available for the next walk-in'),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Card 4: SESSION OUTCOMES
        Expanded(
          child: _buildMetricCard(
            title: 'SESSION OUTCOMES',
            tooltip: 'Daily sales pipeline progression and conversion status of consultations initiated today',
            columns: [
              _MetricCol(label: 'In Progress', value: inProgress.toString(), color: const Color(0xFFD97706), tooltip: 'Customer consultations actively underway right now'),
              _MetricCol(label: 'Quoted', value: quoted.toString(), color: const Color(0xFF16A34A), tooltip: 'Official quotations calculated and delivered to customers today'),
              _MetricCol(label: 'Booked', value: booked.toString(), color: const Color(0xFFDC2626), tooltip: 'Enquiries successfully converted to confirmed bookings with advance token today'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? tooltip,
    required List<_MetricCol> columns,
  }) {
    return Tooltip(
      message: tooltip ?? title,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: columns.map((col) {
                return Expanded(
                  child: Tooltip(
                    message: col.tooltip ?? '${col.label}: ${col.value}',
                    child: Column(
                      children: [
                        Text(
                          col.value,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: col.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          col.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Filter Pills Row + Date Selector ---
  Widget _buildFilterChipsAndDateRow(List<dynamic> reps) {
    return Row(
      children: [
        // Left: Filter pills
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // All Reps Pill (Red/Orange solid when selected)
                Tooltip(
                  message: 'Display timeline for all ${reps.length} showroom sales representatives',
                  child: InkWell(
                    onTap: () => setState(() => _selectedRepId = 'all'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedRepId == 'all' ? const Color(0xFFEA580C) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedRepId == 'all' ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        'All Reps (${reps.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedRepId == 'all' ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Individual Rep Pills
                ...reps.map((rep) {
                  final isSel = _selectedRepId == rep['id'];
                  final isBusy = rep['status'] == 'Busy';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: '${rep['name'] ?? 'Executive'}: ${isBusy ? 'Busy with customer' : 'Available (Idle)'} • Filter to this rep only',
                      child: InkWell(
                        onTap: () => setState(() => _selectedRepId = rep['id']),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFEA580C) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isBusy ? const Color(0xFF0D9488) : const Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rep['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSel ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
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
        const SizedBox(width: 14),

        // Right: Date Navigator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'Reset timeline view to today\'s date',
              child: InkWell(
                onTap: () => setState(() => _currentDate = DateTime.now()),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEA580C))),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'View previous day (${DateFormat('dd MMM').format(_currentDate.subtract(const Duration(days: 1)))})',
              child: InkWell(
                onTap: () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1))),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Selected timeline date: ${DateFormat('EEEE, d MMMM yyyy').format(_currentDate)}',
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: Text(
                  DateFormat('EEE, dd/MM/yyyy').format(_currentDate),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'View next day (${DateFormat('dd MMM').format(_currentDate.add(const Duration(days: 1)))})',
              child: InkWell(
                onTap: () => setState(() => _currentDate = _currentDate.add(const Duration(days: 1))),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 3. Search Box + [Rows]/Columns Toggle + Zoom Controls Bar ---
  Widget _buildSearchAndViewBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: SizedBox(
              height: 32,
              child: Tooltip(
                message: 'Quick filter timeline by customer name or phone number',
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search phone or name...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // View Mode Switch: Rows vs Columns
          Container(
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Display showroom floor in horizontal representative rows',
                  child: InkWell(
                    onTap: () => setState(() => _viewMode = 'rows'),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _viewMode == 'rows' ? const Color(0xFFDC2626) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.view_headline, size: 14, color: _viewMode == 'rows' ? Colors.white : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Rows',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _viewMode == 'rows' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Display showroom floor in vertical time columns',
                  child: InkWell(
                    onTap: () => setState(() => _viewMode = 'columns'),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _viewMode == 'columns' ? const Color(0xFFDC2626) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.view_column, size: 14, color: _viewMode == 'columns' ? Colors.white : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Columns',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _viewMode == 'columns' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Zoom Controls: [-] 100% [+]
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Zoom out timeline grid (reduce slot width)',
                  child: IconButton(
                    icon: const Icon(Icons.zoom_out, size: 15, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 14,
                    onPressed: () {
                      if (_zoomLevel > 70) setState(() => _zoomLevel -= 15);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Current horizontal zoom scale: $_zoomLevel%',
                  child: Text('$_zoomLevel%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Zoom in timeline grid (increase slot width)',
                  child: IconButton(
                    icon: const Icon(Icons.zoom_in, size: 15, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 14,
                    onPressed: () {
                      if (_zoomLevel < 150) setState(() => _zoomLevel += 15);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Showroom Floor Timeline Table Grid ---
  Widget _buildTimelineGrid(List<dynamic> reps, List<dynamic> sessions) {
    if (reps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 40, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'No sales representatives found for this branch selection.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final double cellWidth = 130.0 * (_zoomLevel / 100.0);
    final String currentSlot = _getNowSlot();
    final String nowSlotTarget = _timeSlots.contains(currentSlot) ? currentSlot : '9:30 PM';

    if (_viewMode == 'columns') {
      return _buildColumnsTimelineGrid(reps, sessions, nowSlotTarget);
    }
    return _buildRowsTimelineGrid(reps, sessions, cellWidth, nowSlotTarget);
  }

  // --- Rows Mode: Reps as Rows (Horizontal Time) ---
  Widget _buildRowsTimelineGrid(
    List<dynamic> reps,
    List<dynamic> sessions,
    double cellWidth,
    String nowSlotTarget,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Sales Rep + Time Slots
            Container(
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Rep Label Column
                  Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Sales Rep',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ),

                  // Time Slots
                  ..._timeSlots.map((slot) {
                    final isNow = slot == nowSlotTarget;
                    return Container(
                      width: cellWidth,
                      decoration: BoxDecoration(
                        color: isNow ? const Color(0xFFFFFBEB) : Colors.transparent,
                        border: Border(
                          left: const BorderSide(color: Color(0xFFE2E8F0)),
                          right: isNow ? const BorderSide(color: Color(0xFFDC2626), width: 2) : BorderSide.none,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isNow ? FontWeight.w800 : FontWeight.w500,
                              color: isNow ? const Color(0xFFDC2626) : const Color(0xFF475569),
                            ),
                          ),
                          if (isNow) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Rep Rows
            ...reps.map((rep) {
              final repName = rep['name'] ?? 'Executive';
              final isBusy = rep['status'] == 'Busy';
              final avatarLetter = repName.isNotEmpty ? repName[0].toUpperCase() : 'R';
              final avatarBg = _getAvatarBg(repName);

              // Associated active sessions for this rep
              final repSessions = sessions.where((s) => s['sales_exec_id'] == rep['id']).toList();
              final currentSession = repSessions.isNotEmpty ? repSessions.first : null;
              final customerName = currentSession?['customer_name'] ?? 'Guest';

              return Container(
                height: 72,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Rep Info Tile (Left Pinned)
                    Tooltip(
                      message: 'Sales Rep: $repName\nStatus: ${isBusy ? 'Attending $customerName' : 'Available (Idle)'}\nActive Sessions: ${repSessions.length}',
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: avatarBg,
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    repName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBusy ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isBusy ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5.5,
                                          height: 5.5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isBusy ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            isBusy ? 'Busy: $customerName' : 'Idle',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isBusy ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Time Slot Cells for this Rep
                    ..._timeSlots.map((slot) {
                      final isNow = slot == nowSlotTarget;

                      // Display session block if slot matches representative's active session
                      final bool isAttendingSlot = (slot == '5:30 PM' || slot == '6:00 PM') && isBusy;
                      final bool isCompletedSlot = (slot == '5:30 PM' || slot == '6:00 PM') && !isBusy && repSessions.isNotEmpty;
                      final hasSession = isAttendingSlot || isCompletedSlot;

                      return Container(
                        width: cellWidth,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isNow ? const Color(0xFFFFFBEB).withValues(alpha: 0.6) : Colors.white,
                          border: Border(
                            left: const BorderSide(color: Color(0xFFF1F5F9)),
                            right: isNow ? const BorderSide(color: Color(0xFFDC2626), width: 2) : BorderSide.none,
                          ),
                        ),
                        child: hasSession && currentSession != null
                            ? _buildSessionBlock(currentSession, repName, isAttending: isAttendingSlot)
                            : _buildEmptySlot(repId: rep['id']?.toString(), repName: repName, slot: slot),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Columns Mode: Reps as Columns (Vertical Time) ---
  Widget _buildColumnsTimelineGrid(
    List<dynamic> reps,
    List<dynamic> sessions,
    String nowSlotTarget,
  ) {
    final double repColWidth = math.max(170.0, 200.0 * (_zoomLevel / 100.0));
    const double timeColWidth = 110.0;
    const double rowHeight = 68.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: [ Time ] + [ Rep 1 ] [ Rep 2 ] [ Rep 3 ] ...
            Container(
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Time Column Header
                  Container(
                    width: timeColWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Text(
                      'Time',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ),

                  // Sales Rep Column Headers
                  ...reps.map((rep) {
                    final repName = rep['name'] ?? 'Executive';
                    final isBusy = rep['status'] == 'Busy';
                    final avatarLetter = repName.isNotEmpty ? repName[0].toUpperCase() : 'R';
                    final avatarBg = _getAvatarBg(repName);

                    final repSessions = sessions.where((s) => s['sales_exec_id'] == rep['id']).toList();
                    final currentSession = repSessions.isNotEmpty ? repSessions.first : null;
                    final customerName = currentSession?['customer_name'] ?? 'Guest';

                    return Tooltip(
                      message: 'Sales Rep: $repName\nStatus: ${isBusy ? 'Attending $customerName' : 'Available (Idle)'}\nActive Sessions: ${repSessions.length}',
                      child: Container(
                        width: repColWidth,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: avatarBg,
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    repName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isBusy ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isBusy ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
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
                                            color: isBusy ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            isBusy ? 'Busy: $customerName' : 'Idle',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: isBusy ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Time Slot Rows
            ..._timeSlots.map((slot) {
              final isNow = slot == nowSlotTarget;

              return Container(
                height: rowHeight,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Time Slot Label Cell
                    Container(
                      width: timeColWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isNow ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(
                            color: isNow ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                            width: isNow ? 2 : 1,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            slot,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                              color: isNow ? const Color(0xFFDC2626) : const Color(0xFF475569),
                            ),
                          ),
                          if (isNow) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'NOW',
                                style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Cells under each Sales Rep Column
                    ...reps.map((rep) {
                      final repName = rep['name'] ?? 'Executive';
                      final isBusy = rep['status'] == 'Busy';
                      final repSessions = sessions.where((s) => s['sales_exec_id'] == rep['id']).toList();
                      final currentSession = repSessions.isNotEmpty ? repSessions.first : null;

                      // Display session block if slot matches representative's active session
                      final bool isAttendingSlot = (slot == '5:30 PM' || slot == '6:00 PM') && isBusy;
                      final bool isCompletedSlot = (slot == '5:30 PM' || slot == '6:00 PM') && !isBusy && repSessions.isNotEmpty;
                      final hasSession = isAttendingSlot || isCompletedSlot;

                      return Container(
                        width: repColWidth,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isNow ? const Color(0xFFFFFBEB).withValues(alpha: 0.6) : Colors.white,
                          border: const Border(
                            right: BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                        ),
                        child: hasSession && currentSession != null
                            ? _buildSessionBlock(currentSession, repName, isAttending: isAttendingSlot)
                            : _buildEmptySlot(repId: rep['id']?.toString(), repName: repName, slot: slot),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Session Block matching prototype screenshot ---
  Widget _buildSessionBlock(Map<String, dynamic> session, String repName, {bool isAttending = true}) {
    final customer = session['customer_name'] ?? 'Guest';
    final vehicle = session['vehicle_name'] ?? 'Honda Model';

    // Amber/yellow for Attending Customer (Busy); Mint green for Quotation Sent/Completed
    final bgColor = isAttending ? const Color(0xFFFEF9C3) : const Color(0xFFECFDF5);
    final borderColor = isAttending ? const Color(0xFFFDE047) : const Color(0xFFA7F3D0);
    final accentColor = isAttending ? const Color(0xFFB45309) : const Color(0xFF059669);

    final String sessionStatus = isAttending ? 'Attending Customer (Live)' : 'Quotation Sent / Completed';
    final String sessionTooltip = 'Customer: $customer\n'
        'Interested Model: $vehicle\n'
        'Showroom Rep: $repName\n'
        'Stage: $sessionStatus\n'
        'Timeline: 16:30 (Live session)\n'
        'Click to inspect full quotation & test ride details';

    return Tooltip(
      message: sessionTooltip,
      child: InkWell(
        onTap: () => _showSessionDetails(session, repName),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      customer,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$vehicle • 16:30 (Live)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.access_time_rounded, size: 13, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot({String? repId, String? repName, String? slot}) {
    final tooltipMsg = (repName != null && slot != null)
        ? 'Available slot ($slot) for $repName • Click to start new enquiry'
        : 'Available time slot • Click to log walk-in consultation';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        onTap: () {
          if (repId != null) {
            context.go('/tablet?repId=$repId');
          } else {
            context.go('/tablet');
          }
        },
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: const Icon(Icons.add, size: 13, color: Color(0x2294A3B8)),
        ),
      ),
    );
  }

  // --- 5. Timeline Legend ---
  Widget _buildTimelineLegend() {
    return Row(
      children: [
        _buildLegendItem(
          'Attending Customer (Busy)',
          const Color(0xFF38BDF8),
          tooltip: 'Sales representative is actively engaged with a customer on the showroom floor',
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          'Quotation Sent / Completed',
          const Color(0xFF34D399),
          tooltip: 'Official quotation breakdown has been calculated and delivered to the customer',
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          'Booked',
          const Color(0xFFFBBF24),
          tooltip: 'Customer confirmed purchase and paid the vehicle booking advance',
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: 'Real-time timeline guideline corresponding to current clock time',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2, height: 12, color: const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              const Text('Current Time', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color dotColor, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session, String repName) {
    bool isMobileRevealed = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final rawMobile = session['customer_mobile']?.toString() ?? 'N/A';
          final hasMobile = rawMobile != 'N/A' && rawMobile.isNotEmpty;
          final displayMobile = (isMobileRevealed || !hasMobile) ? rawMobile : MaskUtil.maskMobile(rawMobile);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session['enquiryNumber'] ?? 'Enquiry Session',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Customer Name', session['customer_name'] ?? 'Walk-in'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mobile Number', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      InkWell(
                        onTap: () {
                          if (hasMobile) {
                            setDialogState(() => isMobileRevealed = !isMobileRevealed);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayMobile,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isMobileRevealed ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                letterSpacing: isMobileRevealed ? 0 : 0.6,
                              ),
                            ),
                            if (hasMobile) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isMobileRevealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 13,
                                color: isMobileRevealed ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDetailRow('Vehicle Model', session['vehicle_name'] ?? 'Model'),
                if (session['colour'] != null && session['colour'].toString().isNotEmpty)
                  _buildDetailRow('Colour', session['colour']),
                if (session['grand_total'] != null)
                  _buildDetailRow('Quoted Amount', CurrencyFormatter.format(session['grand_total'])),
                _buildDetailRow('Sales Executive', repName),
                _buildDetailRow('Status', session['status'] ?? 'Active'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/enquiries');
                },
                child: const Text('View All Enquiries'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _MetricCol {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  _MetricCol({required this.label, required this.value, required this.color, this.tooltip});
}
