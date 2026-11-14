import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class MasterColumn {
  final String key;
  final String label;
  final int flex;
  final bool isStatus;
  final bool isCurrency;
  final bool isTag;

  const MasterColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.isStatus = false,
    this.isCurrency = false,
    this.isTag = false,
  });
}

class MasterFormField {
  final String key;
  final String label;
  final String type; // 'text' | 'number' | 'boolean' | 'select'
  final bool required;
  final List<String>? options;
  final dynamic initialValue;

  const MasterFormField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = true,
    this.options,
    this.initialValue,
  });
}

class MasterCrudView extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<MasterColumn> columns;
  final List<MasterFormField> formFields;
  final Future<List<Map<String, dynamic>>> Function() fetchItems;
  final Future<void> Function(Map<String, dynamic> data) onCreate;
  final Future<void> Function(String id, Map<String, dynamic> data) onUpdate;
  final Future<void> Function(String id) onDelete;

  const MasterCrudView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.formFields,
    required this.fetchItems,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<MasterCrudView> createState() => _MasterCrudViewState();
}

class _MasterCrudViewState extends State<MasterCrudView> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.fetchItems();
      setState(() {
        _items = data;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ${widget.title}: $e')),
        );
      }
    }
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredItems = List.from(_items);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredItems = _items.where((it) {
        return it.values.any((val) => val.toString().toLowerCase().contains(q));
      }).toList();
    }
  }

  void _showFormDialog({Map<String, dynamic>? editingItem}) {
    final controllers = <String, TextEditingController>{};
    final boolValues = <String, bool>{};

    for (final field in widget.formFields) {
      if (field.type == 'boolean') {
        boolValues[field.key] = editingItem != null
            ? (editingItem[field.key] == true)
            : (field.initialValue == true);
      } else {
        controllers[field.key] = TextEditingController(
          text: editingItem != null ? editingItem[field.key]?.toString() ?? '' : '',
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            editingItem != null ? 'Edit ${widget.title}' : 'Add New ${widget.title}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.formFields.map((field) {
                  if (field.type == 'boolean') {
                    return SwitchListTile(
                      title: Text(field.label, style: const TextStyle(fontSize: 14)),
                      value: boolValues[field.key] ?? false,
                      onChanged: (val) {
                        setDialogState(() {
                          boolValues[field.key] = val;
                        });
                      },
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controllers[field.key],
                          keyboardType: field.type == 'number' ? TextInputType.number : TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Enter ${field.label.toLowerCase()}',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payload = <String, dynamic>{};
                for (final field in widget.formFields) {
                  if (field.type == 'boolean') {
                    payload[field.key] = boolValues[field.key] ?? false;
                  } else if (field.type == 'number') {
                    payload[field.key] = num.tryParse(controllers[field.key]?.text ?? '') ?? 0;
                  } else {
                    payload[field.key] = controllers[field.key]?.text.trim() ?? '';
                  }
                }

                try {
                  if (editingItem != null) {
                    await widget.onUpdate(editingItem['id'], payload);
                  } else {
                    await widget.onCreate(payload);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving: $e')),
                  );
                }
              },
              child: Text(editingItem != null ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deactivation'),
        content: Text('Are you sure you want to mark "$label" as Inactive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusClosed),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onDelete(id);
              _loadData();
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showFormDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add ${widget.title.replaceAll('Master', '').trim()}'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.title.toLowerCase()}...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applySearch();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Table / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Text(
                          'No ${widget.title.toLowerCase()} found.',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      )
                    : Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          itemCount: _filteredItems.length + 1,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            // Table Header Row
                            if (index == 0) {
                              return Container(
                                color: AppColors.surfaceMuted,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                child: Row(
                                  children: [
                                    ...widget.columns.map((col) => Expanded(
                                          flex: col.flex,
                                          child: Text(
                                            col.label.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        )),
                                    const SizedBox(
                                      width: 100,
                                      child: Text(
                                        'ACTIONS',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final item = _filteredItems[index - 1];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  ...widget.columns.map((col) {
                                    final val = item[col.key];

                                    if (col.isStatus) {
                                      final isAct = val == 'Active';
                                      return Expanded(
                                        flex: col.flex,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isAct ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              val?.toString() ?? 'Active',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isAct ? AppColors.statusBought : AppColors.statusClosed,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    if (col.isTag) {
                                      final isFix = val == false;
                                      return Expanded(
                                        flex: col.flex,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isFix ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isFix ? 'FIX' : 'EDITABLE',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isFix ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    String displayVal = val?.toString() ?? '-';
                                    if (col.isCurrency) {
                                      displayVal = CurrencyFormatter.format(val);
                                    }

                                    return Expanded(
                                      flex: col.flex,
                                      child: Text(
                                        displayVal,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                      ),
                                    );
                                  }),
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                          onPressed: () => _showFormDialog(editingItem: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.statusClosed),
                                          onPressed: () => _confirmDelete(
                                            item['id'],
                                            item['name'] ?? item['code'] ?? 'Item',
                                          ),
                                        ),
                                      ],
                                    ),
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
    );
  }
}
