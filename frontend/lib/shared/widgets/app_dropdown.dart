import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? errorText;
  final String? disabledReason;
  final bool searchable;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.disabledReason,
    this.searchable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;
    final selected = items.where((i) => i.value == value).firstOrNull;
    final useSheet = Breakpoints.isPhone(context) || (searchable && items.length > 6);

    Widget field;
    if (useSheet) {
      field = InkWell(
        onTap: isDisabled ? null : () => _openSelectionSheet(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: hint ?? 'Select $label',
            errorText: errorText,
            enabled: !isDisabled,
            suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20),
          ),
          child: Text(
            selected?.label ?? hint ?? 'Select $label',
            style: AppTypography.body.copyWith(
              fontSize: Breakpoints.isPhone(context) ? 16 : 14,
              color: selected != null ? AppColors.ink : AppColors.secondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    } else {
      field = DropdownButtonFormField<T>(
        value: selected?.value,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: hint ?? 'Select $label',
          errorText: errorText,
          enabled: !isDisabled,
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item.value,
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      );
    }

    final wrapped = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.s4),
        field,
      ],
    );

    if (isDisabled && disabledReason != null && disabledReason!.isNotEmpty) {
      return Tooltip(message: disabledReason!, child: wrapped);
    }
    return wrapped;
  }

  Future<void> _openSelectionSheet(BuildContext context) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
      ),
      builder: (ctx) => _SearchableSelectionSheet<T>(
        title: label,
        items: items,
        selectedValue: value,
      ),
    );
    if (result != null && onChanged != null) {
      onChanged!(result);
    }
  }
}

class _SearchableSelectionSheet<T> extends StatefulWidget {
  final String title;
  final List<AppDropdownItem<T>> items;
  final T? selectedValue;

  const _SearchableSelectionSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
  });

  @override
  State<_SearchableSelectionSheet<T>> createState() => _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T> extends State<_SearchableSelectionSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((it) =>
            it.label.toLowerCase().contains(_query.toLowerCase()) ||
            (it.subtitle?.toLowerCase().contains(_query.toLowerCase()) ?? false))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s16,
          right: AppSpacing.s16,
          top: AppSpacing.s16,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppTypography.title)),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(AppIcons.search, size: 20),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.s12),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching options',
                          style: AppTypography.body.copyWith(color: AppColors.secondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final item = filtered[idx];
                          final isSelected = item.value == widget.selectedValue;
                          return ListTile(
                            minVerticalPadding: 12,
                            title: Text(
                              item.label,
                              style: isSelected ? AppTypography.bodyStrong : AppTypography.body,
                            ),
                            subtitle: item.subtitle != null
                                ? Text(item.subtitle!, style: AppTypography.caption)
                                : null,
                            trailing: isSelected
                                ? const Icon(AppIcons.success, color: AppColors.brand)
                                : null,
                            onTap: () => Navigator.of(context).pop(item.value),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
