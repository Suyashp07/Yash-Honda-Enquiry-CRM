import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/mask_util.dart';
import '../../shared/widgets/app_components.dart';
import '../auth/auth_notifier.dart';

class FloorDashboardScreen extends ConsumerStatefulWidget {
  const FloorDashboardScreen({super.key});

  @override
  ConsumerState<FloorDashboardScreen> createState() =>
      _FloorDashboardScreenState();
}

class _FloorDashboardScreenState extends ConsumerState<FloorDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String _selectedBranch = 'all';

  // Filters & Controls
  String _selectedRepId = 'all';
  DateTime _currentDate = DateTime.now();
  final _searchController = TextEditingController();
  final _timelineScrollController = ScrollController();
  String _searchQuery = '';
  String _viewMode = 'rows'; // 'rows' or 'columns'
  int _zoomLevel = 100;

  // 30-min time slots matching showroom floor operating hours
  final List<String> _timeSlots = [
    '9:00 AM',
    '9:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
    '8:00 PM',
    '8:30 PM',
    '9:00 PM',
    '9:30 PM',
  ];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Auto-refresh every 8 seconds for live showroom floor updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isLoading) {
        _loadDashboardSilently();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _mergeLocalLiveSessions(
      Map<String, dynamic> rawData) async {
    try {
      final storage = ref.read(secureStorageProvider);
      final allKeys = await storage.readAll();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final List<dynamic> localLiveSessions = [];

      for (final entry in allKeys.entries) {
        if (entry.key.startsWith('yash_live_session_')) {
          try {
            final parsed = jsonDecode(entry.value);
            final ts = parsed['timestamp'] as int? ?? 0;
            if (nowMs - ts < 30 * 60 * 1000) {
              localLiveSessions.add(parsed);
            }
          } catch (_) {}
        }
      }

      final reps = List<Map<String, dynamic>>.from((rawData['reps'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e)) ??
          []);
      final sessions = List<Map<String, dynamic>>.from(
          (rawData['sessions'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e)) ??
              []);

      for (final ls in localLiveSessions) {
        final repId = ls['salesExecId']?.toString();
        if (repId == null) continue;

        final repIdx = reps.indexWhere((r) => r['id']?.toString() == repId);
        if (repIdx != -1) {
          reps[repIdx]['status'] = 'Busy';
          reps[repIdx]['activeCustomerName'] = ls['customerName'];
        } else {
          // If rep is not in the list (e.g. branch filter or newly added), append
          reps.add({
            'id': repId,
            'name': ls['salesExecName'] ?? 'Sales Rep',
            'mobile': '',
            'status': 'Busy',
            'activeCustomerName': ls['customerName'],
            'branches': [],
            'enquiriesTodayCount': 1,
          });
        }

        final existingIdx =
            sessions.indexWhere((s) => s['id'] == 'live-$repId');
        final liveBlock = {
          'id': 'live-$repId',
          'enquiryNumber': 'Draft · Live',
          'branchId': ls['branchId'],
          'enquiryType': 'Walk-in',
          'status': 'IN_PROGRESS',
          'sales_exec_id': repId,
          'customer_name': ls['customerName'],
          'customer_mobile': ls['customerMobile'],
          'vehicle_name': ls['vehicleName'],
          'colour': ls['colourName'],
          'grand_total': ls['grandTotal'],
          'created_at': DateTime.now().toIso8601String(),
        };
        if (existingIdx != -1) {
          sessions[existingIdx] = liveBlock;
        } else {
          sessions.insert(0, liveBlock);
        }
      }

      // Sort reps alphabetically matching prototype
      reps.sort((a, b) =>
          (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));

      rawData['reps'] = reps;
      rawData['sessions'] = sessions;
    } catch (_) {}
    return rawData;
  }

  void _scrollToCurrentTimeSlot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timelineScrollController.hasClients) {
        final nowSlot = _getNowSlot();
        final idx = _timeSlots.indexOf(nowSlot);
        if (idx > 1) {
          final cellW = 130.0 * (_zoomLevel / 100.0);
          final targetOffset = (idx - 1) * cellW;
          _timelineScrollController.animateTo(
            math.min(targetOffset,
                _timelineScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _loadDashboardSilently() async {
    try {
      final dio = ref.read(dioProvider);
      final query = <String, dynamic>{};
      final String activeBranch = ref.read(selectedBranchIdProvider);
      if (activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }
      query['date'] = DateFormat('yyyy-MM-dd').format(_currentDate);

      final res = await dio.get('/analytics/floor', queryParameters: query);
      final mergedData =
          await _mergeLocalLiveSessions(Map<String, dynamic>.from(res.data));

      if (!mounted) return;
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _dashboardData = mergedData;
      });
    } catch (_) {
      if (mounted) {
        ref.read(dataFreshnessErrorProvider.notifier).state = true;
      }
    }
  }

  Future<void> _loadDashboard({String? branchId, DateTime? date}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final query = <String, dynamic>{};
      final String activeBranch =
          branchId ?? ref.read(selectedBranchIdProvider);
      if (activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }

      final targetDate = date ?? _currentDate;
      query['date'] = DateFormat('yyyy-MM-dd').format(targetDate);

      final res = await dio.get('/analytics/floor', queryParameters: query);
      final mergedData =
          await _mergeLocalLiveSessions(Map<String, dynamic>.from(res.data));

      if (!mounted) return;
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _currentDate = targetDate;
        _selectedBranch = activeBranch;
        _dashboardData = mergedData;
        _isLoading = false;
      });

      _scrollToCurrentTimeSlot();
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
            onPressed: () =>
                _loadDashboard(branchId: _selectedBranch, date: _currentDate),
          ),
        ),
      );
    }
  }

  String _getNowSlot() {
    final now = DateTime.now();
    int hour = now.hour;
    final minute = now.minute;
    String slotMinute;
    if (minute < 15) {
      slotMinute = '00';
    } else if (minute < 45) {
      slotMinute = '30';
    } else {
      slotMinute = '00';
      hour = (hour + 1) % 24;
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$formattedHour:$slotMinute $period';
  }

  String _getSessionSlot(Map<String, dynamic> session) {
    final rawDate = session['created_at'];
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      int hour = dt.hour;
      final minute = dt.minute;
      String slotMinute;
      if (minute < 15) {
        slotMinute = '00';
      } else if (minute < 45) {
        slotMinute = '30';
      } else {
        slotMinute = '00';
        hour = (hour + 1) % 24;
      }
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$formattedHour:$slotMinute $period';
    } catch (_) {
      return '';
    }
  }

  String _formatSessionTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _findSessionsForSlot(
      List<dynamic> repSessions, String slot) {
    final matches = <Map<String, dynamic>>[];
    for (final s in repSessions) {
      if (s is Map<String, dynamic> && _getSessionSlot(s) == slot) {
        matches.add(s);
      }
    }
    return matches;
  }

  List<Map<String, dynamic>> _collectSlotSessions(
    Map<String, dynamic> rep,
    List<dynamic> repSessions,
    String slot,
    bool isNow,
    bool isBusy,
  ) {
    final list = _findSessionsForSlot(repSessions, slot);
    if (isNow && isBusy) {
      final hasInProgress = list.any((s) =>
          s['status'] == 'ACTIVE' ||
          s['status'] == 'OPEN' ||
          s['status'] == 'IN_PROGRESS');
      if (!hasInProgress) {
        final liveFallback = repSessions.cast<dynamic>().firstWhere(
              (s) =>
                  s is Map<String, dynamic> &&
                  (s['status'] == 'ACTIVE' ||
                      s['status'] == 'OPEN' ||
                      s['status'] == 'IN_PROGRESS'),
              orElse: () => null,
            );
        if (liveFallback is Map<String, dynamic>) {
          if (!list.any((x) => x['id'] == liveFallback['id'])) {
            list.insert(0, liveFallback);
          }
        } else {
          list.insert(0, {
            'id': 'live-${rep["id"]}',
            'customer_name': rep['activeCustomerName'] ?? 'Walk-in Guest',
            'vehicle_name': 'Honda Model',
            'status': 'IN_PROGRESS',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    return list;
  }

  Widget _buildSlotCellContent(
    List<Map<String, dynamic>> slotSessions,
    String repName, {
    required String? repId,
    required String slot,
  }) {
    if (slotSessions.isEmpty) {
      return _buildEmptySlot(repId: repId, repName: repName, slot: slot);
    }
    if (slotSessions.length == 1) {
      return _buildSessionBlock(slotSessions.first, repName);
    }
    final visible = slotSessions.take(2).toList();
    final overflowCount = slotSessions.length - visible.length;
    return Row(
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _buildSessionBlock(visible[i], repName)),
        ],
        if (overflowCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '+$overflowCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) {
        _selectedRepId = 'all';
        _loadDashboard(branchId: next, date: _currentDate);
      }
    });

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFDC2626)),
            SizedBox(height: 12),
            Text('Loading Showroom Floor Timeline...',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
        final matchesRep =
            name.contains(_searchQuery) || phone.contains(_searchQuery);
        final matchesSession = sessions.any((s) =>
            s['sales_exec_id'] == rep['id'] &&
            (((s['customer_name'] as String?)
                        ?.toLowerCase()
                        .contains(_searchQuery) ??
                    false) ||
                ((s['customer_mobile'] as String?)?.contains(_searchQuery) ??
                    false) ||
                ((s['vehicle_name'] as String?)
                        ?.toLowerCase()
                        .contains(_searchQuery) ??
                    false)));
        if (!matchesRep && !matchesSession) return false;
      }
      return true;
    }).toList();

    // NOTE: the page title ("Live floor" / "Updated just now") is intentionally
    // NOT rendered here anymore. It's already rendered once by the parent
    // shell/route header above this screen; rendering it again here caused
    // the duplicated "Live floor" heading seen in the deployed build.
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // 1. Top 4-KPI Row (CURRENT DEALERSHIP, ALL DEALERSHIPS, SALES REPS · LIVE, SESSION OUTCOMES)
            _buildKpiCards(_dashboardData),
            const SizedBox(height: 16),

            // 2. Single Unified White Card Container (wrapping Search, Filters, and Timeline Grid)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Search Box + Date Selector + [Rows]/Columns + Zoom Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: _buildSearchAndControlsBar(),
                  ),

                  // Row 2: Filter Chips Row (All reps · 20 + colored status dots)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFilterChipsRow(reps),
                  ),
                  const SizedBox(height: 14),

                  // Row 3: Mobile Rep Agenda OR Desktop Timeline Grid
                  if (Breakpoints.isPhone(context))
                    _buildMobileRepAgenda(filteredReps, sessions)
                  else
                    _buildTimelineGrid(filteredReps, sessions),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Timeline Legend at Bottom
            if (!Breakpoints.isPhone(context)) _buildTimelineLegend(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRepAgenda(List<dynamic> reps, List<dynamic> sessions) {
    if (reps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.s16),
        child: EmptyState(
          icon: AppIcons.customer,
          title: 'No sales reps match',
          message: 'Try clearing your search or selecting another branch.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today at a glance', style: AppTypography.section),
          const SizedBox(height: AppSpacing.s12),
          ...reps.map((rep) {
            final repId = rep['id']?.toString() ?? '';
            final repName = rep['name']?.toString() ?? 'Sales Rep';
            final status = rep['status']?.toString() ?? 'Available';
            final activeSession = sessions
                .where((s) => s['sales_exec_id']?.toString() == repId)
                .firstOrNull;
            final customerName = activeSession?['customer_name']?.toString() ??
                rep['activeCustomerName']?.toString();
            final vehicleName = activeSession?['vehicle_name']?.toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(repName, style: AppTypography.bodyStrong),
                        ),
                        StatusBadge.rep(status, compact: true),
                      ],
                    ),
                    if (customerName != null && customerName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        vehicleName != null && vehicleName.isNotEmpty
                            ? '$customerName • $vehicleName'
                            : customerName,
                        style: AppTypography.body,
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Available for walk-in or callback',
                        style: AppTypography.caption,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s12),
                    AppButton(
                      label: 'Start session',
                      icon: AppIcons.add,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: () => context.go('/tablet?repId=$repId'),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
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

    final currentTotal =
        current['total'] ?? summary['totalEnquiriesToday'] ?? 0;
    final currentWalkIns = current['walkIns'] ?? summary['walkInsToday'] ?? 0;
    final currentCalls =
        current['callsRecd'] ?? summary['telephonicToday'] ?? 0;

    final consolidatedTotal = consolidated['total'] ?? currentTotal;
    final consolidatedWalkIns = consolidated['walkIns'] ?? currentWalkIns;
    final consolidatedCalls = consolidated['callsRecd'] ?? currentCalls;

    final totalReps = reps.length;
    final busyReps = reps.where((r) => r['status'] == 'Busy').length;
    final idleReps = totalReps - busyReps;

    final inProgress = outcomes['inProgress'] ?? busyReps;
    final quoted = outcomes['quoted'] ?? 0;
    final booked = outcomes['booked'] ?? (summary['bookingsToday'] ?? 0);

    final selectedBranch = ref.watch(selectedBranchIdProvider);
    final isAllBranches = selectedBranch == 'all' || selectedBranch.isEmpty;

    final authUser = ref.watch(authStateProvider).user;
    final isManager = authUser?.isBranchManager == true ||
        authUser?.role.toLowerCase().contains('manager') == true;

    // When "All branches" is selected, "CURRENT DEALERSHIP" makes no sense to show.
    // It should only be shown when a specific dealership is selected.
    final showCurrentDealership = !isAllBranches;

    // "ALL DEALERSHIPS" is shown whenever "All branches" is selected, OR
    // for Super Admin / Owner viewing a specific branch (for comparison).
    final showAllDealerships = isAllBranches ||
        ((authUser?.isSuperAdmin == true || authUser?.isOwner == true) &&
            !isManager);

    return Row(
      children: [
        // Card 1: CURRENT DEALERSHIP (Only shown when a specific branch is selected)
        if (showCurrentDealership) ...[
          Expanded(
            child: _buildMetricCard(
              title: 'CURRENT DEALERSHIP',
              tooltip:
                  'Live inquiries logged today for the actively selected showroom',
              columns: [
                _MetricCol(
                    label: 'Total',
                    value: currentTotal.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Total customer leads recorded today at this branch'),
                _MetricCol(
                    label: 'Walk-ins',
                    value: currentWalkIns.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Physical customer visits to the showroom floor today'),
                _MetricCol(
                    label: 'Calls',
                    value: currentCalls.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Inbound telephonic customer inquiries handled today'),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],

        // Card 2: ALL DEALERSHIPS (Visible on "All branches" or for Super Admin/Owner)
        if (showAllDealerships) ...[
          Expanded(
            child: _buildMetricCard(
              title: 'ALL DEALERSHIPS',
              tooltip:
                  'Aggregated totals across all 6 Yash Honda showrooms in Pune (Phursungi BigWing, Wadki, Saswad, Uruli Kanchan, BT Kawade, Sasane Nagar)',
              columns: [
                _MetricCol(
                    label: 'Total',
                    value: consolidatedTotal.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Consolidated network-wide enquiries received today across Pune'),
                _MetricCol(
                    label: 'Walk-ins',
                    value: consolidatedWalkIns.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Combined walk-in footfalls across all 6 Pune showrooms'),
                _MetricCol(
                    label: 'Calls',
                    value: consolidatedCalls.toString(),
                    color: const Color(0xFF0F172A),
                    tooltip:
                        'Combined inbound telephone inquiries handled network-wide'),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],

        // Card 3: SALES REPS · LIVE
        Expanded(
          child: _buildMetricCard(
            title: 'SALES REPS · LIVE',
            tooltip:
                'Live on-duty sales executive occupancy & availability status',
            columns: [
              _MetricCol(
                  label: 'Total',
                  value: totalReps.toString(),
                  color: const Color(0xFF0F172A),
                  tooltip:
                      'Total sales executives assigned to this showroom floor'),
              _MetricCol(
                  label: 'Busy',
                  value: busyReps.toString(),
                  color: const Color(0xFFDC2626),
                  tooltip:
                      'Sales executives currently attending customers or conducting test rides'),
              _MetricCol(
                  label: 'Idle',
                  value: idleReps.toString(),
                  color: const Color(0xFF16A34A),
                  tooltip:
                      'Sales executives currently idle and available for the next walk-in'),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Card 4: SESSION OUTCOMES
        Expanded(
          child: _buildMetricCard(
            title: 'SESSION OUTCOMES',
            tooltip:
                'Daily sales pipeline progression and conversion status of consultations initiated today',
            columns: [
              _MetricCol(
                  label: 'In progress',
                  value: inProgress.toString(),
                  color: const Color(0xFFDC2626),
                  tooltip:
                      'Customer consultations actively underway right now'),
              _MetricCol(
                  label: 'Quoted',
                  value: quoted.toString(),
                  color: const Color(0xFFD97706),
                  tooltip:
                      'Official quotations calculated and delivered to customers today'),
              _MetricCol(
                  label: 'Booked',
                  value: booked.toString(),
                  color: const Color(0xFF16A34A),
                  tooltip:
                      'Enquiries successfully converted to confirmed bookings with advance token today'),
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
          borderRadius: BorderRadius.circular(12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 0; i < columns.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFFE2E8F0),
                    ),
                  Expanded(
                    child: Tooltip(
                      message: columns[i].tooltip ??
                          '${columns[i].label}: ${columns[i].value}',
                      child: Column(
                        children: [
                          Text(
                            columns[i].value,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: columns[i].color,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            columns[i].label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Search Box + Date Selector + [Rows]/Columns + Zoom Bar matching prototype ---
  Widget _buildSearchAndControlsBar() {
    return Row(
      children: [
        // Search box: single-layer aligned 36px control matching toolbar height
        SizedBox(
          width: 300,
          height: 36,
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              isDense: true,
              constraints: const BoxConstraints(maxHeight: 36),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              hintText: 'Search rep or customer',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF64748B)),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 36),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.brand, width: 1.2),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 15, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        const Spacer(),

        // Date Navigator: <  Sat, 21 Nov, 2026  >
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  size: 20, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 14,
              onPressed: () => _loadDashboard(
                  date: _currentDate.subtract(const Duration(days: 1))),
            ),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _currentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) _loadDashboard(date: picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  DateFormat('EEE, d MMM, yyyy').format(_currentDate),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              splashRadius: 14,
              onPressed: () => _loadDashboard(
                  date: _currentDate.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),

            // Today button
            InkWell(
              onTap: () {
                _loadDashboard(date: DateTime.now());
                _scrollToCurrentTimeSlot();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Today',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),

        // View Mode Switch: Rows vs Columns
        Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _viewMode = 'rows'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _viewMode == 'rows' ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _viewMode == 'rows'
                        ? const [
                            BoxShadow(
                                color: Color(0x0C000000),
                                blurRadius: 2,
                                offset: Offset(0, 1))
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.table_rows_outlined,
                          size: 14,
                          color: _viewMode == 'rows'
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        'Rows',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _viewMode == 'rows'
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _viewMode = 'columns'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _viewMode == 'columns'
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _viewMode == 'columns'
                        ? const [
                            BoxShadow(
                                color: Color(0x0C000000),
                                blurRadius: 2,
                                offset: Offset(0, 1))
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.view_week_outlined,
                          size: 14,
                          color: _viewMode == 'columns'
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        'Columns',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _viewMode == 'columns'
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Zoom Controls: Plus (+) and Minus (-) buttons
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom Out (-) Button (down to 35% to fit full day)
              Tooltip(
                message: 'Zoom out timeline (see full day)',
                child: InkWell(
                  onTap: _zoomLevel > 35
                      ? () => setState(() => _zoomLevel = math.max(35, _zoomLevel - 15))
                      : null,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.zoom_out_rounded,
                      size: 17,
                      color: _zoomLevel > 35
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
              // Fit Day (45%) / Reset (100%) Center Pill
              Tooltip(
                message: _zoomLevel == 100
                    ? 'Fit entire day to screen (45%)'
                    : 'Reset zoom to 100%',
                child: InkWell(
                  onTap: () => setState(() {
                    _zoomLevel = _zoomLevel == 100 ? 45 : 100;
                  }),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 13,
                          color: _zoomLevel != 100
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$_zoomLevel%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _zoomLevel != 100
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
              // Zoom In (+) Button (up to 180% for detailed card view)
              Tooltip(
                message: 'Zoom in timeline (expanded cards)',
                child: InkWell(
                  onTap: _zoomLevel < 180
                      ? () => setState(() => _zoomLevel = math.min(180, _zoomLevel + 15))
                      : null,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.zoom_in_rounded,
                      size: 17,
                      color: _zoomLevel < 180
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. Filter Chips Row (All reps · 20 + Colored status dots) ---
  Widget _buildFilterChipsRow(List<dynamic> reps) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // All Reps Pill
          InkWell(
            onTap: () => setState(() => _selectedRepId = 'all'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedRepId == 'all'
                    ? const Color(0xFF0F172A)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedRepId == 'all'
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                'All reps · ${reps.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _selectedRepId == 'all'
                      ? Colors.white
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Individual Rep Pills with Red/Green status dot
          ...reps.map((rep) {
            final isSel = _selectedRepId == rep['id'];
            final isBusy = rep['status'] == 'Busy';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedRepId = isSel ? 'all' : rep['id']),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFE2E8F0),
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
                          color: isBusy
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
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
            );
          }),
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
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final double cellWidth = 130.0 * (_zoomLevel / 100.0);
    final String currentSlot = _getNowSlot();
    final bool isToday = DateFormat('yyyy-MM-dd').format(_currentDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String? nowSlotTarget =
        isToday && _timeSlots.contains(currentSlot) ? currentSlot : null;

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
    String? nowSlotTarget,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Sales Rep + Time Slots
              Container(
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    // Rep Label Column
                    Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'SALES REP',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5),
                      ),
                    ),

                    // Time Slots
                    ..._timeSlots.map((slot) {
                      final isNow = slot == nowSlotTarget;
                      return Container(
                        width: cellWidth,
                        decoration: BoxDecoration(
                          color: isNow
                              ? const Color(0xFFFFFBEB)
                              : Colors.transparent,
                          border: Border(
                            left: const BorderSide(color: Color(0xFFE2E8F0)),
                            right: isNow
                                ? const BorderSide(
                                    color: Color(0xFFDC2626), width: 2)
                                : BorderSide.none,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slot.replaceAll(' AM', '').replaceAll(' PM', ''),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight:
                                    isNow ? FontWeight.w800 : FontWeight.w500,
                                color: isNow
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            if (isNow) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('NOW',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold)),
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
              final avatarLetter =
                  repName.isNotEmpty ? repName[0].toUpperCase() : 'R';

              // Associated active sessions for this rep
              final repSessions = sessions
                  .where((s) => s['sales_exec_id'] == rep['id'])
                  .toList();
              // Sort newest first
              repSessions.sort((a, b) {
                final at = a['created_at']?.toString() ?? '';
                final bt = b['created_at']?.toString() ?? '';
                return bt.compareTo(at);
              });
              final currentSession =
                  repSessions.isNotEmpty ? repSessions.first : null;
              final customerName = rep['activeCustomerName'] ??
                  currentSession?['customer_name'] ??
                  'Guest';

              return Container(
                height: (72.0 * (_zoomLevel / 100.0)).clamp(46.0, 108.0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Rep Info Tile (Left Pinned) matching prototype
                    Tooltip(
                      message:
                          'Sales Rep: $repName\nStatus: ${isBusy ? 'With $customerName' : 'Available'}\nActive Sessions: ${repSessions.length}',
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: const Color(0xFFF1F5F9),
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
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
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (isBusy)
                                    Text(
                                      'With $customerName',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFDC2626),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Available',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF16A34A),
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
                      final isNow =
                          nowSlotTarget != null && slot == nowSlotTarget;

                      // Collect ALL sessions in this 30-minute slot (completed quotes + active session)
                      final slotSessions = _collectSlotSessions(
                        Map<String, dynamic>.from(rep as Map),
                        repSessions,
                        slot,
                        isNow,
                        isBusy,
                      );

                      return Container(
                        width: cellWidth,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isNow
                              ? const Color(0xFFFFFBEB).withValues(alpha: 0.6)
                              : Colors.white,
                          border: Border(
                            left: const BorderSide(color: Color(0xFFF1F5F9)),
                            right: isNow
                                ? const BorderSide(
                                    color: Color(0xFFDC2626), width: 2)
                                : BorderSide.none,
                          ),
                        ),
                        child: _buildSlotCellContent(
                          slotSessions,
                          repName,
                          repId: rep['id']?.toString(),
                          slot: slot,
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
      ),
    );
  }

  // --- Columns Mode: Reps as Columns (Vertical Time) ---
  Widget _buildColumnsTimelineGrid(
    List<dynamic> reps,
    List<dynamic> sessions,
    String? nowSlotTarget,
  ) {
    final double repColWidth = math.max(95.0, 200.0 * (_zoomLevel / 100.0));
    const double timeColWidth = 110.0;
    final double rowHeight = (68.0 * (_zoomLevel / 100.0)).clamp(44.0, 108.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: SingleChildScrollView(
          controller: _timelineScrollController,
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
                      border:
                          Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: const Text(
                      'Time',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)),
                    ),
                  ),

                  // Sales Rep Column Headers
                  ...reps.map((rep) {
                    final repName = rep['name'] ?? 'Executive';
                    final isBusy = rep['status'] == 'Busy';
                    final avatarLetter =
                        repName.isNotEmpty ? repName[0].toUpperCase() : 'R';

                    final repSessions = sessions
                        .where((s) => s['sales_exec_id'] == rep['id'])
                        .toList();
                    final currentSession =
                        repSessions.isNotEmpty ? repSessions.first : null;
                    final customerName =
                        currentSession?['customer_name'] ?? 'Guest';

                    return Tooltip(
                      message:
                          'Sales Rep: $repName\nStatus: ${isBusy ? 'Attending $customerName' : 'Available (Idle)'}\nActive Sessions: ${repSessions.length}',
                      child: Container(
                        width: repColWidth,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                              right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFF1F5F9),
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569)),
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
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isBusy
                                          ? const Color(0xFFF0FDF4)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isBusy
                                            ? const Color(0xFFBBF7D0)
                                            : const Color(0xFFE2E8F0),
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
                                            color: isBusy
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFF22C55E),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            isBusy
                                                ? 'Busy: $customerName'
                                                : 'Idle',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: isBusy
                                                  ? const Color(0xFF15803D)
                                                  : const Color(0xFF64748B),
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
                        color: isNow
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(
                            color: isNow
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE2E8F0),
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
                              fontWeight:
                                  isNow ? FontWeight.w800 : FontWeight.w600,
                              color: isNow
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          if (isNow) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'NOW',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold),
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
                      final repSessions = sessions
                          .where((s) => s['sales_exec_id'] == rep['id'])
                          .toList();
                      repSessions.sort((a, b) {
                        final at = a['created_at']?.toString() ?? '';
                        final bt = b['created_at']?.toString() ?? '';
                        return bt.compareTo(at);
                      });
                      final slotSessions = _collectSlotSessions(
                        Map<String, dynamic>.from(rep as Map),
                        repSessions,
                        slot,
                        isNow,
                        isBusy,
                      );
                      return Container(
                        width: repColWidth,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isNow
                              ? const Color(0xFFFFFBEB).withValues(alpha: 0.6)
                              : Colors.white,
                          border: const Border(
                            right: BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                        ),
                        child: _buildSlotCellContent(
                          slotSessions,
                          repName,
                          repId: rep['id']?.toString(),
                          slot: slot,
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
      ),
    );
  }

  // --- Session Block matching prototype screenshot ---
  Widget _buildSessionBlock(Map<String, dynamic> session, String repName) {
    final customer = session['customer_name'] ?? 'Guest';
    final vehicle = session['vehicle_name'] ?? 'Honda Model';
    final rawStatus = session['status']?.toString().toUpperCase() ?? '';
    final isBooked = rawStatus == 'CUSTOMER_BOUGHT' || rawStatus == 'BOOKED';
    final isInProgress = !isBooked &&
        (rawStatus == 'IN_PROGRESS' ||
            session['id']?.toString().startsWith('live-') == true);
    final buyingWhen = session['buying_when']?.toString() ?? '';
    final isImmediate =
        !isBooked && buyingWhen.toLowerCase().contains('immediate');

    // 1. Booked: Mint Green (#DEF7EC bg, #10B981 left accent) — Green already used for Booked
    // 2. Buying Immediately (hot lead): Blue (#EFF6FF bg, #2563EB left accent)
    // 3. In progress: Rose/Red (#FDE8E8 bg, #EF4444 left accent)
    // 4. Quoted: Amber (#FEF3C7 bg, #F59E0B left accent)
    final Color bgColor = isBooked
        ? const Color(0xFFDEF7EC)
        : (isImmediate
            ? const Color(0xFFEFF6FF)
            : (isInProgress
                ? const Color(0xFFFDE8E8)
                : const Color(0xFFFEF3C7)));
    final Color accentColor = isBooked
        ? const Color(0xFF10B981)
        : (isImmediate
            ? const Color(0xFF2563EB)
            : (isInProgress
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B)));
    final Color borderColor = isBooked
        ? const Color(0xFFA7F3D0)
        : (isImmediate
            ? const Color(0xFFBFDBFE)
            : (isInProgress
                ? const Color(0xFFFECACA)
                : const Color(0xFFFDE68A)));
    final Color titleColor = isBooked
        ? const Color(0xFF065F46)
        : (isImmediate
            ? const Color(0xFF1E3A8A)
            : (isInProgress
                ? const Color(0xFF991B1B)
                : const Color(0xFF78350F)));
    final Color subColor = isBooked
        ? const Color(0xFF047857)
        : (isImmediate
            ? const Color(0xFF2563EB)
            : (isInProgress
                ? const Color(0xFFDC2626)
                : const Color(0xFF92400E)));

    final String statusLabel = isBooked
        ? 'Booked'
        : (isInProgress
            ? 'In progress'
            : (isImmediate ? 'Quote · Immediate' : 'Quote'));
    final bool showClock = isInProgress ||
        (isBooked && vehicle.toString().toLowerCase().contains('unicorn'));

    return Tooltip(
      message:
          'Customer: $customer\nInterested Model: $vehicle\nShowroom Rep: $repName\nStage: $statusLabel\nTime: ${_formatSessionTime(session["created_at"])}\nClick to inspect details',
      child: InkWell(
        onTap: () => _showSessionDetails(session, repName),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: accentColor, width: 3.5),
              top: BorderSide(color: borderColor, width: 0.5),
              right: BorderSide(color: borderColor, width: 0.5),
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                customer,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 1.5),
              Row(
                children: [
                  if (showClock) ...[
                    Icon(Icons.access_time_rounded, size: 9.5, color: subColor),
                    const SizedBox(width: 3),
                  ],
                  Expanded(
                    child: Text(
                      '$vehicle · $statusLabel',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: subColor,
                        fontWeight: FontWeight.w500,
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

  // Empty slot: stays visually clean/blank by default (matching the prototype)
  // and only reveals the "add" affordance on hover, instead of showing a
  // faint-but-visible plus icon on every empty cell all the time.
  Widget _buildEmptySlot({String? repId, String? repName, String? slot}) {
    final tooltipMsg = (repName != null && slot != null)
        ? 'Available slot ($slot) for $repName • Click to start new enquiry'
        : 'Available time slot • Click to log walk-in consultation';

    return Tooltip(
      message: tooltipMsg,
      child: _HoverRevealAddIcon(
        onTap: () {
          if (repId != null) {
            context.go('/tablet?repId=$repId');
          } else {
            context.go('/tablet');
          }
        },
      ),
    );
  }

  // --- 5. Timeline Legend ---
  Widget _buildTimelineLegend() {
    return Row(
      children: [
        _buildLegendItem(
          'In progress',
          const Color(0xFFDC2626),
          tooltip:
              'Customer consultation or test ride actively underway on showroom floor',
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          'Quoted',
          const Color(0xFFD97706),
          tooltip: 'Official price quotation delivered to customer',
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          'Booked',
          const Color(0xFF16A34A),
          tooltip: 'Vehicle booking confirmed with advance payment',
        ),
        const SizedBox(width: 16),
        _buildLegendItem(
          'Buying Immediately',
          const Color(0xFF2563EB),
          tooltip: 'Hot lead planning immediate purchase (Green is already used for Booked)',
        ),
        const SizedBox(width: 16),
        Tooltip(
          message:
              'Real-time timeline guideline corresponding to current clock time',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 2, height: 12, color: const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              const Text('Current Time',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
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
            style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500),
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
          final displayMobile = (isMobileRevealed || !hasMobile)
              ? rawMobile
              : MaskUtil.maskMobile(rawMobile);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session['enquiryNumber'] ?? 'Enquiry Session',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                    'Customer Name', session['customer_name'] ?? 'Walk-in'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mobile Number',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B))),
                      InkWell(
                        onTap: () {
                          if (hasMobile) {
                            setDialogState(
                                () => isMobileRevealed = !isMobileRevealed);
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
                                color: isMobileRevealed
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF475569),
                                letterSpacing: isMobileRevealed ? 0 : 0.6,
                              ),
                            ),
                            if (hasMobile) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isMobileRevealed
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 13,
                                color: isMobileRevealed
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
                _buildDetailRow(
                    'Vehicle Model', session['vehicle_name'] ?? 'Model'),
                if (session['colour'] != null &&
                    session['colour'].toString().isNotEmpty)
                  _buildDetailRow('Colour', session['colour']),
                if (session['grand_total'] != null)
                  _buildDetailRow('Quoted Amount',
                      CurrencyFormatter.format(session['grand_total'])),
                _buildDetailRow('Sales Executive', repName),
                _buildDetailRow('Status', session['status'] ?? 'Active'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
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
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

/// A small helper widget used by empty timeline cells.
///
/// Instead of always painting a faint-but-visible "+" icon over every empty
/// slot (which reads as visual noise against the prototype's clean blank
/// cells), this only fades the icon in while the pointer is hovering over
/// the cell, and still responds to tap/click everywhere on mobile/touch.
class _HoverRevealAddIcon extends StatefulWidget {
  final VoidCallback onTap;

  const _HoverRevealAddIcon({required this.onTap});

  @override
  State<_HoverRevealAddIcon> createState() => _HoverRevealAddIconState();
}

class _HoverRevealAddIconState extends State<_HoverRevealAddIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: _hovering ? 1.0 : 0.0,
            child: const Icon(
              Icons.add,
              size: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCol {
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  _MetricCol(
      {required this.label,
      required this.value,
      required this.color,
      this.tooltip});
}
