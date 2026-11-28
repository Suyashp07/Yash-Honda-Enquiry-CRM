import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/api_constants.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../auth/auth_notifier.dart';
import 'widgets/configurator_media_dialogs.dart';

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
  String? _loadError;
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
  String? _logoUrl;
  String? _upiQrUrl;
  bool _isUploadingLogo = false;
  bool _isUploadingUpiQr = false;
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

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

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
          _logoUrl = data['logoUrl']?.toString();
          _upiQrUrl = data['upiQrUrl']?.toString();
          _officeHoursEnabled = data['officeHoursEnabled'] == true;
          if (data['officeWindows'] is List) {
            _officeWindows
              ..clear()
              ..addAll(
                (data['officeWindows'] as List).map<Map<String, dynamic>>((w) => {
                      'startTime': (w['startTime'] ?? '9:00 AM').toString(),
                      'endTime': (w['endTime'] ?? '1:00 PM').toString(),
                      'enabled': w['enabled'] == true,
                    }),
              );
          }
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
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
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
        return 'Accessories';
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
          ref.read(branchesRefreshProvider.notifier).state++;
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
        title: Row(
          children: [
            Expanded(
              child: Text('Delete ${_getSectionTitle()}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A))),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Text(
            'Are you sure you want to permanently delete "${item['name'] ?? item['code'] ?? 'this item'}"?'),
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
          ref.read(branchesRefreshProvider.notifier).state++;
          break;
        case 'users':
          await dio.delete('/users/$id');
          break;
      }

      _loadSectionData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully')),
        );
      }
    } catch (e) {
      String message = 'Failed to delete item';
      if (e is DioException && e.response?.data is Map) {
        final msg = e.response?.data['message'];
        if (msg != null && msg.toString().isNotEmpty) {
          message = msg is List ? msg.join(', ') : msg.toString();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
    bool isPriceEditable = editingItem?['isPriceEditable'] == true;
    bool isStandard = editingItem?['isStandard'] == true;
    String? currentImageUrl = editingItem?['imageUrl']?.toString();
    LocalImageInspectResult? pendingImage;
    String? imageFeedback;
    bool imageIsError = false;
    bool isSaving = false;

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
          title: Row(
            children: [
              Expanded(
                child: Text(
                  editingItem != null ? 'Edit Add-on' : 'Add Add-on',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
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
                  // Code & Name row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Code',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: codeCtrl,
                              decoration: InputDecoration(
                                hintText: 'CERAMIC',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(
                                  fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                hintText: 'e.g. 1250',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                              style: const TextStyle(
                                  fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

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
                      hintText: 'e.g. Engine Guard, Tank Pad, Ceramic Coating',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDC2626))),
                    ),
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 14),

                  // Configurator Inclusion Type (Standard Included vs Optional)
                  const Text('Build My Honda Classification',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isStandard = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: !isStandard
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !isStandard
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Optional Add-on',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: !isStandard
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const Text(
                                  'Customer ticks & adds price',
                                  style: TextStyle(
                                      fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDlgState(() => isStandard = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isStandard
                                  ? const Color(0xFFF0FDF4)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isStandard
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Standard (Included)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isStandard
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const Text(
                                  'Pre-checked & included free',
                                  style: TextStyle(
                                      fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Editable price at POS toggle
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: isPriceEditable,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFFDC2626),
                          onChanged: (val) =>
                              setDlgState(() => isPriceEditable = val),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Sales rep can override amount at POS',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Product Image Upload + Live Preview Box
                  const Text('Product Thumbnail (400×400 px, min 200×200 px)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pendingImage != null &&
                                  pendingImage!.bytes.isNotEmpty
                              ? Image.memory(pendingImage!.bytes,
                                  fit: BoxFit.contain)
                              : SmartMediaImage(
                                  source: currentImageUrl,
                                  fit: BoxFit.contain,
                                  fallback: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 28,
                                      color: Color(0xFF94A3B8)),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onPressed: () async {
                                      final inspect = await pickAndInspectImage(
                                          isAccessory: true);
                                      if (inspect == null) return;
                                      setDlgState(() {
                                        if (inspect.qualityStatus ==
                                            'rejected') {
                                          pendingImage = null;
                                          imageFeedback = inspect.message;
                                          imageIsError = true;
                                        } else {
                                          pendingImage = inspect;
                                          imageFeedback = inspect.message;
                                          imageIsError = false;
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.upload_file_outlined,
                                        size: 15),
                                    label: Text(
                                      (pendingImage != null ||
                                              (currentImageUrl != null &&
                                                  currentImageUrl!.isNotEmpty))
                                          ? 'Replace Photo'
                                          : 'Upload Photo',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (pendingImage != null ||
                                      (currentImageUrl != null &&
                                          currentImageUrl!.isNotEmpty)) ...[
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () {
                                        setDlgState(() {
                                          pendingImage = null;
                                          currentImageUrl = null;
                                          imageFeedback =
                                              'Photo will be cleared on Save.';
                                          imageIsError = false;
                                        });
                                      },
                                      child: const Text('Clear',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFFDC2626))),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                imageFeedback ??
                                    'Clean product photo on light background. Sharp validates & optimizes on save.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: imageIsError
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF64748B),
                                  fontWeight: imageIsError
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
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
              onPressed: isSaving
                  ? null
                  : () async {
                      setDlgState(() => isSaving = true);
                      final dio = ref.read(dioProvider);
                      final p = num.tryParse(priceCtrl.text) ?? 500;
                      try {
                        String savedId;
                        if (editingItem != null) {
                          savedId = editingItem['id'].toString();
                          await dio.put('/accessories/$savedId', data: {
                            'name': nameCtrl.text.trim(),
                            'defaultPrice': p,
                            'isPriceEditable': isPriceEditable,
                            'isStandard': isStandard,
                            if (currentImageUrl == null && pendingImage == null)
                              'imageUrl': null,
                          });
                        } else {
                          final res = await dio.post('/accessories', data: {
                            'name': nameCtrl.text.trim(),
                            'defaultPrice': p,
                            'isPriceEditable': isPriceEditable,
                            'isStandard': isStandard,
                          });
                          savedId = res.data['id'].toString();
                        }

                        if (pendingImage != null &&
                            pendingImage!.bytes.isNotEmpty) {
                          final formData = FormData.fromMap({
                            'file': MultipartFile.fromBytes(
                              pendingImage!.bytes,
                              filename: pendingImage!.filename,
                            ),
                          });
                          await dio.post('/accessories/$savedId/image',
                              data: formData);
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
                        setDlgState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to save add-on: $e')),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
    final codeInputCtrl =
        TextEditingController(text: editingItem?['hex'] ?? '#111827');
    String colorFormat = 'HEX'; // 'HEX' | 'RGB'

    String? normalizeToHex(String raw, String fmt) {
      final s = raw.trim();
      if (fmt == 'HEX') {
        final cleaned = s.replaceAll('#', '');
        if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) return null;
        return '#${cleaned.toUpperCase()}';
      } else {
        final cleaned = s
            .replaceAll(RegExp(r'rgba?\(|\)', caseSensitive: false), '')
            .trim();
        final parts = cleaned
            .split(RegExp(r'[\s,]+'))
            .where((p) => p.isNotEmpty)
            .toList();
        if (parts.length != 3) return null;
        final r = int.tryParse(parts[0]);
        final g = int.tryParse(parts[1]);
        final b = int.tryParse(parts[2]);
        if (r == null ||
            g == null ||
            b == null ||
            r < 0 ||
            r > 255 ||
            g < 0 ||
            g > 255 ||
            b < 0 ||
            b > 255) {
          return null;
        }
        String toHex2(int n) =>
            n.toRadixString(16).padLeft(2, '0').toUpperCase();
        return '#${toHex2(r)}${toHex2(g)}${toHex2(b)}';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final resolvedHex =
              normalizeToHex(codeInputCtrl.text, colorFormat) ?? '#111827';
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    editingItem != null ? 'Edit Colour' : 'Add Standard Colour',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colour Name
                  const Text(
                    'Colour Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Rebel Red Metallic',
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

                  // Format Dropdown (HEX | RGB)
                  const Text(
                    'Colour Code Format',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: colorFormat,
                    items: const [
                      DropdownMenuItem(
                          value: 'HEX', child: Text('HEX (e.g. #DC2626)')),
                      DropdownMenuItem(
                          value: 'RGB', child: Text('RGB (e.g. 220, 38, 38)')),
                    ],
                    onChanged: (val) {
                      if (val == null || val == colorFormat) return;
                      setDlgState(() {
                        if (val == 'RGB') {
                          final hex = normalizeToHex(codeInputCtrl.text, 'HEX');
                          if (hex != null) {
                            final c = _parseColor(hex);
                            codeInputCtrl.text =
                                '${(c.r * 255).round()}, ${(c.g * 255).round()}, ${(c.b * 255).round()}';
                          } else {
                            codeInputCtrl.text = '17, 24, 39';
                          }
                        } else {
                          final hex = normalizeToHex(codeInputCtrl.text, 'RGB');
                          codeInputCtrl.text = hex ?? '#111827';
                        }
                        colorFormat = val;
                      });
                    },
                    decoration: InputDecoration(
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
                  ),
                  const SizedBox(height: 16),

                  // Colour Code + Live Swatch
                  Text(
                    colorFormat == 'HEX'
                        ? 'HEX Colour Code'
                        : 'RGB Colour Code',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeInputCtrl,
                    onChanged: (_) => setDlgState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          colorFormat == 'HEX' ? '#DC2626' : '220, 38, 38',
                      isDense: true,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          width: 28,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _parseColor(resolvedHex),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFFCBD5E1), width: 0.8),
                          ),
                        ),
                      ),
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
                  final cName = nameCtrl.text.trim();
                  final hexVal =
                      normalizeToHex(codeInputCtrl.text, colorFormat);
                  if (cName.isEmpty || hexVal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(cName.isEmpty
                            ? 'Please enter a valid Colour Name.'
                            : colorFormat == 'HEX'
                                ? 'Please enter a valid 6-digit HEX code (e.g. #DC2626).'
                                : 'Please enter valid RGB values between 0 and 255 (e.g. 220, 38, 38).'),
                      ),
                    );
                    return;
                  }
                  final dio = ref.read(dioProvider);
                  try {
                    if (editingItem != null) {
                      await dio
                          .put('/vehicles/colours/${editingItem['id']}', data: {
                        'name': cName,
                        'hex': hexVal,
                      });
                    } else {
                      await dio.post('/vehicles/colours', data: {
                        'name': cName,
                        'hex': hexVal,
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
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          );
        },
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
    final exShowroomCtrl = TextEditingController(
      text: editingItem?['exShowroomPrice']?.toString() ?? '',
    );
    final ccCtrl = TextEditingController(
      text: editingItem?['ccDisplacement']?.toString() ?? '',
    );
    final hexCtrl =
        TextEditingController(text: editingItem?['hex'] ?? '#CC0000');
    final letterheadCtrl = TextEditingController(
        text: editingItem?['letterhead'] ?? 'Yash Honda – Red Wing');
    final brochureUrlCtrl =
        TextEditingController(text: editingItem?['brochureUrl'] ?? '');
    final wordmarkUrlCtrl =
        TextEditingController(text: editingItem?['wordmarkImageUrl'] ?? '');
    PlatformFile? pickedBrochurePdf;
    final addressCtrl =
        TextEditingController(text: editingItem?['address'] ?? '');
    final rawCat = (editingItem?['category'] ?? 'MC').toString();
    String vehicleType = rawCat.toLowerCase().contains('scooter')
        ? 'Scooter'
        : (rawCat.toLowerCase().contains('big') ||
                rawCat.toLowerCase().contains('wing')
            ? 'BigBike'
            : 'MC');
    String branchWing = editingItem?['wing'] ?? 'RedWing';
    bool isPriceEditable = editingItem?['isPriceEditable'] ?? false;
    bool isStandardAcc = editingItem?['isStandard'] ?? false;
    final accImageUrlCtrl =
        TextEditingController(text: editingItem?['imageUrl'] ?? '');
    PlatformFile? pickedAccImage;

    final Set<String> selectedColourIds = {
      for (final vc in (editingItem?['colours'] as List? ?? []))
        if (vc['colour']?['id'] != null || vc['colourId'] != null)
          (vc['colour']?['id'] ?? vc['colourId']).toString(),
    };
    List<Map<String, dynamic>> allColours = [];
    bool coloursLoaded = false;
    List<Map<String, dynamic>> allModelGroups = [];
    final String? initialModelGroupId =
        editingItem?['modelGroupId']?.toString() ??
            editingItem?['modelGroup']?['id']?.toString();
    String? selectedModelGroupId = initialModelGroupId;
    bool modelGroupsLoaded = false;

    String? pickDefaultModelGroupId(
        String cat, List<Map<String, dynamic>> mgs) {
      if (mgs.isEmpty) return null;
      final wantBig = cat == 'BigBike';
      final match = mgs.firstWhere(
        (m) => m['name'].toString().toLowerCase().contains('big') == wantBig,
        orElse: () => mgs.first,
      );
      return match['id']?.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          if (_currentSection == 'vehicles' && !coloursLoaded) {
            coloursLoaded = true;
            ref.read(dioProvider).get('/vehicles/colours').then((res) {
              if (res.data is List && context.mounted) {
                setDlgState(() {
                  allColours = (res.data as List)
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .where((c) => (c['status'] ?? 'Active') == 'Active')
                      .toList();
                });
              }
            }).catchError((_) {});
          }
          if (_currentSection == 'vehicles' && !modelGroupsLoaded) {
            modelGroupsLoaded = true;
            ref.read(dioProvider).get('/vehicles/model-groups').then((res) {
              if (res.data is List && context.mounted) {
                final mgs = (res.data as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .where((m) => (m['status'] ?? 'Active') == 'Active')
                    .toList();
                setDlgState(() {
                  allModelGroups = mgs;
                  if (selectedModelGroupId == null ||
                      !mgs.any(
                          (m) => m['id']?.toString() == selectedModelGroupId)) {
                    selectedModelGroupId =
                        pickDefaultModelGroupId(vehicleType, mgs);
                  }
                });
              }
            }).catchError((_) {});
          }
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    editingItem != null
                        ? 'Edit ${_getSectionTitle()}'
                        : '${_getAddButtonText()} ${_getSectionTitle()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text('Name',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
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
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vehicle Category / Division',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: ['MC', 'Scooter', 'BigBike']
                                          .contains(vehicleType)
                                      ? vehicleType
                                      : 'MC',
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'MC',
                                        child: Text('Motorcycles (MC)')),
                                    DropdownMenuItem(
                                        value: 'Scooter',
                                        child: Text('Scooter')),
                                    DropdownMenuItem(
                                        value: 'BigBike',
                                        child: Text('Big Bike (BigWing)')),
                                  ],
                                  onChanged: (val) => setDlgState(() {
                                    vehicleType = val ?? 'MC';
                                    if (allModelGroups.isNotEmpty) {
                                      selectedModelGroupId =
                                          pickDefaultModelGroupId(
                                              vehicleType, allModelGroups);
                                    }
                                  }),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Engine CC',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: ccCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 125',
                                    suffixText: 'CC',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Honda Wing (Showroom Division)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: allModelGroups.any((m) =>
                                m['id']?.toString() == selectedModelGroupId)
                            ? selectedModelGroupId
                            : null,
                        hint: const Text('Loading Honda Wings...'),
                        items: allModelGroups.map((mg) {
                          final mgName = mg['name']?.toString() ?? 'Wing';
                          final isBig = mgName.toLowerCase().contains('big');
                          return DropdownMenuItem<String>(
                            value: mg['id']?.toString(),
                            child: Text(isBig
                                ? '$mgName (Premium & Big Bikes · ${mg['quotePrefix'] ?? 'BWQ'})'
                                : '$mgName (Commuter & Scooters · ${mg['quotePrefix'] ?? 'RWQ'})'),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setDlgState(() => selectedModelGroupId = val),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ex-Showroom (₹)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: exShowroomCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 82450',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('On-road Price (₹ Pune)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 100380',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (allColours.isNotEmpty) ...[
                        const Text('Available Factory Colours',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            String searchTxt = '';
                            final tempSelected =
                                Set<String>.from(selectedColourIds);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => StatefulBuilder(
                                builder: (c, setDrawerState) {
                                  final filteredCols = allColours.where((col) {
                                    if (searchTxt.isEmpty) return true;
                                    return (col['name'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchTxt.toLowerCase());
                                  }).toList();
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    titlePadding: const EdgeInsets.fromLTRB(
                                        20, 18, 20, 8),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Select Factory Colours',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16)),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  setDrawerState(() {
                                                tempSelected.addAll(
                                                    allColours.map((e) =>
                                                        e['id'].toString()));
                                              }),
                                              child: const Text('All',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            ),
                                            TextButton(
                                              onPressed: () => setDrawerState(
                                                  () => tempSelected.clear()),
                                              child: const Text('Clear',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Color(0xFF64748B))),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    content: SizedBox(
                                      width: 360,
                                      height: 340,
                                      child: Column(
                                        children: [
                                          TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Search colours...',
                                              prefixIcon: const Icon(
                                                  Icons.search,
                                                  size: 18),
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onChanged: (v) => setDrawerState(
                                                () => searchTxt = v),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: filteredCols.length,
                                              itemBuilder: (_, idx) {
                                                final col = filteredCols[idx];
                                                final cid =
                                                    col['id'].toString();
                                                final isChecked =
                                                    tempSelected.contains(cid);
                                                final hexStr =
                                                    col['hex']?.toString() ??
                                                        '#111827';
                                                return CheckboxListTile(
                                                  dense: true,
                                                  controlAffinity:
                                                      ListTileControlAffinity
                                                          .leading,
                                                  activeColor:
                                                      const Color(0xFFDC2626),
                                                  value: isChecked,
                                                  onChanged: (val) =>
                                                      setDrawerState(() {
                                                    if (val == true) {
                                                      tempSelected.add(cid);
                                                    } else {
                                                      tempSelected.remove(cid);
                                                    }
                                                  }),
                                                  secondary: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          _parseColor(hexStr),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFCBD5E1)),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    col['name']?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dCtx, true),
                                        child: Text(
                                            'Done (${tempSelected.length})'),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                            if (confirmed == true) {
                              setDlgState(() {
                                selectedColourIds
                                  ..clear()
                                  ..addAll(tempSelected);
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFF94A3B8)),
                            ),
                            child: Row(
                              children: [
                                if (selectedColourIds.isNotEmpty) ...[
                                  ...allColours
                                      .where((c) => selectedColourIds
                                          .contains(c['id'].toString()))
                                      .take(5)
                                      .map((c) => Container(
                                            width: 14,
                                            height: 14,
                                            margin:
                                                const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: _parseColor(
                                                  c['hex']?.toString() ??
                                                      '#111827'),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFCBD5E1)),
                                            ),
                                          )),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    selectedColourIds.isEmpty
                                        ? 'Select factory colours...'
                                        : '${selectedColourIds.length} colour${selectedColourIds.length == 1 ? '' : 's'} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: selectedColourIds.isEmpty
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF0F172A),
                                      fontWeight: selectedColourIds.isEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 20, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text('Brochure (PDF Only · Optional)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 20,
                              color: (pickedBrochurePdf != null ||
                                      brochureUrlCtrl.text.trim().isNotEmpty)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pickedBrochurePdf != null
                                    ? pickedBrochurePdf!.name
                                    : (brochureUrlCtrl.text.trim().isNotEmpty
                                        ? 'Brochure PDF attached'
                                        : 'No PDF selected'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: (pickedBrochurePdf != null ||
                                          brochureUrlCtrl.text
                                              .trim()
                                              .isNotEmpty)
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: (pickedBrochurePdf != null ||
                                          brochureUrlCtrl.text
                                              .trim()
                                              .isNotEmpty)
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (pickedBrochurePdf != null ||
                                brochureUrlCtrl.text.trim().isNotEmpty)
                              IconButton(
                                tooltip: 'Remove PDF',
                                icon: const Icon(Icons.close,
                                    size: 16, color: Color(0xFF64748B)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                onPressed: () => setDlgState(() {
                                  pickedBrochurePdf = null;
                                  brochureUrlCtrl.clear();
                                }),
                              ),
                            const SizedBox(width: 4),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  withData: true,
                                );
                                if (res != null && res.files.isNotEmpty) {
                                  final f = res.files.first;
                                  if (!f.name.toLowerCase().endsWith('.pdf')) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Only PDF (.pdf) files are allowed.')),
                                      );
                                    }
                                    return;
                                  }
                                  setDlgState(() => pickedBrochurePdf = f);
                                }
                              },
                              icon: const Icon(Icons.upload_file_rounded,
                                  size: 15, color: Color(0xFFDC2626)),
                              label: Text(
                                (pickedBrochurePdf != null ||
                                        brochureUrlCtrl.text.trim().isNotEmpty)
                                    ? 'Replace PDF'
                                    : 'Upload PDF',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: wordmarkUrlCtrl,
                        decoration: InputDecoration(
                          labelText: 'Stylized Name Wordmark (PNG / URL)',
                          hintText:
                              'Optional PNG/WebP URL or data URI for model font logo',
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (editingItem != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              showVehicleMediaManagerDialog(
                                context: context,
                                dio: ref.read(dioProvider),
                                vehicle: editingItem,
                                onUpdated: _loadSectionData,
                              );
                            },
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 16),
                            label: const Text(
                              'Manage Listing, Studio & Colour Photos →',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Vehicle Type',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value:
                            vehicleType == 'Motorcycle' || vehicleType == 'MC'
                                ? 'MC'
                                : vehicleType == 'BigBike'
                                    ? 'BigBike'
                                    : 'Scooter',
                        items: const [
                          DropdownMenuItem(
                              value: 'MC', child: Text('Motorcycles (MC)')),
                          DropdownMenuItem(
                              value: 'Scooter', child: Text('Scooters')),
                          DropdownMenuItem(
                              value: 'BigBike',
                              child: Text('Big Bikes (BigWing)')),
                        ],
                        onChanged: (val) =>
                            setDlgState(() => vehicleType = val ?? 'MC'),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
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
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: isPriceEditable,
                            activeColor: const Color(0xFFCC0000),
                            onChanged: (val) => setDlgState(
                                () => isPriceEditable = val ?? false),
                          ),
                          const Expanded(
                            child: Text('Editable at Point of Sale by Rep',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: isStandardAcc,
                            activeColor: const Color(0xFFCC0000),
                            onChanged: (val) => setDlgState(
                                () => isStandardAcc = val ?? false),
                          ),
                          const Expanded(
                            child: Text(
                                'Standard (Included by default in Build My Honda)',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Accessory Image (Upload or URL)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: pickedAccImage?.bytes != null
                                ? Image.memory(pickedAccImage!.bytes!,
                                    fit: BoxFit.cover)
                                : SmartMediaImage(
                                    source: accImageUrlCtrl.text.trim(),
                                    fit: BoxFit.cover,
                                    fallback: const Icon(
                                        Icons.image_outlined,
                                        color: Color(0xFF94A3B8)),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: accImageUrlCtrl,
                              onChanged: (_) => setDlgState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Paste image URL or upload file ->',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              if (picked != null && picked.files.isNotEmpty) {
                                setDlgState(
                                    () => pickedAccImage = picked.files.first);
                              }
                            },
                            icon: const Icon(Icons.upload_rounded, size: 15),
                            label: const Text('Upload',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                    if (_currentSection == 'branches') ...[
                      const Text('Showroom Address',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Pune - Saswad Road, Phursungi, Pune',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
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
                      final onRoad = num.tryParse(priceCtrl.text) ?? 85000;
                      final exShowroom = num.tryParse(exShowroomCtrl.text) ??
                          (onRoad * 0.85).round();
                      final ccVal = int.tryParse(ccCtrl.text.trim());
                      final bUrl = brochureUrlCtrl.text.trim().isNotEmpty
                          ? brochureUrlCtrl.text.trim()
                          : null;
                      final wUrl = wordmarkUrlCtrl.text.trim().isNotEmpty
                          ? wordmarkUrlCtrl.text.trim()
                          : null;
                      String? savedVehicleId;
                      if (editingItem != null) {
                        savedVehicleId = editingItem['id']?.toString();
                        await dio.put('/vehicles/${editingItem['id']}', data: {
                          'name': nameCtrl.text.trim(),
                          'category': vehicleType,
                          if (selectedModelGroupId != null &&
                              selectedModelGroupId != initialModelGroupId)
                            'modelGroupId': selectedModelGroupId,
                          'exShowroomPrice': exShowroom,
                          'onRoadPrice': onRoad,
                          if (ccVal != null) 'ccDisplacement': ccVal,
                          'brochureUrl': bUrl,
                          'wordmarkImageUrl': wUrl,
                          'colourIds': selectedColourIds.toList(),
                        });
                      } else {
                        String? mgId = selectedModelGroupId;
                        if (mgId == null) {
                          final mgRes = await dio.get('/vehicles/model-groups');
                          final mgs = (mgRes.data as List)
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .toList();
                          mgId = pickDefaultModelGroupId(vehicleType, mgs);
                        }
                        final createRes = await dio.post('/vehicles', data: {
                          'code': codeCtrl.text.trim().isEmpty
                              ? 'MOD-${DateTime.now().millisecondsSinceEpoch}'
                              : codeCtrl.text.trim(),
                          'name': nameCtrl.text.trim(),
                          'category': vehicleType,
                          'modelGroupId': mgId,
                          'exShowroomPrice': exShowroom,
                          'onRoadPrice': onRoad,
                          if (ccVal != null) 'ccDisplacement': ccVal,
                          'brochureUrl': bUrl,
                          'wordmarkImageUrl': wUrl,
                          'colourIds': selectedColourIds.toList(),
                        });
                        savedVehicleId = createRes.data?['id']?.toString();
                      }
                      if (pickedBrochurePdf != null &&
                          savedVehicleId != null &&
                          savedVehicleId.isNotEmpty) {
                        final formData = FormData();
                        if (pickedBrochurePdf!.bytes != null) {
                          formData.files.add(MapEntry(
                            'file',
                            MultipartFile.fromBytes(pickedBrochurePdf!.bytes!,
                                filename: pickedBrochurePdf!.name),
                          ));
                        } else if (pickedBrochurePdf!.path != null) {
                          formData.files.add(MapEntry(
                            'file',
                            await MultipartFile.fromFile(
                                pickedBrochurePdf!.path!,
                                filename: pickedBrochurePdf!.name),
                          ));
                        }
                        await dio.post('/vehicles/$savedVehicleId/brochure',
                            data: formData);
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
                        await dio.put('/vehicles/colours/${editingItem['id']}',
                            data: {
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
                      final imgUrlVal = accImageUrlCtrl.text.trim().isNotEmpty
                          ? accImageUrlCtrl.text.trim()
                          : null;
                      String? savedAccId;
                      if (editingItem != null) {
                        savedAccId = editingItem['id']?.toString();
                        await dio
                            .put('/accessories/${editingItem['id']}', data: {
                          'name': nameCtrl.text.trim(),
                          'defaultPrice': p,
                          'isPriceEditable': isPriceEditable,
                          'isStandard': isStandardAcc,
                          if (pickedAccImage == null) 'imageUrl': imgUrlVal,
                        });
                      } else {
                        final res = await dio.post('/accessories', data: {
                          'name': nameCtrl.text.trim(),
                          'defaultPrice': p,
                          'isPriceEditable': isPriceEditable,
                          'isStandard': isStandardAcc,
                          if (pickedAccImage == null && imgUrlVal != null)
                            'imageUrl': imgUrlVal,
                        });
                        savedAccId = res.data?['id']?.toString();
                      }
                      if (pickedAccImage?.bytes != null &&
                          savedAccId != null &&
                          savedAccId.isNotEmpty) {
                        final formData = FormData();
                        formData.files.add(MapEntry(
                          'file',
                          MultipartFile.fromBytes(pickedAccImage!.bytes!,
                              filename: pickedAccImage!.name),
                        ));
                        await dio.post('/accessories/$savedAccId/image',
                            data: formData);
                      }
                    } else if (_currentSection == 'financiers') {
                      if (editingItem != null) {
                        await dio
                            .put('/financiers/${editingItem['id']}', data: {
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
                          'address': addressCtrl.text.trim().isNotEmpty
                              ? addressCtrl.text.trim()
                              : 'Pune, MH',
                        });
                      } else {
                        await dio.post('/branches', data: {
                          'code': codeCtrl.text.trim(),
                          'name': nameCtrl.text.trim(),
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
                            content: Text(
                                '${_getSectionTitle()} saved successfully')),
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
          );
        },
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      editingItem != null ? 'Edit User' : 'Add Staff User',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0F172A)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
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
                          'OWNER',
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
                              value: 'OWNER', child: Text('Owner')),
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
        title: Row(
          children: [
            Expanded(
              child: Text('Reset Password for ${user['name']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A))),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
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

  Future<void> _saveCompanyProfile({bool silent = false}) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/settings', data: {
        'companyName': _compNameCtrl.text.trim(),
        'gstNumber': _gstCtrl.text.trim(),
        'address': _addrCtrl.text.trim(),
        'bankName': _bankCtrl.text.trim(),
        'accountNumber': _accCtrl.text.trim(),
        'ifsc': _ifscCtrl.text.trim(),
        'upiId': _upiCtrl.text.trim(),
        'hypothecationCharge': num.tryParse(_hypoCtrl.text.trim()) ?? 0,
        'applyHypothecationDefault': _applyHypo,
        'logoUrl': _logoUrl,
        'upiQrUrl': _upiQrUrl,
        'officeHoursEnabled': _officeHoursEnabled,
        'officeWindows': _officeWindows,
      });

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company Profile saved successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving company profile: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('data:') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) return path;
    final base = ApiConstants.baseUrl.endsWith('/api')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 4)
        : ApiConstants.baseUrl;
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }

  Widget _buildBrandingImage(String? url, {required Widget fallback}) {
    if (url == null || url.trim().isEmpty) return fallback;
    final clean = url.trim();
    if (clean.startsWith('data:image')) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Data =
            commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }
    return Image.network(
      _resolveImageUrl(clean),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Future<void> _pickAndUploadBranding(String type) async {
    final isLogo = type == 'logo';
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;

      setState(() {
        if (isLogo) {
          _isUploadingLogo = true;
        } else {
          _isUploadingUpiQr = true;
        }
      });

      // Encode bytes to Base64 Data URI so it survives Render ephemeral restarts
      String? localDataUri;
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        final ext = (file.extension ?? 'png').toLowerCase();
        final mime = ext == 'svg'
            ? 'image/svg+xml'
            : (ext == 'webp'
                ? 'image/webp'
                : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png'));
        localDataUri = 'data:$mime;base64,${base64Encode(file.bytes!)}';
      }

      final dio = ref.read(dioProvider);
      final formData = FormData();
      if (file.bytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(file.bytes!, filename: file.name),
        ));
      } else if (file.path != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(file.path!, filename: file.name),
        ));
      }

      String? uploadedUrl;
      try {
        final res = await dio.post('/settings/upload/$type', data: formData);
        uploadedUrl = res.data?['url']?.toString() ??
            res.data?['settings']?['logoUrl']?.toString() ??
            res.data?['settings']?['upiQrUrl']?.toString();
      } catch (err) {
        uploadedUrl = localDataUri;
      }

      final finalUrl = (uploadedUrl != null && uploadedUrl.isNotEmpty)
          ? uploadedUrl
          : localDataUri;

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = finalUrl;
          _isUploadingLogo = false;
        } else {
          _upiQrUrl = finalUrl;
          _isUploadingUpiQr = false;
        }
      });

      // Automatically persist to companySettings in database
      await _saveCompanyProfile(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${isLogo ? 'Logo' : 'UPI QR code'} uploaded and saved permanently!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _isUploadingLogo = false;
        } else {
          _isUploadingUpiQr = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _removeBranding(String type) async {
    final isLogo = type == 'logo';
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/settings/branding/$type');

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoUrl = null;
        } else {
          _upiQrUrl = null;
        }
      });

      await _saveCompanyProfile(silent: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isLogo ? 'Logo' : 'UPI QR code'} removed.'),
            backgroundColor: const Color(0xFF0F172A),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove image: $e')),
      );
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
                child: _loadError != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined,
                              size: 36, color: Color(0xFFEF4444)),
                          const SizedBox(height: 10),
                          Text(
                            'Unable to load ${_getSectionTitle().toLowerCase()}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Server was temporarily busy or re-connecting. Please retry.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _loadSectionData,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Retry'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'No ${_getSectionTitle().toLowerCase()} found.',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13),
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
          Expanded(flex: 3, child: Text('Model & CC', style: headerStyle)),
          Expanded(flex: 2, child: Text('Group / Div', style: headerStyle)),
          Expanded(flex: 2, child: Text('Price (Ex / OR)', style: headerStyle)),
          Expanded(flex: 2, child: Text('Showroom Media', style: headerStyle)),
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
          Expanded(flex: 4, child: Text('Add-on', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base price', style: headerStyle)),
          Expanded(
              flex: 2, child: Text('Configurator Type', style: headerStyle)),
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
          Expanded(flex: 6, child: Text('Address', style: headerStyle)),
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
              width: 205, child: Text('', textAlign: TextAlign.right)),
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
              onChanged:
                  isSuperAdmin ? (val) => _toggleStatus(item, val) : null,
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
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
        final cat = item['category'] ?? 'MC';
        final cc = item['ccDisplacement'];
        final group = item['modelGroup']?['name'] ??
            (cat == 'Scooter' ? 'RW Scooter' : 'Red Wing');
        final exPrice = CurrencyFormatter.format(item['exShowroomPrice'] ?? 0);
        final price = CurrencyFormatter.format(item['onRoadPrice'] ?? 97200);
        final brochureUrl = item['brochureUrl'] as String?;
        final thumbUrl = item['listingImageUrl']?.toString() ??
            item['detailImageUrl']?.toString();
        final colourList = (item['colours'] as List? ?? []);
        final colourImgsUploaded = colourList
            .where((c) =>
                c['colourImageUrl'] != null &&
                c['colourImageUrl'].toString().isNotEmpty)
            .length;
        final baseCount = (item['listingImageUrl'] != null ? 1 : 0) +
            (item['detailImageUrl'] != null ? 1 : 0) +
            colourImgsUploaded;

        Widget mediaWidget = OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: baseCount > 0
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFAFAFA),
            side: BorderSide(
              color: baseCount > 0
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFCBD5E1),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () {
            if (isSuperAdmin) {
              showVehicleMediaManagerDialog(
                context: context,
                dio: ref.read(dioProvider),
                vehicle: item,
                onUpdated: _loadSectionData,
              );
            }
          },
          icon: Icon(
            Icons.photo_library_outlined,
            size: 13,
            color: baseCount > 0
                ? const Color(0xFF16A34A)
                : const Color(0xFF64748B),
          ),
          label: Text(
            baseCount > 0 ? 'Photos ($baseCount)' : 'Add Photos',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: baseCount > 0
                  ? const Color(0xFF166534)
                  : const Color(0xFF475569),
            ),
          ),
        );

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
            child: Row(
              children: [
                if (thumbUrl != null && thumbUrl.isNotEmpty) ...[
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SmartMediaImage(source: thumbUrl, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              textStyle.copyWith(fontWeight: FontWeight.w600)),
                      if (cc != null)
                        Text('$cc CC',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group, style: textStyle),
                Text(cat,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(price,
                    style: textStyle.copyWith(fontWeight: FontWeight.w700)),
                Text('Ex: $exPrice',
                    style: const TextStyle(
                        fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Expanded(
              flex: 2,
              child:
                  Align(alignment: Alignment.centerLeft, child: mediaWidget)),
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
        final isStandard = item['isStandard'] == true;
        final imgUrl = item['imageUrl']?.toString();

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SmartMediaImage(
                    source: imgUrl,
                    fit: BoxFit.contain,
                    fallback: const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(price, style: textStyle)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: isSuperAdmin
                    ? () async {
                        final dio = ref.read(dioProvider);
                        await dio.put('/accessories/${item['id']}',
                            data: {'isStandard': !isStandard});
                        _loadSectionData();
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isStandard
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isStandard
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    isStandard ? 'Standard (Included)' : 'Optional',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isStandard
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
        final address = item['address'] ?? '';

        return [
          Expanded(flex: 2, child: Text(code, style: textStyle)),
          Expanded(
              flex: 3,
              child: Text(name,
                  style: textStyle.copyWith(fontWeight: FontWeight.w500))),
          Expanded(
              flex: 6,
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
          width: 205,
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
              if (isSuperAdmin) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFF94A3B8)),
                  splashRadius: 18,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  tooltip: 'Delete ${item['name'] ?? 'user'}',
                  onPressed: () => _deleteItem(item),
                ),
              ],
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
    'Summary',
    'Reports',
    'Masters',
    'Users',
    'Company Profile',
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
          // Header Row with Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Appears on every quotation PDF and payment footer.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                onPressed: () => _saveCompanyProfile(),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Save Changes',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
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
          // 1. Logo
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
                      width: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      child: _buildBrandingImage(
                        _logoUrl,
                        fallback: const Text('HONDA',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFDC2626),
                                fontSize: 9)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isUploadingLogo
                          ? null
                          : () => _pickAndUploadBranding('logo'),
                      icon: _isUploadingLogo
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFDC2626)))
                          : const Icon(Icons.arrow_upward_rounded,
                              size: 14, color: Color(0xFF1E293B)),
                      label: Text(_isUploadingLogo ? 'Uploading...' : 'Replace',
                          style: const TextStyle(
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
                      onPressed: (_logoUrl != null && _logoUrl!.isNotEmpty)
                          ? () => _removeBranding('logo')
                          : null,
                      tooltip: 'Remove logo',
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 2. UPI QR Code
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
                      clipBehavior: Clip.antiAlias,
                      child: _buildBrandingImage(
                        _upiQrUrl,
                        fallback: const Icon(Icons.qr_code_2_rounded,
                            size: 24, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isUploadingUpiQr
                          ? null
                          : () => _pickAndUploadBranding('upi-qr'),
                      icon: _isUploadingUpiQr
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFDC2626)))
                          : const Icon(Icons.arrow_upward_rounded,
                              size: 14, color: Color(0xFF1E293B)),
                      label: Text(
                          _isUploadingUpiQr ? 'Uploading...' : 'Replace',
                          style: const TextStyle(
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
                      onPressed: (_upiQrUrl != null && _upiQrUrl!.isNotEmpty)
                          ? () => _removeBranding('upi-qr')
                          : null,
                      tooltip: 'Remove UPI QR code',
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
        title: Row(
          children: [
            const Expanded(
              child: Text('Add Time Window',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
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
        title: Row(
          children: [
            const Expanded(
              child: Text('Edit Time Window',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
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
