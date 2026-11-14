import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../shared/widgets/master_crud_view.dart';

class MastersScreen extends ConsumerStatefulWidget {
  const MastersScreen({super.key});

  @override
  ConsumerState<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends ConsumerState<MastersScreen> {
  String _activeTab = 'branches';

  @override
  Widget build(BuildContext context) {
    final dio = ref.watch(dioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Sub-navigation tab selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabChip('branches', 'Branches (Pune 6)'),
                  _tabChip('vehicles', 'Vehicles & Pricing'),
                  _tabChip('accessories', 'Add-on Accessories'),
                  _tabChip('financiers', 'Partner Financiers'),
                  _tabChip('areas', 'Locality Areas'),
                  _tabChip('lead-sources', 'Lead Sources'),
                  _tabChip('model-groups', 'Model Groups'),
                  _tabChip('colours', 'Colours Catalog'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Active Master View
          Expanded(child: _buildActiveMaster(dio)),
        ],
      ),
    );
  }

  Widget _tabChip(String key, String label) {
    final isSelected = _activeTab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : AppColors.textPrimary)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceMuted,
        onSelected: (val) {
          if (val) setState(() => _activeTab = key);
        },
      ),
    );
  }

  Widget _buildActiveMaster(dynamic dio) {
    switch (_activeTab) {
      case 'branches':
        return MasterCrudView(
          key: const ValueKey('branches'),
          title: 'Branches Master',
          subtitle: 'Manage all 6 Honda dealership branches in Pune with equal functionality',
          columns: const [
            MasterColumn(key: 'code', label: 'Branch Code', flex: 1),
            MasterColumn(key: 'name', label: 'Branch Name', flex: 3),
            MasterColumn(key: 'address', label: 'Address', flex: 3),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'code', label: 'Branch Code (e.g. RWWKD)'),
            MasterFormField(key: 'name', label: 'Branch Name'),
            MasterFormField(key: 'address', label: 'Branch Address'),
          ],
          fetchItems: () async {
            final res = await dio.get('/branches');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/branches', data: data),
          onUpdate: (id, data) async => await dio.put('/branches/$id', data: data),
          onDelete: (id) async => await dio.delete('/branches/$id'),
        );

      case 'vehicles':
        return MasterCrudView(
          key: const ValueKey('vehicles'),
          title: 'Vehicle Catalog & Pricing',
          subtitle: 'Manage vehicles and manually stored Pune on-road pricing',
          columns: const [
            MasterColumn(key: 'code', label: 'Code', flex: 1),
            MasterColumn(key: 'name', label: 'Model Name', flex: 3),
            MasterColumn(key: 'category', label: 'Category', flex: 1),
            MasterColumn(key: 'exShowroomPrice', label: 'Ex-Showroom', flex: 2, isCurrency: true),
            MasterColumn(key: 'onRoadPrice', label: 'On-Road (Pune)', flex: 2, isCurrency: true),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'code', label: 'Vehicle Code (e.g. ACT6G)'),
            MasterFormField(key: 'name', label: 'Model Name'),
            MasterFormField(key: 'category', label: 'Category (MC | Scooter | BigBike)'),
            MasterFormField(key: 'exShowroomPrice', label: 'Ex-Showroom Price (₹)', type: 'number'),
            MasterFormField(key: 'onRoadPrice', label: 'On-Road Price (Pune ₹)', type: 'number'),
          ],
          fetchItems: () async {
            final res = await dio.get('/vehicles');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/vehicles', data: data),
          onUpdate: (id, data) async => await dio.put('/vehicles/$id', data: data),
          onDelete: (id) async => await dio.delete('/vehicles/$id'),
        );

      case 'accessories':
        return MasterCrudView(
          key: const ValueKey('accessories'),
          title: 'Accessories Master',
          subtitle: 'Add-ons with fixed (FIX) vs sales-rep editable price tags',
          columns: const [
            MasterColumn(key: 'name', label: 'Accessory Name', flex: 3),
            MasterColumn(key: 'defaultPrice', label: 'Default Price', flex: 2, isCurrency: true),
            MasterColumn(key: 'isPriceEditable', label: 'POS Editability', flex: 2, isTag: true),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'name', label: 'Accessory Name'),
            MasterFormField(key: 'defaultPrice', label: 'Default Price (₹)', type: 'number'),
            MasterFormField(key: 'isPriceEditable', label: 'Allow Sales Rep to edit price at POS?', type: 'boolean'),
          ],
          fetchItems: () async {
            final res = await dio.get('/accessories');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/accessories', data: data),
          onUpdate: (id, data) async => await dio.put('/accessories/$id', data: data),
          onDelete: (id) async => await dio.delete('/accessories/$id'),
        );

      case 'financiers':
        return MasterCrudView(
          key: const ValueKey('financiers'),
          title: 'Financier Partners',
          subtitle: 'Approved vehicle loan and finance partners',
          columns: const [
            MasterColumn(key: 'name', label: 'Financier Name', flex: 4),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'name', label: 'Financier Name (e.g. HDFC Bank)'),
          ],
          fetchItems: () async {
            final res = await dio.get('/financiers');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/financiers', data: data),
          onUpdate: (id, data) async => await dio.put('/financiers/$id', data: data),
          onDelete: (id) async => await dio.delete('/financiers/$id'),
        );

      case 'areas':
        return MasterCrudView(
          key: const ValueKey('areas'),
          title: 'Customer Localities & Areas',
          subtitle: 'Pune locality areas for lead demographics and territory mapping',
          columns: const [
            MasterColumn(key: 'name', label: 'Area Name', flex: 4),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'name', label: 'Area Name (e.g. Wakad)'),
          ],
          fetchItems: () async {
            final res = await dio.get('/areas');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/areas', data: data),
          onUpdate: (id, data) async => await dio.put('/areas/$id', data: data),
          onDelete: (id) async => await dio.delete('/areas/$id'),
        );

      case 'lead-sources':
        return MasterCrudView(
          key: const ValueKey('lead-sources'),
          title: 'Lead Origin Sources',
          subtitle: 'Customer enquiry channels (Walk-in, Telephonic, Online)',
          columns: const [
            MasterColumn(key: 'name', label: 'Lead Source', flex: 4),
            MasterColumn(key: 'status', label: 'Status', flex: 1, isStatus: true),
          ],
          formFields: const [
            MasterFormField(key: 'name', label: 'Lead Source Name'),
          ],
          fetchItems: () async {
            final res = await dio.get('/lead-sources');
            return List<Map<String, dynamic>>.from(res.data);
          },
          onCreate: (data) async => await dio.post('/lead-sources', data: data),
          onUpdate: (id, data) async => await dio.put('/lead-sources/$id', data: data),
          onDelete: (id) async => await dio.delete('/lead-sources/$id'),
        );

      default:
        return const Center(child: Text('Select a Master category above'));
    }
  }
}
