import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_card.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? comparison;
  final bool? isPositiveTrend;
  final IconData? icon;
  final Color? accentColor;
  final String? tooltip;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.comparison,
    this.isPositiveTrend,
    this.icon,
    this.accentColor,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isPhone(context);
    final accent = accentColor ?? AppColors.brand;

    final card = AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(isMobile ? AppSpacing.s12 : AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(color: AppColors.secondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            value,
            style: isMobile ? AppTypography.metricMobile : AppTypography.metric,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (comparison != null && comparison!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              comparison!,
              style: AppTypography.caption.copyWith(
                color: isPositiveTrend == null
                    ? AppColors.secondary
                    : (isPositiveTrend! ? AppColors.success : AppColors.danger),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: card);
    }
    return card;
  }
}
