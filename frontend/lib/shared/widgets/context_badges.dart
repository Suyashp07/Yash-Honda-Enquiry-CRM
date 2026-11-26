import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class BranchContextChip extends StatelessWidget {
  final String branchName;
  final String? periodLabel;
  final VoidCallback? onTap;

  const BranchContextChip({
    super.key,
    required this.branchName,
    this.periodLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = periodLabel != null ? '$branchName • $periodLabel' : branchName;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.branch, size: 16, color: AppColors.brand),
          const SizedBox(width: AppSpacing.s4),
          Flexible(
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: content,
      );
    }
    return content;
  }
}

enum FreshnessStatus { live, updating, stale, error }

class FreshnessBadge extends StatelessWidget {
  final DateTime? lastUpdatedAt;
  final bool isUpdating;
  final bool hasError;
  final VoidCallback? onRefresh;

  const FreshnessBadge({
    super.key,
    required this.lastUpdatedAt,
    this.isUpdating = false,
    this.hasError = false,
    this.onRefresh,
  });

  FreshnessStatus get _status {
    if (hasError) return FreshnessStatus.error;
    if (isUpdating) return FreshnessStatus.updating;
    if (lastUpdatedAt == null) return FreshnessStatus.stale;
    final age = DateTime.now().difference(lastUpdatedAt!);
    if (age.inMinutes >= 2) return FreshnessStatus.stale;
    return FreshnessStatus.live;
  }

  String _label() {
    switch (_status) {
      case FreshnessStatus.error:
        return 'Could not refresh';
      case FreshnessStatus.updating:
        return 'Updating...';
      case FreshnessStatus.stale:
        if (lastUpdatedAt == null) return 'Syncing...';
        final mins = DateTime.now().difference(lastUpdatedAt!).inMinutes;
        return 'Stale (${mins}m ago)';
      case FreshnessStatus.live:
        final secs = DateTime.now().difference(lastUpdatedAt!).inSeconds;
        if (secs < 10) return 'Live • just now';
        if (secs < 60) return 'Live • ${secs}s ago';
        return 'Updated ${DateTime.now().difference(lastUpdatedAt!).inMinutes}m ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final Color fg;
    final Color bg;
    final Color border;
    switch (status) {
      case FreshnessStatus.error:
        fg = AppColors.danger;
        bg = AppColors.dangerSoft;
        border = AppColors.dangerBorder;
        break;
      case FreshnessStatus.stale:
        fg = AppColors.warning;
        bg = AppColors.warningSoft;
        border = AppColors.warningBorder;
        break;
      case FreshnessStatus.updating:
        fg = AppColors.info;
        bg = AppColors.infoSoft;
        border = AppColors.infoBorder;
        break;
      case FreshnessStatus.live:
        fg = AppColors.success;
        bg = AppColors.successSoft;
        border = AppColors.successBorder;
        break;
    }

    return InkWell(
      onTap: onRefresh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              _label(),
              style: AppTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
