import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/breakpoints.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/providers/branch_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_components.dart';

class VehiclePickerScreen extends ConsumerStatefulWidget {
  const VehiclePickerScreen({super.key});

  @override
  ConsumerState<VehiclePickerScreen> createState() => _VehiclePickerScreenState();
}

class _VehiclePickerScreenState extends ConsumerState<VehiclePickerScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<dynamic> _vehicles = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final reqId = ++_requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final query = _selectedCategory == 'All' ? null : {'category': _selectedCategory};
      final res = await dio.get('/vehicles', queryParameters: query);

      if (!mounted || reqId != _requestId) return;
      ref.read(lastDataUpdatedProvider.notifier).state = DateTime.now();
      ref.read(dataFreshnessErrorProvider.notifier).state = false;
      setState(() {
        _vehicles = res.data is List ? res.data as List : [];
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || reqId != _requestId) return;
      ref.read(dataFreshnessErrorProvider.notifier).state = true;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load vehicles. Check your connection and try again.';
      });
    }
  }

  List<dynamic> get _filteredVehicles {
    if (_searchQuery.trim().isEmpty) return _vehicles;
    final q = _searchQuery.trim().toLowerCase();
    return _vehicles.where((v) {
      final name = (v['name'] ?? '').toString().toLowerCase();
      final code = (v['code'] ?? '').toString().toLowerCase();
      final group = (v['modelGroup']?['name'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || group.contains(q);
    }).toList();
  }

  String? _resolveImageUrl(Map<String, dynamic> v) {
    final raw = v['listingImageUrl']?.toString() ?? v['detailImageUrl']?.toString();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${ApiConstants.baseUrl.replaceFirst('/api', '')}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final gutter = Breakpoints.gutterFor(context);
    final filtered = _filteredVehicles;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Select vehicle',
              subtitle: 'Choose a model to start an enquiry and live quotation',
              actions: [
                AppButton(
                  label: 'View all enquiries',
                  icon: AppIcons.enquiries,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/enquiries'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            FilterBar(
              resultCount: _isLoading ? null : filtered.length,
              resultLabel: 'models',
              hasActiveFilters: _selectedCategory != 'All' || _searchQuery.isNotEmpty,
              onClearAll: () {
                setState(() {
                  _selectedCategory = 'All';
                  _searchQuery = '';
                });
                _loadVehicles();
              },
              filters: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search model or code...',
                      prefixIcon: Icon(AppIcons.search, size: 20),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                ...['All', 'Scooter', 'MC', 'BigBike'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat == 'MC' ? 'Motorcycles' : cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedCategory = cat);
                        _loadVehicles();
                      }
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Expanded(
              child: _isLoading
                  ? const LoadingState(rows: 4)
                  : _errorMessage != null
                      ? ErrorState(message: _errorMessage!, onRetry: _loadVehicles)
                      : filtered.isEmpty
                          ? EmptyState(
                              icon: AppIcons.vehicle,
                              title: 'No vehicles match',
                              message: 'Try clearing your search or selecting another category.',
                              actionLabel: 'Show all vehicles',
                              onAction: () {
                                setState(() {
                                  _selectedCategory = 'All';
                                  _searchQuery = '';
                                });
                                _loadVehicles();
                              },
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 340,
                                crossAxisSpacing: AppSpacing.s16,
                                mainAxisSpacing: AppSpacing.s16,
                                mainAxisExtent: 320,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final v = Map<String, dynamic>.from(filtered[index]);
                                final colours = (v['colours'] as List?) ?? [];
                                final modelGroup = v['modelGroup']?['name']?.toString() ?? '';
                                final imgUrl = _resolveImageUrl(v);

                                return AppCard(
                                  onTap: () => context.go(
                                    '/enquiries/customize',
                                    extra: {'vehicle': v},
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (modelGroup.isNotEmpty)
                                            StatusBadge(
                                              compact: true,
                                              showIcon: false,
                                              style: StatusStyle(
                                                label: modelGroup,
                                                foreground: AppColors.brand,
                                                background: AppColors.brandSoft,
                                                border: AppColors.brandBorder,
                                                icon: AppIcons.vehicle,
                                              ),
                                            ),
                                          Text(
                                            v['code']?.toString() ?? '',
                                            style: AppTypography.caption,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      Expanded(
                                        child: Center(
                                          child: imgUrl != null
                                              ? Image.network(
                                                  imgUrl,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => const Icon(
                                                    AppIcons.vehicle,
                                                    size: 48,
                                                    color: AppColors.secondary,
                                                  ),
                                                )
                                              : const Icon(
                                                  AppIcons.vehicle,
                                                  size: 48,
                                                  color: AppColors.secondary,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      Text(
                                        v['name']?.toString() ?? 'Honda Vehicle',
                                        style: AppTypography.section,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: AppSpacing.s4),
                                      Text(
                                        'Ex-showroom: ${CurrencyFormatter.format(v['exShowroomPrice'])}',
                                        style: AppTypography.caption,
                                      ),
                                      Text(
                                        'On-road: ${CurrencyFormatter.format(v['onRoadPrice'])}',
                                        style: AppTypography.bodyStrong.copyWith(
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${colours.length} colours',
                                              style: AppTypography.caption,
                                            ),
                                          ),
                                          const Text(
                                            'Select vehicle',
                                            style: TextStyle(
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward,
                                              size: 16, color: AppColors.brand),
                                        ],
                                      ),
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
