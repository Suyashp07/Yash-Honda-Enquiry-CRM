import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/mask_util.dart';
import '../../shared/widgets/app_components.dart';

class FollowUpsScreen extends ConsumerStatefulWidget {
  const FollowUpsScreen({super.key});

  @override
  ConsumerState<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends ConsumerState<FollowUpsScreen> {
  String _scope = 'today';
  List<dynamic> _followUps = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _revealedMobiles = {};

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  Future<void> _loadFollowUps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final activeBranch = ref.read(selectedBranchIdProvider);
      final query = <String, dynamic>{'scope': _scope};
      if (activeBranch.isNotEmpty && activeBranch != 'all') {
        query['branchId'] = activeBranch;
      }
      final res = await dio.get('/follow-ups', queryParameters: query);
      if (!mounted) return;
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _followUps = res.data is List ? res.data as List : [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      ref.read(dataFreshnessErrorProvider.notifier).state = true;
      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load follow-ups. Check your connection and try again.';
      });
    }
  }

  Future<void> _completeFollowUp(String id) async {
    final controller = TextEditingController();
    bool isSubmitting = false;
    String? errorMsg;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => DialogScaffold(
          title: 'Complete Follow-up',
          subtitle: 'Record the call or visit outcome before closing.',
          maxWidth: 440,
          onClose: isSubmitting ? null : () => Navigator.pop(ctx),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.secondary,
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
            ),
            AppButton(
              label: 'Mark Done',
              loading: isSubmitting,
              onPressed: () async {
                final remarks = controller.text.trim();
                if (remarks.isEmpty) {
                  setDialogState(() => errorMsg = 'Please enter outcome remarks.');
                  return;
                }
                setDialogState(() {
                  isSubmitting = true;
                  errorMsg = null;
                });
                try {
                  final dio = ref.read(dioProvider);
                  await dio.patch('/follow-ups/$id/complete', data: {'remarks': remarks});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Follow-up marked completed.'),
                      ),
                    );
                    _loadFollowUps();
                  }
                } catch (e) {
                  setDialogState(() {
                    isSubmitting = false;
                    errorMsg = 'Could not complete follow-up. Please try again.';
                  });
                }
              },
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: controller,
                label: 'Outcome remarks',
                hint: 'e.g. Customer confirmed test ride for Saturday 4 PM',
                maxLines: 3,
                errorText: errorMsg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedBranchIdProvider, (prev, next) {
      if (prev != next) _loadFollowUps();
    });

    final gutter = Breakpoints.gutterFor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Follow-ups',
              subtitle: 'Manage scheduled callbacks and showroom visit commitments',
              actions: [
                AppButton(
                  label: 'Schedule follow-up',
                  icon: AppIcons.add,
                  onPressed: () => context.go('/enquiries'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
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
            ),
            const SizedBox(height: AppSpacing.s16),
            Expanded(
              child: _isLoading
                  ? const LoadingState(rows: 5)
                  : _errorMessage != null
                      ? ErrorState(message: _errorMessage!, onRetry: _loadFollowUps)
                      : _followUps.isEmpty
                          ? EmptyState(
                              icon: AppIcons.followUps,
                              title: 'No $_scope follow-ups due',
                              message:
                                  'Schedule a callback from an enquiry to track next customer actions.',
                              actionLabel: 'Open enquiries',
                              onAction: () => context.go('/enquiries'),
                            )
                          : ListView.separated(
                              itemCount: _followUps.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s12),
                              itemBuilder: (context, index) {
                                final fu = _followUps[index];
                                final enquiry = fu['enquiry'] ?? {};
                                final customer = enquiry['customer'] ?? {};
                                final isCompleted = fu['completedAt'] != null;
                                final fuId = fu['id']?.toString() ?? '';
                                final rawMobile = customer['mobile']?.toString() ?? '';
                                final isRev = _revealedMobiles.contains(fuId);
                                final displayMobile =
                                    isRev ? rawMobile : MaskUtil.maskMobile(rawMobile);
                                final scheduledStr = fu['scheduledAt'] != null
                                    ? DateFormatter.formatDateTime(fu['scheduledAt'].toString())
                                    : 'Not scheduled';

                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              customer['name']?.toString() ?? 'Customer',
                                              style: AppTypography.bodyStrong,
                                            ),
                                          ),
                                          StatusBadge(
                                            style: isCompleted
                                                ? AppStatus.forEnquiryStatus('BOOKED')
                                                : (_scope == 'overdue'
                                                    ? const StatusStyle(
                                                        label: 'Overdue',
                                                        foreground: AppColors.danger,
                                                        background: AppColors.dangerSoft,
                                                        border: AppColors.dangerBorder,
                                                        icon: AppIcons.warning,
                                                      )
                                                    : AppStatus.forEnquiryStatus('QUOTED')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      Wrap(
                                        spacing: AppSpacing.s16,
                                        runSpacing: AppSpacing.s8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () => setState(() {
                                              if (isRev) {
                                                _revealedMobiles.remove(fuId);
                                              } else {
                                                _revealedMobiles.add(fuId);
                                              }
                                            }),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(AppIcons.call,
                                                    size: 16, color: AppColors.secondary),
                                                const SizedBox(width: 4),
                                                Text(displayMobile, style: AppTypography.body),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  isRev ? AppIcons.hide : AppIcons.view,
                                                  size: 16,
                                                  color: AppColors.secondary,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(AppIcons.followUps,
                                                  size: 16, color: AppColors.secondary),
                                              const SizedBox(width: 4),
                                              Text(scheduledStr, style: AppTypography.caption),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if ((fu['remarks'] ?? '').toString().isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.s8),
                                        Text(
                                          fu['remarks'].toString(),
                                          style: AppTypography.body,
                                        ),
                                      ],
                                      if (!isCompleted) ...[
                                        const SizedBox(height: AppSpacing.s12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            AppButton(
                                              label: 'Complete',
                                              icon: AppIcons.success,
                                              variant: AppButtonVariant.secondary,
                                              onPressed: () => _completeFollowUp(fuId),
                                            ),
                                          ],
                                        ),
                                      ],
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
