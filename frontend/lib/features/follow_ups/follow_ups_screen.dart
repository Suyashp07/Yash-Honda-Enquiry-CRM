import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/mask_util.dart';
import '../../core/providers/branch_provider.dart';

class FollowUpsScreen extends ConsumerStatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  ConsumerState<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends ConsumerState<FollowUpsScreen> {
  String _scope = 'today';
  List<dynamic> _followUps = [];
  bool _isLoading = true;
  final Set<String> _revealedMobiles = {};

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  Future<void> _loadFollowUps() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final activeBranch = ref.read(selectedBranchIdProvider);
      final query = <String, dynamic>{'scope': _scope};
      if (activeBranch.isNotEmpty && activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }
      final res = await dio.get('/follow-ups', queryParameters: query);
      setState(() {
        _followUps = res.data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeFollowUp(String id) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Follow-up'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter outcome remarks...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final dio = ref.read(dioProvider);
              await dio.patch('/follow-ups/$id/complete', data: {'remarks': controller.text.trim()});
              _loadFollowUps();
            },
            child: const Text('Mark Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) {
        _loadFollowUps();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer Follow-ups', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Manage scheduled call-backs and showroom visit commitments', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('Today')),
                    ButtonSegment(value: 'overdue', label: Text('Overdue')),
                    ButtonSegment(value: 'upcoming', label: Text('Upcoming')),
                    ButtonSegment(value: 'completed', label: Text('Completed')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (set) {
                    setState(() => _scope = set.first);
                    _loadFollowUps();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _followUps.isEmpty
                      ? Center(child: Text('No $_scope follow-ups found.', style: const TextStyle(color: AppColors.textMuted)))
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: _followUps.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final fu = _followUps[index];
                              final enquiry = fu['enquiry'] ?? {};
                              final customer = enquiry['customer'] ?? {};
                              final isCompleted = fu['completedAt'] != null;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(customer['name'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Builder(
                                            builder: (context) {
                                              final rawMobile = customer['mobile']?.toString() ?? '';
                                              final fuId = fu['id']?.toString() ?? '';
                                              final isRev = _revealedMobiles.contains(fuId);
                                              final displayMobile = isRev ? rawMobile : MaskUtil.maskMobile(rawMobile);
                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (isRev) {
                                                      _revealedMobiles.remove(fuId);
                                                    } else {
                                                      _revealedMobiles.add(fuId);
                                                    }
                                                  });
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(displayMobile, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      isRev ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                                      size: 12,
                                                      color: isRev ? const Color(0xFFDC2626) : Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(fu['remarks'] ?? 'No remarks', style: const TextStyle(fontSize: 13)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormatter.formatDateTime(fu['scheduledAt']),
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    if (!isCompleted)
                                      ElevatedButton(
                                        onPressed: () => _completeFollowUp(fu['id']),
                                        child: const Text('Complete'),
                                      )
                                    else
                                      const Chip(
                                        label: Text('Done', style: TextStyle(fontSize: 11, color: AppColors.statusBought)),
                                        backgroundColor: Color(0xFFDCFCE7),
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

