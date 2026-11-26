import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_card.dart';

class FilterBar extends StatelessWidget {
  final List<Widget> filters;
  final int? resultCount;
  final String? resultLabel;
  final bool hasActiveFilters;
  final VoidCallback? onClearAll;

  const FilterBar({
    super.key,
    required this.filters,
    this.resultCount,
    this.resultLabel,
    this.hasActiveFilters = false,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          ),
          if (resultCount != null || hasActiveFilters) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                if (resultCount != null)
                  Text(
                    '$resultCount ${resultLabel ?? 'results'}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (hasActiveFilters && onClearAll != null)
                  TextButton.icon(
                    onPressed: onClearAll,
                    icon: const Icon(AppIcons.close, size: 16),
                    label: const Text('Clear all'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
