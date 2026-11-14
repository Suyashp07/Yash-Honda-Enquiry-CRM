import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/currency_formatter.dart';

class VehiclePickerScreen extends ConsumerStatefulWidget {
  const VehiclePickerScreen({super.key});

  @override
  ConsumerState<VehiclePickerScreen> createState() => _VehiclePickerScreenState();
}

class _VehiclePickerScreenState extends ConsumerState<VehiclePickerScreen> {
  String _selectedCategory = 'All';
  List<dynamic> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final query = _selectedCategory == 'All' ? null : {'category': _selectedCategory};
      final res = await dio.get('/vehicles', queryParameters: query);

      setState(() {
        _vehicles = res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Customer Enquiry — Select Vehicle',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select category and vehicle model to begin enquiry & quotation flow',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/enquiries'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.textPrimary),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('View All Enquiries'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Scooter', 'MC', 'BigBike'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(
                        cat == 'MC' ? 'Motorcycles (MC)' : cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCategory = cat);
                          _loadVehicles();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Vehicle Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _vehicles.isEmpty
                      ? const Center(child: Text('No vehicles found in this category'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _vehicles.length,
                          itemBuilder: (context, index) {
                            final v = _vehicles[index];
                            final colours = (v['colours'] as List?) ?? [];
                            final modelGroup = v['modelGroup']?['name'] ?? '';

                            return InkWell(
                              onTap: () {
                                context.go(
                                  '/enquiries/customize',
                                  extra: {'vehicle': v},
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Badge & Icon
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: modelGroup == 'BigWing'
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFFFE5E5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            modelGroup.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: modelGroup == 'BigWing'
                                                  ? const Color(0xFFB45309)
                                                  : AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.two_wheeler, size: 28, color: AppColors.textSecondary),
                                      ],
                                    ),
                                    const Spacer(),

                                    // Vehicle Name & Code
                                    Text(
                                      v['name'] ?? '',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'Code: ${v['code']} • ${v['category']}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 12),

                                    // Colour dots
                                    Row(
                                      children: colours.take(5).map((vc) {
                                        final hexStr = vc['colour']?['hex'] ?? '#CCCCCC';
                                        final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));
                                        return Container(
                                          margin: const EdgeInsets.only(right: 5),
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black12, width: 1),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 14),

                                    // On-road Price (Pune)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Pune On-Road', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                            Text(
                                              CurrencyFormatter.format(v['onRoadPrice']),
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                        const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.primary),
                                      ],
                                    ),
                                  ],
                                ),
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

