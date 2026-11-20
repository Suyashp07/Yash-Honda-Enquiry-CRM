import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/currency_formatter.dart';
import '../auth/auth_notifier.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  final String section;

  const AdminPanelScreen({
    super.key,
    required this.section,
  });

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  // For User roles & permissions sub-tab
  String _userSubTab = 'users';

  // Company Profile controllers
  final _compNameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _hypoCtrl = TextEditingController(text: '500');
  bool _applyHypo = true;
  bool _officeHoursEnabled = false;
  final List<Map<String, dynamic>> _officeWindows = [
    {'startTime': '9:00 AM', 'endTime': '1:00 PM', 'enabled': true},
    {'startTime': '2:00 PM', 'endTime': '9:00 PM', 'enabled': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadSectionData();
  }

  @override
  void didUpdateWidget(covariant AdminPanelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _loadSectionData();
    }
  }

  @override
  void dispose() {
    _compNameCtrl.dispose();
    _gstCtrl.dispose();
    _addrCtrl.dispose();
    _termsCtrl.dispose();
    _bankCtrl.dispose();
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _hypoCtrl.dispose();
    super.dispose();
  }

  String get _currentSection =>
      widget.section.isEmpty ? 'vehicles' : widget.section;

  Future<void> _loadSectionData() async {
    if (!mounted) return;
    final user = ref.read(authStateProvider).user;
    if (user == null || !user.canAccessAdminPanel) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (user.isBranchManager &&
        (_currentSection == 'users' || _currentSection == 'company-profile')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);

      if (_currentSection == 'company-profile') {
        final res = await dio.get('/settings');
        final data = res.data as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _compNameCtrl.text = data['companyName'] ?? 'Yash Honda';
          _gstCtrl.text = data['gstNumber'] ?? '24XXXXXXXXXXXZ5';
          _addrCtrl.text = data['address'] ??
              'Suryaloknagri Society Pune Hadapsar Pune 411013';
          _termsCtrl.text = data['quotationTerms'] ??
              'Prices indicative and subject to change. Insurance as applicable. Delivery subject to availability. Exchange value declared by customer and recorded for reference only. E&OE.';
          _bankCtrl.text = data['bankName'] ?? 'HDFC Bank';
          _accCtrl.text = data['accountNumber'] ?? '50200098765432';
          _ifscCtrl.text = data['ifsc'] ?? 'HDFC0001234';
          _upiCtrl.text = data['upiId'] ?? 'yashhonda@hdfcbank';
          _hypoCtrl.text = data['hypothecationCharge']?.toString() ?? '500';
          _applyHypo = data['applyHypothecationDefault'] ?? true;
          _isLoading = false;
        });
        return;
      }

      String endpoint = '';
      switch (_currentSection) {
        case 'vehicles':
          endpoint = '/vehicles';
          break;
        case 'model-groups':
          endpoint = '/vehicles/model-groups';
          break;
        case 'colours':
          endpoint = '/vehicles/colours';
          break;
        case 'accessories':
          endpoint = '/accessories';
          break;
        case 'financiers':
          endpoint = '/financiers';
          break;
        case 'areas':
          endpoint = '/areas';
          break;
        case 'lead-sources':
          endpoint = '/lead-sources';
          break;
        case 'branches':
          endpoint = '/branches';
          break;
        case 'users':
          endpoint = '/users';
          break;
        default:
          endpoint = '/vehicles';
      }

      final res = await dio.get(endpoint);
      final rawList = res.data as List;
      if (!mounted) return;
      setState(() {
        _items = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (e is DioException && e.response?.statusCode == 401) {
        ref.read(authStateProvider.notifier).logout();
        ScaffoldMessenger.of(context).clearSnackBars();
        context.go('/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load ${_getSectionTitle()}: $e')),
      );
    }
  }

  String _getSectionTitle() {
    switch (_currentSection) {
      case 'vehicles':
        return 'Models';
      case 'model-groups':
        return 'Model Groups';
      case 'colours':
        return 'Colours';
      case 'accessories':
        return 'Add-ons';
      case 'financiers':
        return 'Financiers';
      case 'areas':
        return 'Areas';
      case 'lead-sources':
        return 'Sources';
      case 'branches':
        return 'Branches';
      case 'users':
        return 'Users';
      case 'company-profile':
        return 'Company Profile';
      default:
        return 'Admin Panel';
    }
  }

  String _getSectionSubtitle() {
    switch (_currentSection) {
      case 'vehicles':
        return 'Every bike, with its prices and EMI.';
      case 'model-groups':
        return 'Scooter, Motorcycle, BIG WING. Each group can carry its own quotation letterhead.';
      case 'colours':
        return 'The colour list. Availability per model is set on the model.';
      case 'accessories':
        return 'RSA, Helmet, PDI, Ceramic Coating, Extended Warranty. Price can be overridden per model.';
      case 'financiers':
        return 'Finance partners shown when a lead chooses Finance. Open one to set its EMI per model.';
      case 'areas':
        return 'Customer areas for the enquiry form.';
      case 'lead-sources':
        return 'Google, Walk-in, Tele, Social Media, Paper Ad, Referral.';
      case 'branches':
        return 'Each showroom, with its own quote-number prefix.';
      case 'users':
        return 'Staff logins, roles and permissions.';
      case 'company-profile':
        return 'Dealership billing, quotation footer, bank details & working hours.';
      default:
        return '';
    }
  }

  String _getAddButtonText() {
    final user = ref.read(authStateProvider).user;
    if (user?.isSuperAdmin != true) {
      return ''; // Only Super Admin can Add or Modify Masters
    }
    switch (_currentSection) {
      case 'vehicles':
        return 'Add model';
      case 'users':
        return _userSubTab == 'roles' ? '' : 'Add user';
      case 'company-profile':
        return '';
      default:
        return 'Add';
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> item, bool nextVal) async {
    final newStatus = nextVal ? 'Active' : 'Inactive';
    final id = item['id'].toString();

    // Optimistic UI update
    setState(() {
      item['status'] = newStatus;
    });

    try {
      final dio = ref.read(dioProvider);
      switch (_currentSection) {
        case 'vehicles':
          await dio.put('/vehicles/$id', data: {'status': newStatus});
          break;
        case 'model-groups':
          await dio
              .put('/vehicles/model-groups/$id', data: {'status': newStatus});
          break;
        case 'colours':
          await dio.put('/vehicles/colours/$id', data: {'status': newStatus});
          break;
        case 'accessories':
          await dio.put('/accessories/$id', data: {'status': newStatus});
          break;
        case 'financiers':
          await dio.put('/financiers/$id', data: {'status': newStatus});
          break;
        case 'areas':
          await dio.put('/areas/$id', data: {'status': newStatus});
          break;
        case 'lead-sources':
          await dio.put('/lead-sources/$id', data: {'status': newStatus});
          break;
        case 'branches':
          await dio.put('/branches/$id', data: {'status': newStatus});
          break;
        case 'users':
          await dio.put('/users/$id', data: {'status': newStatus});
          break;
      }
    } catch (e) {
      // Revert if failed
      setState(() {
        item['status'] = nextVal ? 'Inactive' : 'Active';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${_getSectionTitle()}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A))),
        content: Text(
            'Are you sure you want to deactivate "${item['name'] ?? item['code'] ?? 'this item'}"?'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dio = ref.read(dioProvider);
      final id = item['id'].toString();
      switch (_currentSection) {
        case 'vehicles':
          await dio.delete('/vehicles/$id');
          break;
        case 'model-groups':
          await dio.delete('/vehicles/model-groups/$id');
          break;
        case 'colours':
          await dio.delete('/vehicles/colours/$id');
          break;
        case 'accessories':
          await dio.delete('/accessories/$id');
          break;
        case 'financiers':
          await dio.delete('/financiers/$id');
          break;
        case 'areas':
          await dio.delete('/areas/$id');
          break;
        case 'lead-sources':
          await dio.delete('/lead-sources/$id');
          break;
        case 'branches':
          await dio.delete('/branches/$id');
          break;
        case 'users':
          await dio.delete('/users/$id');
          break;
      }

      _loadSectionData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as Inactive')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete item: $e')),
        );
      }
    }
  }

  String _getColourCode(Map<String, dynamic> item) {
    if (item['code'] != null && item['code'].toString().isNotEmpty) {
      return item['code'].toString();
    }
    final name = (item['name'] ?? '').toString().trim();
    final lower = name.toLowerCase();
    if (lower.contains('black')) return 'BLK';
    if (lower.contains('blue')) return 'BLU';
    if (lower.contains('grey') || lower.contains('gray')) return 'GRY';
    if (lower.contains('white')) return 'WHT';
    if (lower.contains('red')) return 'RED';
    if (lower.contains('silver')) return 'SLV';
    if (lower.contains('yellow')) return 'YEL';
    if (lower.contains('green')) return 'GRN';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return parts.map((p) => p.isNotEmpty ? p[0] : '').join('').toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 3)).toUpperCase();
  }

  Future<void> _openBrochure(String url) async {
    String fullUrl = url;
    if (url.startsWith('/api')) {
      final base = ApiConstants.baseUrl.replaceAll('/api', '');
      fullUrl = '$base$url';
    }
    final uri = Uri.parse(fullUrl);
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open brochure: $e')),
        );
      }
    }
  }

  void _showBrochureDialog(Map<String, dynamic> vehicle) {
    final vehicleId = vehicle['id'].toString();
    final vehicleName = vehicle['name'] ?? vehicle['code'] ?? 'Vehicle';
    String? currentUrl = vehicle['brochureUrl'];
    final urlCtrl = TextEditingController(text: currentUrl ?? '');
    PlatformFile? pickedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Brochure - $vehicleName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Current brochure status
                  if (currentUrl != null && currentUrl!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Brochure active on this model',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(
                                  currentUrl!,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.open_in_new,
                                size: 14, color: Color(0xFF2563EB)),
                            label: const Text('Open',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF2563EB))),
                            onPressed: () => _openBrochure(currentUrl!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Color(0xFFEF4444)),
                            tooltip: 'Remove brochure',
                            onPressed: () async {
                              final dio = ref.read(dioProvider);
                              await dio.put('/vehicles/$vehicleId',
                                  data: {'brochureUrl': null});
                              setDlgState(() {
                                currentUrl = null;
                                urlCtrl.clear();
                                vehicle['brochureUrl'] = null;
                              });
                              _loadSectionData();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Section 1: Upload PDF File
                  const Text('Option 1: Upload Brochure PDF',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setDlgState(() {
                            pickedFile = result.files.first;
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File selection error: $e')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pickedFile != null
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            pickedFile != null
                                ? Icons.picture_as_pdf_rounded
                                : Icons.cloud_upload_outlined,
                            size: 32,
                            color: pickedFile != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pickedFile != null
                                ? 'Selected: ${pickedFile!.name} (${(pickedFile!.size / 1024).toStringAsFixed(1)} KB)'
                                : 'Click to select Brochure PDF from your device',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: pickedFile != null
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: pickedFile != null
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF475569),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Supported formats: .pdf (Max 30MB)',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (pickedFile != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: isUploading
                            ? null
                            : () async {
                                setDlgState(() => isUploading = true);
                                try {
                                  final dio = ref.read(dioProvider);
                                  final formData = FormData();
                                  if (pickedFile!.bytes != null) {
                                    formData.files.add(MapEntry(
                                      'file',
                                      MultipartFile.fromBytes(
                                          pickedFile!.bytes!,
                                          filename: pickedFile!.name),
                                    ));
                                  } else if (pickedFile!.path != null) {
                                    formData.files.add(MapEntry(
                                      'file',
                                      await MultipartFile.fromFile(
                                          pickedFile!.path!,
                                          filename: pickedFile!.name),
                                    ));
                                  }

                                  await dio.post(
                                      '/vehicles/$vehicleId/brochure',
                                      data: formData);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadSectionData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Brochure PDF uploaded successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  setDlgState(() => isUploading = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Upload failed: $e')),
                                    );
                                  }
                                }
                              },
                        icon: isUploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload, size: 16),
                        label: Text(
                            isUploading
                                ? 'Uploading...'
                                : 'Upload Selected PDF',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('OR',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Online Brochure Link / URL
                  const Text('Option 2: Direct Brochure Web Link',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      hintText: 'https://example.com/honda_activa_brochure.pdf',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDC2626))),
                    ),
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close',
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final link = urlCtrl.text.trim();
                if (link.isEmpty && pickedFile == null) {
                  Navigator.pop(ctx);
                  return;
                }
                if (link.isNotEmpty) {
                  final dio = ref.read(dioProvider);
                  try {
                    await dio.put('/vehicles/$vehicleId',
                        data: {'brochureUrl': link});
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadSectionData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Brochure link saved successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to save brochure link: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save Link',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  String _getAccessoryCode(Map<String, dynamic> item) {
    if (item['code'] != null && item['code'].toString().isNotEmpty) {
      return item['code'].toString();
    }
    final name = (item['name'] ?? '').toString().trim();
    final lower = name.toLowerCase();
    if (lower.contains('ceramic')) return 'CERAMIC';
    if (lower.contains('extended') ||
        lower.contains('warranty') ||
        lower.contains('ew')) return 'EW32';
    if (lower.contains('helmet')) return 'HELMET';
    if (lower.contains('optional') || lower.contains('opt')) return 'OPT_ACC';
    if (lower.contains('pdi')) return 'PDI';
    if (lower.contains('rsa')) return 'RSA';
    if (lower.contains('mat')) return 'FMP';
    if (lower.contains('grip') || lower.contains('lever')) return 'GC&LS';
    if (lower.contains('seat')) return 'DSC';
    if (lower.contains('test')) return 'TEST1';

    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    return clean.substring(0, clean.length.clamp(0, 7));
  }

  void _showAddonDialog({Map<String, dynamic>? editingItem}) {
    final codeCtrl = TextEditingController(
        text: editingItem != null ? _getAccessoryCode(editingItem) : 'OPT_ACC');
    final nameCtrl = TextEditingController(text: editingItem?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: editingItem?['defaultPrice']?.toString() ?? '',
    );
    bool isDefault = editingItem?['isDefault'] == true ||
        editingItem?['isPriceEditable'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: Text(
            editingItem != null ? 'Edit Add-on' : 'Add Add-on',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A)),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code
                const Text('Code',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. CERAMIC, EW32, HELMET',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDC2626))),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Name
                const Text('Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Ceramic Coating',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDC2626))),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Base price (₹)
                const Text('Base price (₹)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1000',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFDC2626))),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Default switch / checkbox
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: isDefault,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF16A34A),
                        onChanged: (val) => setDlgState(() => isDefault = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Include by default on new quotations',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                final p = num.tryParse(priceCtrl.text) ?? 500;
                try {
                  if (editingItem != null) {
                    await dio.put('/accessories/${editingItem['id']}', data: {
                      'name': nameCtrl.text.trim(),
                      'defaultPrice': p,
                      'isPriceEditable': isDefault,
                    });
                  } else {
                    await dio.post('/accessories', data: {
                      'name': nameCtrl.text.trim(),
                      'defaultPrice': p,
                      'isPriceEditable': isDefault,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadSectionData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Add-on ${editingItem != null ? "updated" : "added"} successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save add-on: $e')),
                    );
                  }
                }
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _showColourDialog({Map<String, dynamic>? editingItem}) {
    final codeCtrl = TextEditingController(
        text: editingItem != null ? _getColourCode(editingItem) : 'BLK');
    final nameCtrl = TextEditingController(text: editingItem?['name'] ?? '');
    final hexCtrl =
        TextEditingController(text: editingItem?['hex'] ?? '#111827');

    const suggestedColors = [
      '#FFFFFF', // White
      '#111827', // Black
      '#94A3B8', // Grey
      '#DC2626', // Red
      '#2563EB', // Blue
      '#F59E0B', // Amber
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          title: Text(
            editingItem != null ? 'Edit Colours' : 'Add Colours',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code field
                const Text(
                  'Code',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. BLK',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Name field
                const Text(
                  'Name',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Black',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                  ),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),

                // Hex field
                const Text(
                  'Hex',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _parseColor(hexCtrl.text),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFFCBD5E1), width: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: hexCtrl,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '#111827',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Palette Swatches Row
                Row(
                  children: suggestedColors.map((hexStr) {
                    final isWhite = hexStr == '#FFFFFF';
                    final isCurrent = hexCtrl.text.trim().toUpperCase() ==
                        hexStr.toUpperCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          hexCtrl.text = hexStr;
                          setDlgState(() {});
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _parseColor(hexStr),
                            border: Border.all(
                              color: isWhite
                                  ? const Color(0xFFCBD5E1)
                                  : (isCurrent
                                      ? const Color(0xFF0F172A)
                                      : Colors.transparent),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Helper text
                const Text(
                  'Choose a shade, select a suggested colour, or enter a six-digit hex code.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    fontSize: 13),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                try {
                  if (editingItem != null) {
                    await dio
                        .put('/vehicles/colours/${editingItem['id']}', data: {
                      'name': nameCtrl.text.trim(),
                      'hex': hexCtrl.text.trim(),
                    });
                  } else {
                    await dio.post('/vehicles/colours', data: {
                      'name': nameCtrl.text.trim(),
                      'hex': hexCtrl.text.trim(),
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadSectionData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Colour ${editingItem != null ? "updated" : "added"} successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save colour: $e')),
                    );
                  }
                }
              },
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? editingItem}) {
    if (_currentSection == 'users') {
      _showUserDialog(editingItem: editingItem);
      return;
    }
    if (_currentSection == 'colours') {
      _showColourDialog(editingItem: editingItem);
      return;
    }
    if (_currentSection == 'accessories') {
      _showAddonDialog(editingItem: editingItem);
      return;
    }

    final codeCtrl = TextEditingController(
        text: editingItem?['code'] ?? editingItem?['quotePrefix'] ?? '');
    final nameCtrl = TextEditingController(text: editingItem?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: editingItem?['onRoadPrice']?.toString() ??
          editingItem?['defaultPrice']?.toString() ??
          '',
    );
    final hexCtrl =
        TextEditingController(text: editingItem?['hex'] ?? '#CC0000');
    final letterheadCtrl = TextEditingController(
        text: editingItem?['letterhead'] ?? 'Yash Honda – Red Wing');
    final brochureUrlCtrl =
        TextEditingController(text: editingItem?['brochureUrl'] ?? '');
    final addressCtrl =
        TextEditingController(text: editingItem?['address'] ?? '');
    String vehicleType = editingItem?['category'] ?? 'Motorcycle';
    String branchWing = editingItem?['wing'] ?? 'RedWing';
    bool isPriceEditable = editingItem?['isPriceEditable'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: Text(
            editingItem != null
                ? 'Edit ${_getSectionTitle()}'
                : '${_getAddButtonText()} ${_getSectionTitle()}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A)),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentSection != 'colours' &&
                      _currentSection != 'financiers' &&
                      _currentSection != 'areas' &&
                      _currentSection != 'lead-sources') ...[
                    const Text('Code',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. BWM, ACT6G, RWWKD',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Name',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Enter ${_getSectionTitle().toLowerCase()} name',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_currentSection == 'vehicles') ...[
                    const Text('Vehicle Type / Category',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['MC', 'Scooter', 'BigBike'].contains(vehicleType)
                          ? vehicleType
                          : 'Scooter',
                      items: const [
                        DropdownMenuItem(
                            value: 'Scooter', child: Text('Scooter')),
                        DropdownMenuItem(
                            value: 'MC', child: Text('Motorcycle (MC)')),
                        DropdownMenuItem(
                            value: 'BigBike',
                            child: Text('Big Wing (BigBike)')),
                      ],
                      onChanged: (val) =>
                          setDlgState(() => vehicleType = val ?? 'Scooter'),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('On-road Price (₹ Pune)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 97200',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Brochure PDF URL / Link (Optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: brochureUrlCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. https://.../activa_brochure.pdf',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_currentSection == 'model-groups') ...[
                    const Text('Quotation Letterhead',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: letterheadCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Yash Honda – Big Wing',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Vehicle Type',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['Motorcycle', 'Scooter'].contains(vehicleType)
                          ? vehicleType
                          : 'Motorcycle',
                      items: const [
                        DropdownMenuItem(
                            value: 'Motorcycle', child: Text('Motorcycle')),
                        DropdownMenuItem(
                            value: 'Scooter', child: Text('Scooter')),
                      ],
                      onChanged: (val) =>
                          setDlgState(() => vehicleType = val ?? 'Motorcycle'),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_currentSection == 'colours') ...[
                    const Text('Color Hex Code',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _parseColor(hexCtrl.text),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: hexCtrl,
                            onChanged: (_) => setDlgState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'e.g. #1E3A8A or #CC0000',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_currentSection == 'accessories') ...[
                    const Text('Default Price (₹)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 2500',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: isPriceEditable,
                          activeColor: const Color(0xFFCC0000),
                          onChanged: (val) =>
                              setDlgState(() => isPriceEditable = val ?? false),
                        ),
                        const Text('Editable at Point of Sale by Rep',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                  if (_currentSection == 'branches') ...[
                    const Text('Dealership Wing',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: ['BigWing', 'RedWing'].contains(branchWing)
                          ? branchWing
                          : 'RedWing',
                      items: const [
                        DropdownMenuItem(
                            value: 'BigWing',
                            child: Text('BigWing (Premium / Phursungi)')),
                        DropdownMenuItem(
                            value: 'RedWing',
                            child: Text('RedWing (Commuter / Network)')),
                      ],
                      onChanged: (val) =>
                          setDlgState(() => branchWing = val ?? 'RedWing'),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Showroom Address',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Pune - Saswad Road, Phursungi, Pune',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                      fontSize: 13)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final dio = ref.read(dioProvider);
                try {
                  if (_currentSection == 'vehicles') {
                    final p = num.tryParse(priceCtrl.text) ?? 85000;
                    final bUrl = brochureUrlCtrl.text.trim().isNotEmpty
                        ? brochureUrlCtrl.text.trim()
                        : null;
                    if (editingItem != null) {
                      await dio.put('/vehicles/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                        'category': vehicleType,
                        'onRoadPrice': p,
                        'brochureUrl': bUrl,
                      });
                    } else {
                      // Get a model group id
                      final mgRes = await dio.get('/vehicles/model-groups');
                      final mgId = (mgRes.data as List).first['id'];
                      await dio.post('/vehicles', data: {
                        'code': codeCtrl.text.trim().isEmpty
                            ? 'MOD-${DateTime.now().millisecondsSinceEpoch}'
                            : codeCtrl.text.trim(),
                        'name': nameCtrl.text.trim(),
                        'category': vehicleType,
                        'modelGroupId': mgId,
                        'exShowroomPrice': p * 0.85,
                        'onRoadPrice': p,
                        'brochureUrl': bUrl,
                      });
                    }
                  } else if (_currentSection == 'model-groups') {
                    if (editingItem != null) {
                      await dio.put(
                          '/vehicles/model-groups/${editingItem['id']}',
                          data: {
                            'name': nameCtrl.text.trim(),
                            'quotePrefix': codeCtrl.text.trim(),
                          });
                    } else {
                      await dio.post('/vehicles/model-groups', data: {
                        'name': nameCtrl.text.trim(),
                        'quotePrefix': codeCtrl.text.trim(),
                      });
                    }
                  } else if (_currentSection == 'colours') {
                    if (editingItem != null) {
                      await dio
                          .put('/vehicles/colours/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                        'hex': hexCtrl.text.trim(),
                      });
                    } else {
                      await dio.post('/vehicles/colours', data: {
                        'name': nameCtrl.text.trim(),
                        'hex': hexCtrl.text.trim(),
                      });
                    }
                  } else if (_currentSection == 'accessories') {
                    final p = num.tryParse(priceCtrl.text) ?? 500;
                    if (editingItem != null) {
                      await dio.put('/accessories/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                        'defaultPrice': p,
                        'isPriceEditable': isPriceEditable,
                      });
                    } else {
                      await dio.post('/accessories', data: {
                        'name': nameCtrl.text.trim(),
                        'defaultPrice': p,
                        'isPriceEditable': isPriceEditable,
                      });
                    }
                  } else if (_currentSection == 'financiers') {
                    if (editingItem != null) {
                      await dio.put('/financiers/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    } else {
                      await dio.post('/financiers', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    }
                  } else if (_currentSection == 'areas') {
                    if (editingItem != null) {
                      await dio.put('/areas/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    } else {
                      await dio.post('/areas', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    }
                  } else if (_currentSection == 'lead-sources') {
                    if (editingItem != null) {
                      await dio
                          .put('/lead-sources/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    } else {
                      await dio.post('/lead-sources', data: {
                        'name': nameCtrl.text.trim(),
                      });
                    }
                  } else if (_currentSection == 'branches') {
                    if (editingItem != null) {
                      await dio.put('/branches/${editingItem['id']}', data: {
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim(),
                        'wing': branchWing,
                        'address': addressCtrl.text.trim().isNotEmpty
                            ? addressCtrl.text.trim()
                            : 'Pune, MH',
                      });
                    } else {
                      await dio.post('/branches', data: {
                        'code': codeCtrl.text.trim(),
                        'name': nameCtrl.text.trim(),
                        'wing': branchWing,
                        'address': addressCtrl.text.trim().isNotEmpty
                            ? addressCtrl.text.trim()
                            : 'Pune, MH',
                      });
                    }
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadSectionData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('${_getSectionTitle()} saved successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDialog({Map<String, dynamic>? editingItem}) {
    final nameCtrl = TextEditingController(text: editingItem?['name'] ?? '');
    final mobileCtrl =
        TextEditingController(text: editingItem?['mobile'] ?? '');
    final passCtrl = TextEditingController();
    String role = editingItem?['role'] ?? 'SALES_EXEC';
    List<String> assignedBranchIds = [];
    if (editingItem != null) {
      final userBranches = editingItem['userBranches'] as List? ?? [];
      for (final ub in userBranches) {
        if (ub['branch'] != null && ub['branch']['id'] != null) {
          assignedBranchIds.add(ub['branch']['id'].toString());
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: ref.read(dioProvider).get('/branches'),
        builder: (context, snapshot) {
          final allBranches = (snapshot.data?.data as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          return StatefulBuilder(
            builder: (context, setDlgState) => AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              title: Text(
                editingItem != null ? 'Edit User' : 'Add Staff User',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Full Name',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Rahul Sharma',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Mobile Number (10 digits)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: mobileCtrl,
                        enabled: editingItem ==
                            null, // Mobile is login ID, edit not recommended
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 9888888888',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (editingItem == null) ...[
                        const Text('Initial Password',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Minimum 6 characters',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('Role',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: [
                          'SUPER_ADMIN',
                          'BRANCH_MANAGER',
                          'SALES_EXEC',
                          'ACCOUNTS',
                          'TELE_CALLER'
                        ].contains(role)
                            ? role
                            : 'SALES_EXEC',
                        items: const [
                          DropdownMenuItem(
                              value: 'SUPER_ADMIN', child: Text('Super Admin')),
                          DropdownMenuItem(
                              value: 'BRANCH_MANAGER',
                              child: Text('Branch Manager')),
                          DropdownMenuItem(
                              value: 'SALES_EXEC',
                              child: Text('Sales Executive')),
                          DropdownMenuItem(
                              value: 'ACCOUNTS', child: Text('Accounts')),
                          DropdownMenuItem(
                              value: 'TELE_CALLER', child: Text('Tele-caller')),
                        ],
                        onChanged: (val) =>
                            setDlgState(() => role = val ?? 'SALES_EXEC'),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Assigned Branches',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: allBranches.map((br) {
                          final brId = br['id'].toString();
                          final brName = br['name']?.toString() ?? 'Branch';
                          final isSelected = assignedBranchIds.contains(brId);
                          return FilterChip(
                            label: Text(brName,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87)),
                            selected: isSelected,
                            selectedColor: const Color(0xFFCC0000),
                            checkmarkColor: Colors.white,
                            onSelected: (sel) {
                              setDlgState(() {
                                if (sel) {
                                  assignedBranchIds.add(brId);
                                } else {
                                  assignedBranchIds.remove(brId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        mobileCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter name and mobile')),
                      );
                      return;
                    }
                    if (editingItem == null &&
                        passCtrl.text.trim().length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Password must be at least 6 characters')),
                      );
                      return;
                    }

                    try {
                      final dio = ref.read(dioProvider);
                      if (editingItem != null) {
                        await dio.put('/users/${editingItem['id']}', data: {
                          'name': nameCtrl.text.trim(),
                          'role': role,
                          'branchIds': assignedBranchIds,
                        });
                      } else {
                        await dio.post('/users', data: {
                          'name': nameCtrl.text.trim(),
                          'mobile': mobileCtrl.text.trim(),
                          'password': passCtrl.text.trim(),
                          'role': role,
                          'branchIds': assignedBranchIds,
                        });
                      }

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadSectionData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(editingItem != null
                                  ? 'User updated'
                                  : 'User created successfully')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Save User'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password for ${user['name']}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new password:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Minimum 6 characters',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (passCtrl.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }

              try {
                final dio = ref.read(dioProvider);
                await dio.put('/users/${user['id']}', data: {
                  'password': passCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password reset successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error resetting password: $e')),
                );
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCompanyProfile() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/settings', data: {
        'companyName': _compNameCtrl.text.trim(),
        'gstNumber': _gstCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'quotationTerms': _termsCtrl.text.trim(),
        'bankName': _bankCtrl.text.trim(),
        'accountNumber': _accCtrl.text.trim(),
        'ifsc': _ifscCtrl.text.trim(),
        'upiId': _upiCtrl.text.trim(),
        'hypothecationCharge': num.tryParse(_hypoCtrl.text.trim()) ?? 0,
        'applyHypothecationDefault': _applyHypo,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company Profile saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving company profile: $e')),
        );
      }
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF1E3A8A);
    try {
      final clean = hexString.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF1E3A8A);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;

    // RBAC check: Sales Rep, Tele-caller, Accounts, or unauthenticated users CANNOT view Admin Panel
    if (user == null || !user.canAccessAdminPanel) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 28, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have administrative permissions to view or edit Master Records or dealership settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => context.go('/enquiries'),
                child: const Text('Return to Enquiries',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    // RBAC check: Branch Manager CANNOT access Users or Company Profile
    if (user.isBranchManager &&
        (_currentSection == 'users' || _currentSection == 'company-profile')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 28, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Super Admin Privilege Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only Super Admin can manage staff logins, roles, permissions, and dealership profile settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => context.go('/admin/vehicles'),
                child: const Text('Go to Vehicle Masters',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFCC0000)));
    }

    if (_currentSection == 'company-profile') {
      return _buildCompanyProfileView();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title, Subtitle, and Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSectionTitle(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSectionSubtitle(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_getAddButtonText().isNotEmpty)
                Tooltip(
                  message: 'Create a new record in ${_getSectionTitle()}',
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showAddEditDialog(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _getAddButtonText(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // User Sub-Tabs if on Users screen matching prototype
          if (_currentSection == 'users') ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubTabButton('users', 'Users'),
                  _buildSubTabButton('roles', 'Roles & Permissions'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_currentSection == 'users' && _userSubTab == 'roles')
            _buildRolesAndPermissionsView()
          else
            // Standard Master Data Table matching prototype screenshots
            _buildMasterTable(),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String key, String title) {
    final isSelected = _userSubTab == key;
    final tooltipText = key == 'users'
        ? 'Manage showroom staff credentials, roles and branch allocations'
        : 'Configure granular module-by-module permissions (View, Create, Edit, Delete, Export, Send)';

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        onTap: () {
          setState(() => _userSubTab = key);
          if (key == 'roles' && _rolePermissions.isEmpty) {
            _loadRolePermissions();
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: _getTableHeaders(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Rows
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No ${_getSectionTitle().toLowerCase()} found.',
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: _buildRowCells(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _getTableHeaders() {
    TextStyle headerStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF64748B),
    );

    switch (_currentSection) {
      case 'vehicles':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 3, child: Text('Name', style: headerStyle)),
          Expanded(flex: 2, child: Text('Group', style: headerStyle)),
          Expanded(flex: 2, child: Text('On-road price', style: headerStyle)),
          Expanded(flex: 2, child: Text('Brochure', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'model-groups':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 3, child: Text('Name', style: headerStyle)),
          Expanded(flex: 3, child: Text('Letterhead', style: headerStyle)),
          Expanded(flex: 2, child: Text('Vehicle type', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'colours':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 4, child: Text('Name', style: headerStyle)),
          Expanded(flex: 2, child: Text('Colour', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'accessories':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 4, child: Text('Name', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base price', style: headerStyle)),
          Expanded(flex: 2, child: Text('Default', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'financiers':
      case 'areas':
      case 'lead-sources':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 6, child: Text('Name', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'branches':
        return [
          Expanded(flex: 2, child: Text('Code', style: headerStyle)),
          Expanded(flex: 3, child: Text('Name', style: headerStyle)),
          Expanded(flex: 2, child: Text('Wing', style: headerStyle)),
          Expanded(flex: 4, child: Text('Address', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 100, child: Text('', textAlign: TextAlign.right)),
        ];

      case 'users':
        return [
          Expanded(flex: 3, child: Text('User', style: headerStyle)),
          Expanded(flex: 2, child: Text('Mobile', style: headerStyle)),
          Expanded(flex: 2, child: Text('Role', style: headerStyle)),
          Expanded(flex: 3, child: Text('Branches', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 170, child: Text('', textAlign: TextAlign.right)),
        ];

      default:
        return [
          Expanded(flex: 3, child: Text('Code', style: headerStyle)),
          Expanded(flex: 5, child: Text('Name', style: headerStyle)),
          SizedBox(width: 80, child: Text('Active', style: headerStyle)),
          const SizedBox(
              width: 140, child: Text('', textAlign: TextAlign.right)),
        ];
    }
  }

  List<Widget> _buildRowCells(Map<String, dynamic> item) {
    const textStyle = TextStyle(fontSize: 13, color: Color(0xFF1E293B));
    final isActive = (item['status'] ?? 'Active') == 'Active';
    final user = ref.read(authStateProvider).user;
    final isSuperAdmin = user?.isSuperAdmin == true;

    Widget activeSwitch = SizedBox(
      width: 80,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: isActive
              ? 'Active • Item is enabled across showrooms'
              : 'Inactive • Item is disabled from enquiries and quotations',
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isActive,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF16A34A),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              onChanged: isSuperAdmin ? (val) => _toggleStatus(item, val) : null,
            ),
          ),
        ),
      ),
    );

    Widget actions = isSuperAdmin
        ? SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Color(0xFF64748B)),
                  splashRadius: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit ${item['name'] ?? item['code'] ?? 'item'}',
                  onPressed: () => _showAddEditDialog(editingItem: item),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF94A3B8)),
                  splashRadius: 18,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete ${item['name'] ?? item['code'] ?? 'item'}',
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
          )
        : const SizedBox(width: 100);

    switch (_currentSection) {
      case 'vehicles':
        final code = item['code'] ?? 'Activa';
        final name = item['name'] ?? '';
        final group = item['modelGroup']?['name'] ??
            (item['category'] == 'Scooter' ? 'RW Scooter' : 'Red Wing');
        final price = CurrencyFormatter.format(item['onRoadPrice'] ?? 97200);
        final brochureUrl = item['brochureUrl'] as String?;

        Widget brochureWidget;
        if (brochureUrl != null && brochureUrl.isNotEmpty) {
          brochureWidget = Tooltip(
            message: 'View or update official PDF brochure for $name',
            child: InkWell(
              onTap: () => _openBrochure(brochureUrl),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    const Text('PDF',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626))),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showBrochureDialog(item),
                      child: const Icon(Icons.edit_outlined,
                          size: 12, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          brochureWidget = Tooltip(
            message: 'Attach official PDF brochure for $name',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showBrochureDialog(item),
              icon: const Icon(Icons.add, size: 12, color: Color(0xFF64748B)),
              label: const Text('Brochure',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
            ),
          );
        }

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 3,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(group, style: textStyle)),
          Expanded(
              flex: 2,
              child: Text(price,
                  style: textStyle.copyWith(fontWeight: FontWeight.w600))),
          Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerLeft, child: brochureWidget)),
          activeSwitch,
          actions,
        ];

      case 'model-groups':
        final code = item['quotePrefix'] ?? item['code'] ?? 'BWM';
        final name = item['name'] ?? '';
        final letterhead = 'Yash Honda – $name';
        final vType =
            name.toLowerCase().contains('scooter') ? 'Scooter' : 'Motorcycle';

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 3,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(letterhead, style: textStyle)),
          Expanded(flex: 2, child: Text(vType, style: textStyle)),
          activeSwitch,
          actions,
        ];

      case 'colours':
        final code = _getColourCode(item);
        final name = item['name'] ?? '';
        final hex = (item['hex'] ?? '#111827').toString();
        final colorVal = _parseColor(hex);
        final isWhiteOrLight = hex.toUpperCase() == '#FFFFFF' ||
            hex.toUpperCase() == 'FFFFFF' ||
            hex.toUpperCase() == '#F9FAFB' ||
            hex.toUpperCase() == 'F9FAFB';

        return [
          Expanded(
              flex: 2,
              child: Text(code,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(flex: 4, child: Text(name, style: textStyle)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: 'Shade: $name • Hex: $hex',
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorVal,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isWhiteOrLight
                          ? const Color(0xFFCBD5E1)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          activeSwitch,
          actions,
        ];

      case 'accessories':
        final code = _getAccessoryCode(item);
        final name = item['name'] ?? '';
        final price = CurrencyFormatter.format(item['defaultPrice'] ?? 0);
        final isDefault =
            item['isDefault'] == true || item['isPriceEditable'] == true;
        final defaultStr = isDefault ? 'Yes' : '-';

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 4,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(price, style: textStyle)),
          Expanded(flex: 2, child: Text(defaultStr, style: textStyle)),
          activeSwitch,
          actions,
        ];

      case 'financiers':
      case 'areas':
      case 'lead-sources':
        final code = (item['name'] as String?)
                ?.substring(0, (item['name'] as String).length >= 3 ? 3 : 1)
                .toUpperCase() ??
            'COD';
        final name = item['name'] ?? '';

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 6,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          activeSwitch,
          actions,
        ];

      case 'branches':
        final code = item['code'] ?? '';
        final name = item['name'] ?? '';
        final wing = item['wing'] ??
            (code.toString().startsWith('BW') || name.toString().contains('Big')
                ? 'BigWing'
                : 'RedWing');
        final address = item['address'] ?? '';
        final isBigWing = wing == 'BigWing';

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 3,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBigWing
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: isBigWing
                          ? const Color(0xFF334155)
                          : const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  wing,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBigWing
                        ? const Color(0xFFF8FAFC)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
              flex: 4,
              child: Text(address,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          activeSwitch,
          actions,
        ];

      case 'users':
        final name = item['name'] ?? '';
        final mobile = item['mobile'] ?? '';
        final role = (item['role'] ?? '').toString().replaceAll('_', ' ');
        final userBranches = (item['userBranches'] as List? ?? [])
            .map((ub) => ub['branch']?['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ');

        Widget userActions = SizedBox(
          width: 170,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: () => _showUserDialog(editingItem: item),
                child: const Text('Edit',
                    style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showResetPasswordDialog(item),
                child: const Text('Reset password',
                    style: TextStyle(fontSize: 11, color: Color(0xFFCC0000))),
              ),
            ],
          ),
        );

        return [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style:
                            textStyle.copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(mobile, style: textStyle)),
          Expanded(flex: 2, child: Text(role, style: textStyle)),
          Expanded(
            flex: 3,
            child: Text(
              userBranches.isEmpty ? 'All branches' : userBranches,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          activeSwitch,
          userActions,
        ];

      default:
        return [
          Expanded(flex: 3, child: Text(item['code'] ?? '', style: textStyle)),
          Expanded(flex: 5, child: Text(item['name'] ?? '', style: textStyle)),
          activeSwitch,
          actions,
        ];
    }
  }

  static const List<String> _rbacRoles = [
    'Accounts',
    'Branch Manager',
    'Sales Executive',
    'Super Admin',
    'Tele-caller',
  ];

  static const List<String> _rbacModules = [
    'Leads',
    'Quotes',
    'Follow-ups',
    'Dashboard',
    'Reports',
    'Masters',
    'Users',
  ];

  static const List<String> _rbacActions = [
    'view',
    'create',
    'edit',
    'delete',
    'export',
    'send',
  ];

  Map<String, Map<String, Map<String, bool>>> _rolePermissions = {};
  bool _isLoadingPermissions = false;
  final Set<String> _savingRoles = {};

  Future<void> _loadRolePermissions() async {
    setState(() => _isLoadingPermissions = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/users/permissions');
      if (res.data is Map) {
        final Map<String, dynamic> raw = Map<String, dynamic>.from(res.data);
        final Map<String, Map<String, Map<String, bool>>> parsed = {};
        for (final rEntry in raw.entries) {
          final roleName = rEntry.key;
          parsed[roleName] = {};
          if (rEntry.value is Map) {
            for (final mEntry in (rEntry.value as Map).entries) {
              final moduleName = mEntry.key.toString();
              parsed[roleName]![moduleName] = {};
              if (mEntry.value is Map) {
                for (final aEntry in (mEntry.value as Map).entries) {
                  parsed[roleName]![moduleName]![aEntry.key.toString()] =
                      aEntry.value == true;
                }
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _rolePermissions = parsed;
            _isLoadingPermissions = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _rolePermissions = _getCanonicalDefaultPermissions();
        _isLoadingPermissions = false;
      });
    }
  }

  Future<void> _saveRolePermissions(String roleName) async {
    setState(() => _savingRoles.add(roleName));
    try {
      final dio = ref.read(dioProvider);
      final rolePerms = _rolePermissions[roleName] ?? {};
      await dio.put('/users/permissions/$roleName',
          data: {'permissions': rolePerms});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Permissions for $roleName saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save permissions for $roleName: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingRoles.remove(roleName));
      }
    }
  }

  Map<String, Map<String, Map<String, bool>>>
      _getCanonicalDefaultPermissions() {
    return {
      'Accounts': {
        'Leads': {
          'view': true,
          'create': false,
          'edit': true,
          'delete': false,
          'export': false,
          'send': false
        },
        'Quotes': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Follow-ups': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Dashboard': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Reports': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Masters': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Users': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
      },
      'Branch Manager': {
        'Leads': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': false,
          'send': false
        },
        'Quotes': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': false,
          'export': false,
          'send': true
        },
        'Follow-ups': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': false,
          'send': false
        },
        'Dashboard': {
          'view': true,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Reports': {
          'view': true,
          'create': false,
          'edit': false,
          'delete': false,
          'export': true,
          'send': false
        },
        'Masters': {
          'view': true,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Users': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
      },
      'Sales Executive': {
        'Leads': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': false,
          'export': false,
          'send': false
        },
        'Quotes': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': false,
          'export': false,
          'send': true
        },
        'Follow-ups': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': false,
          'export': false,
          'send': false
        },
        'Dashboard': {
          'view': true,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Reports': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Masters': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Users': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
      },
      'Super Admin': {
        'Leads': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Quotes': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Follow-ups': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Dashboard': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Reports': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Masters': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
        'Users': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': true,
          'export': true,
          'send': true
        },
      },
      'Tele-caller': {
        'Leads': {
          'view': true,
          'create': true,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Quotes': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Follow-ups': {
          'view': true,
          'create': true,
          'edit': true,
          'delete': false,
          'export': false,
          'send': false
        },
        'Dashboard': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Reports': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Masters': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
        'Users': {
          'view': false,
          'create': false,
          'edit': false,
          'delete': false,
          'export': false,
          'send': false
        },
      },
    };
  }

  Widget _buildRolesAndPermissionsView() {
    if (_isLoadingPermissions && _rolePermissions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFFDC2626)),
        ),
      );
    }

    final permissions = _rolePermissions.isEmpty
        ? _getCanonicalDefaultPermissions()
        : _rolePermissions;

    return Column(
      children: _rbacRoles.map((roleName) {
        final rolePerms = permissions[roleName] ?? {};
        final isSaving = _savingRoles.contains(roleName);

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header matching prototype
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  children: [
                    Text(
                      roleName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 11, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text(
                            'System',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () => _saveRolePermissions(roleName),
                      child: isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Header
              Container(
                color: const Color(0xFFFAFAFA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Module',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B)),
                      ),
                    ),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('View',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('Create',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('Edit',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('Delete',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('Export',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                    Expanded(
                        flex: 2,
                        child: Center(
                            child: Text('Send',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Table Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rbacModules.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final module = _rbacModules[idx];
                  final modulePerms = rolePerms[module] ?? {};

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 11),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            module,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B)),
                          ),
                        ),
                        ..._rbacActions.map((act) {
                          final isChecked = modulePerms[act] == true;
                          return Expanded(
                            flex: 2,
                            child: Center(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_rolePermissions.isEmpty) {
                                      _rolePermissions =
                                          _getCanonicalDefaultPermissions();
                                    }
                                    if (_rolePermissions[roleName] == null) {
                                      _rolePermissions[roleName] = {};
                                    }
                                    if (_rolePermissions[roleName]![module] ==
                                        null) {
                                      _rolePermissions[roleName]![module] = {};
                                    }
                                    _rolePermissions[roleName]![module]![act] =
                                        !isChecked;
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? const Color(0xFFDC2626)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isChecked
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Company Profile with 6 distinct cards matching prototype
  Widget _buildCompanyProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Company Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Appears on every quotation PDF and payment footer.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          // 2-Column Responsive Card Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildCard1CompanyDetails(),
                          const SizedBox(height: 20),
                          _buildCard3FinanceDefaults(),
                          const SizedBox(height: 20),
                          _buildCard5OfficeHours(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _buildCard2BankDetails(),
                          const SizedBox(height: 20),
                          _buildCard4Branding(),
                          const SizedBox(height: 20),
                          _buildCard6FailedJobs(),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildCard1CompanyDetails(),
                    const SizedBox(height: 20),
                    _buildCard2BankDetails(),
                    const SizedBox(height: 20),
                    _buildCard3FinanceDefaults(),
                    const SizedBox(height: 20),
                    _buildCard4Branding(),
                    const SizedBox(height: 20),
                    _buildCard5OfficeHours(),
                    const SizedBox(height: 20),
                    _buildCard6FailedJobs(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Bottom right Save button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              onPressed: _saveCompanyProfile,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  InputDecoration _companyProfileInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _buildCardContainer({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? headerTrailing,
    Color? iconColor,
    Color? iconBgColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor ?? const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildCard1CompanyDetails() {
    return _buildCardContainer(
      icon: Icons.store_mall_directory_outlined,
      title: 'Company Details',
      subtitle: 'Name, GST and address on the letterhead.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Company name',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _compNameCtrl,
            decoration: _companyProfileInputDecoration('Yash Honda'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          const Text('GST number',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _gstCtrl,
            decoration: _companyProfileInputDecoration('24XXXXXXXXXXXZ5'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),
          const Text('Address',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _addrCtrl,
            decoration: _companyProfileInputDecoration(
                'Suryaloknagri Society Pune Hadapsar Pune 411013'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard2BankDetails() {
    return _buildCardContainer(
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      subtitle: 'Printed on the quotation for payment.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bank name',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _bankCtrl,
                      decoration: _companyProfileInputDecoration('HDFC Bank'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Account number',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _accCtrl,
                      decoration:
                          _companyProfileInputDecoration('50200098765432'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('IFSC',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ifscCtrl,
                      decoration: _companyProfileInputDecoration('HDFC0001234'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UPI ID',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _upiCtrl,
                      decoration:
                          _companyProfileInputDecoration('yashhonda@hdfcbank'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard3FinanceDefaults() {
    return _buildCardContainer(
      icon: Icons.credit_card_outlined,
      title: 'Finance Defaults',
      subtitle:
          'Auto-fills on a lead the first time Finance is picked - editable per lead after that.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hypothecation charge (Rs)',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155))),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _hypoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _companyProfileInputDecoration('500'),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 14),
              Theme(
                data: ThemeData(unselectedWidgetColor: const Color(0xFFCBD5E1)),
                child: Checkbox(
                  value: _applyHypo,
                  activeColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => setState(() => _applyHypo = val ?? true),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Apply by default on Finance leads',
                  style: TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard4Branding() {
    return _buildCardContainer(
      icon: Icons.image_outlined,
      title: 'Branding',
      subtitle: 'Logo and UPI QR code on the quotation PDF.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Logo',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      height: 38,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('HONDA',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                              fontSize: 9)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_upward_rounded,
                          size: 14, color: Color(0xFF1E293B)),
                      label: const Text('Replace',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {},
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UPI QR code',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.qr_code_2_rounded,
                          size: 24, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_upward_rounded,
                          size: 14, color: Color(0xFF1E293B)),
                      label: const Text('Replace',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {},
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addOfficeHourWindow() {
    final startCtrl = TextEditingController(text: '9:00 AM');
    final endCtrl = TextEditingController(text: '1:00 PM');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Time Window',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                    labelText: 'Start Time (e.g. 9:00 AM)')),
            const SizedBox(height: 12),
            TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                    labelText: 'End Time (e.g. 1:00 PM)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () {
              if (startCtrl.text.isNotEmpty && endCtrl.text.isNotEmpty) {
                setState(() {
                  _officeWindows.add({
                    'startTime': startCtrl.text.trim(),
                    'endTime': endCtrl.text.trim(),
                    'enabled': true,
                  });
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editOfficeHourWindow(int index) {
    final startCtrl =
        TextEditingController(text: _officeWindows[index]['startTime']);
    final endCtrl =
        TextEditingController(text: _officeWindows[index]['endTime']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Time Window',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: startCtrl,
                decoration: const InputDecoration(labelText: 'Start Time')),
            const SizedBox(height: 12),
            TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'End Time')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () {
              if (startCtrl.text.isNotEmpty && endCtrl.text.isNotEmpty) {
                setState(() {
                  _officeWindows[index]['startTime'] = startCtrl.text.trim();
                  _officeWindows[index]['endTime'] = endCtrl.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard5OfficeHours() {
    return _buildCardContainer(
      icon: Icons.access_time_outlined,
      title: 'Office Hours',
      subtitle:
          'Restrict system access to office hours - Super Admin is never blocked.',
      headerTrailing: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: _officeHoursEnabled,
          activeColor: Colors.white,
          activeTrackColor: const Color(0xFF10B981),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFF64748B),
          onChanged: (val) => setState(() => _officeHoursEnabled = val),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._officeWindows.asMap().entries.map((entry) {
            final idx = entry.key;
            final win = entry.value;
            final isEnabled = win['enabled'] as bool;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: isEnabled,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF10B981),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => setState(() => win['enabled'] = val),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${win['startTime']} – ${win['endTime']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () => _editOfficeHourWindow(idx),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () =>
                        setState(() => _officeWindows.removeAt(idx)),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _addOfficeHourWindow,
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                label: const Text(
                  'Add Window',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _saveCompanyProfile,
                child: const Text('Save',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard6FailedJobs() {
    return _buildCardContainer(
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF16A34A),
      iconBgColor: const Color(0xFFDCFCE7),
      title: 'Failed send jobs',
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No failed jobs. Deliveries are healthy.',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
