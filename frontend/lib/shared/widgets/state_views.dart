import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'app_button.dart';
import 'app_card.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon = AppIcons.info,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Icon(icon, size: 24, color: AppColors.secondary),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(title, style: AppTypography.section, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.s8),
              Text(
                message,
                style: AppTypography.body.copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.s16),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    super.key,
    this.title = 'Could not load data',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AppCard(
          backgroundColor: AppColors.dangerSoft,
          borderColor: AppColors.dangerBorder,
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.error, size: 32, color: AppColors.danger),
              const SizedBox(height: AppSpacing.s12),
              Text(
                title,
                style: AppTypography.section.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                message,
                style: AppTypography.body.copyWith(color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.s16),
                AppButton(
                  label: retryLabel,
                  icon: AppIcons.refresh,
                  onPressed: onRetry,
                  variant: AppButtonVariant.danger,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class UnauthorizedState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const UnauthorizedState({
    super.key,
    this.title = 'You do not have permission',
    this.message = 'Your current role does not have access to this section.',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.lock, size: 32, color: AppColors.warning),
              const SizedBox(height: AppSpacing.s12),
              Text(title, style: AppTypography.section, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.s8),
              Text(
                message,
                style: AppTypography.body.copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.s16),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  final int rows;
  final String? label;

  const LoadingState({super.key, this.rows = 4, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.s8),
        ],
        ...List.generate(
          rows,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
