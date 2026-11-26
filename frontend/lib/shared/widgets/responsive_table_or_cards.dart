import 'package:flutter/material.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/theme/app_spacing.dart';

class ResponsiveTableOrCards<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, List<T> items) desktopTableBuilder;
  final Widget Function(BuildContext context, T item) mobileCardBuilder;
  final EdgeInsetsGeometry? padding;

  const ResponsiveTableOrCards({
    super.key,
    required this.items,
    required this.desktopTableBuilder,
    required this.mobileCardBuilder,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = Breakpoints.isPhone(context);
    if (isPhone) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (ctx, idx) => mobileCardBuilder(ctx, items[idx]),
      );
    }
    return desktopTableBuilder(context, items);
  }
}
