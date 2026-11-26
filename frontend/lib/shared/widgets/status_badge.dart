import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status.dart';
import '../../core/theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final StatusStyle style;
  final bool showIcon;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.style,
    this.showIcon = true,
    this.compact = false,
  });

  factory StatusBadge.enquiry(String status, {bool compact = false}) =>
      StatusBadge(style: AppStatus.forEnquiryStatus(status), compact: compact);

  factory StatusBadge.rep(String state, {bool compact = false}) =>
      StatusBadge(style: AppStatus.forRepState(state), compact: compact);

  factory StatusBadge.delivery(String status, {bool compact = false}) =>
      StatusBadge(style: AppStatus.forDeliveryStatus(status), compact: compact);

  factory StatusBadge.active(bool isActive, {bool compact = false}) =>
      StatusBadge(style: AppStatus.forActiveFlag(isActive), compact: compact);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${style.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(color: style.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(style.icon, size: AppIcons.sizeInline - 2, color: style.foreground),
              const SizedBox(width: AppSpacing.s4),
            ],
            Text(
              style.label,
              style: AppTypography.label.copyWith(
                color: style.foreground,
                fontSize: compact ? 11 : 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
