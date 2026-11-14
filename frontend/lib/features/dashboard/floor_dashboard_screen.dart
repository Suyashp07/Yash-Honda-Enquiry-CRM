import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../shared/widgets/ai_summary/ai_summary_card.dart';

class FloorDashboardScreen extends ConsumerStatefulWidget {
  const FloorDashboardScreen({super.key});

  @override
  ConsumerState<FloorDashboardScreen> createState() => _FloorDashboardScreenState();
}

class _FloorDashboardScreenState extends ConsumerState<FloorDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String _selectedBranch = 'all';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final query = _selectedBranch == 'all' ? null : {'branchId': _selectedBranch};
      final res = await dio.get('/analytics/floor', queryParameters: query);

      setState(() {
        _dashboardData = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Floor Dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _dashboardData?['summary'] ?? {};
    final reps = (_dashboardData?['reps'] as List?) ?? [];
    final branches = (_dashboardData?['branches'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floor Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Live showroom sales rep workload and today\'s customer floor traffic',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedBranch,
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All 6 Branches (Pune)')),
                          ...branches.map((b) => DropdownMenuItem(
                                value: b['id'].toString(),
                                child: Text('${b['code']} - ${b['name']}'),
                              )),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBranch = val);
                            _loadDashboard();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadDashboard,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // AI-Powered Executive Summary Card (Client-Requested Feature)
            AiSummaryCard(
              branchCode: _selectedBranch,
              range: 'today',
            ),

            // Top KPI Quick Counters
            Row(
              children: [
                _buildKpiCard('TOTAL ENQUIRIES', summary['totalEnquiriesToday']?.toString() ?? '0', Icons.assignment_outlined, AppColors.primary),
                const SizedBox(width: 14),
                _buildKpiCard('WALK-INS TODAY', summary['walkInsToday']?.toString() ?? '0', Icons.directions_walk_outlined, const Color(0xFF2563EB)),
                const SizedBox(width: 14),
                _buildKpiCard('TELEPHONIC LEADS', summary['telephonicToday']?.toString() ?? '0', Icons.call_outlined, const Color(0xFF0D9488)),
                const SizedBox(width: 14),
                _buildKpiCard('BOOKINGS TODAY', summary['bookingsToday']?.toString() ?? '0', Icons.check_circle_outline, AppColors.statusBought),
                const SizedBox(width: 14),
                _buildKpiCard('ACTIVE SALES REPS', summary['activeRepsCount']?.toString() ?? '0', Icons.people_outline, const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 24),

            // Live Sales Rep Status Board (RIGID specification)
            const Text(
              'Showroom Floor Status Board (Live Rep Activity)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            Card(
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reps.isEmpty ? 1 : reps.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      color: AppColors.surfaceMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('SALES EXECUTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Text('BRANCHES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Text('TODAY ENQUIRIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          Expanded(flex: 2, child: Text('FLOOR STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                        ],
                      ),
                    );
                  }

                  if (reps.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No sales executives active on floor for this branch.', style: TextStyle(color: AppColors.textMuted))),
                    );
                  }

                  final rep = reps[index - 1];
                  final isBusy = rep['status'] == 'Busy';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isBusy ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                                child: Text(
                                  rep['name']?[0] ?? 'R',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isBusy ? AppColors.repBusy : AppColors.repIdle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rep['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(rep['mobile'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            (rep['branches'] as List?)?.join(', ') ?? '-',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${rep['enquiriesTodayCount'] ?? 0} serviced',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBusy ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isBusy ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
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
                                      color: isBusy ? AppColors.repBusy : AppColors.repIdle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    rep['status'] ?? 'Idle',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isBusy ? AppColors.repBusy : AppColors.repIdle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
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
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
