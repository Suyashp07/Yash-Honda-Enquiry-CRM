import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/providers/branch_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/auth_notifier.dart';

class CustomizeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;
  final String? initialRepId;

  const CustomizeScreen(
      {super.key, this.vehicle = const {}, this.initialRepId});

  @override
  ConsumerState<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends ConsumerState<CustomizeScreen> {
  // Form Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _remarksController = TextEditingController();

  // Exchange Controllers
  final _exchangeMakeModelController = TextEditingController();
  final _exchangeYearController = TextEditingController();
  final _exchangeKmsController = TextEditingController();
  final _exchangeExpectedController = TextEditingController();

  // Master Data Lists
  List<dynamic> _vehicles = [];
  List<dynamic> _branches = [];
  List<dynamic> _accessories = [];
  List<dynamic> _financiers = [];
  List<dynamic> _leadSources = [];
  List<dynamic> _salesReps = [];
  Map<String, dynamic>? _settings;
  Timer? _sessionDebounceTimer;

  void _debouncedSyncSession() {
    setState(() {});
    _sessionDebounceTimer?.cancel();
    _sessionDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _syncLiveFloorSession();
    });
  }

  Future<void> _syncLiveFloorSession() async {
    if (_selectedRepId == null || _selectedVehicle == null) return;
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final vehicle = _selectedVehicle?['name'] ?? 'Honda Model';
    final colour = _selectedColour;
    final grandTotal = _liveCalculation?['grandTotal'];

    final repObj = _salesReps.firstWhere(
      (r) => r['id']?.toString() == _selectedRepId,
      orElse: () => null,
    );
    final repName = repObj?['name']?.toString() ?? 'Sales Rep';

    final payload = {
      'salesExecId': _selectedRepId,
      'salesExecName': repName,
      'customerName': name.isNotEmpty ? name : 'Walk-in Guest',
      'customerMobile': mobile,
      'vehicleName': vehicle,
      'colourName': colour,
      'grandTotal': grandTotal,
      'branchId': _selectedBranchId ?? '',
      'status': 'IN_PROGRESS',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 1. Sync instantly to browser storage for 0ms cross-tab visibility
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.write(
        key: 'yash_live_session_${_selectedRepId}',
        value: jsonEncode(payload),
      );
    } catch (_) {}

    // 2. Broadcast to backend server
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/analytics/floor/session', data: payload);
    } catch (_) {}
  }

  Future<void> _endLiveFloorSession() async {
    if (_selectedRepId == null) return;
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: 'yash_live_session_${_selectedRepId}');
    } catch (_) {}
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/analytics/floor/session/$_selectedRepId');
    } catch (_) {}
  }

  // Selected State
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;
  String? _selectedColour;
  String? _selectedBranchId;
  String _selectedType = 'Walk-in';
  String? _selectedSourceId;
  String? _selectedAreaId;
  String? _selectedRepId;
  String _purchaseMode = 'Cash';
  String? _selectedFinancierId;
  String _buyingWhen = 'Immediate';
  String _exchange = 'no'; // 'no', 'yes', 'yes_print'

  final _downPaymentController = TextEditingController();
  final _emi24Controller = TextEditingController();
  final _emi36Controller = TextEditingController();
  final _emi48Controller = TextEditingController();
  final _hypothecationController = TextEditingController();
  String? _emiDefaultsVehicleId;

  void _populateEmiDefaults(double total, {bool force = false}) {
    if (total <= 0) return;
    if (!force &&
        _emiDefaultsVehicleId == _selectedVehicleId &&
        _downPaymentController.text.trim().isNotEmpty) {
      return;
    }
    _emiDefaultsVehicleId = _selectedVehicleId;
    _downPaymentController.text = (total * 0.20).round().toString();
    _emi24Controller.text = ((total * 0.80 * 1.12) / 24).round().toString();
    _emi36Controller.text = ((total * 0.80 * 1.18) / 36).round().toString();
    _emi48Controller.text = ((total * 0.80 * 1.24) / 48).round().toString();
    if (_hypothecationController.text.trim().isEmpty) {
      _hypothecationController.text = '500';
    }
  }

  final Set<String> _selectedAccessoryIds = {};
  bool _sendEmail = false;
  bool _sendWhatsApp = false;
  bool _marketingConsent = true;

  bool _isLoadingMasters = true;
  bool _isCalculating = false;
  bool _calculationError = false;
  Map<String, dynamic>? _liveCalculation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Listen to text changes for immediate dynamic update of the Quote Preview and Live Floor Session!
    _nameController.addListener(_debouncedSyncSession);
    _mobileController.addListener(_debouncedSyncSession);

    _loadAllMasters();
  }

  @override
  void dispose() {
    _sessionDebounceTimer?.cancel();
    _endLiveFloorSession();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    _exchangeMakeModelController.dispose();
    _exchangeYearController.dispose();
    _exchangeKmsController.dispose();
    _exchangeExpectedController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMasters() async {
    setState(() => _isLoadingMasters = true);
    try {
      final dio = ref.read(dioProvider);
      final results = await Future.wait([
        dio.get('/vehicles'),
        dio.get('/branches'),
        dio.get('/settings'),
        dio.get('/accessories'),
        dio.get('/financiers'),
        dio.get('/areas'),
        dio.get('/lead-sources'),
        dio.get('/users'),
      ]);

      final vehicles = results[0].data as List;
      final branches = results[1].data as List;
      final settings = results[2].data as Map<String, dynamic>;
      final accessories = results[3].data as List;
      final financiers = results[4].data as List;
      final areas = results[5].data as List;
      final leadSources = results[6].data as List;
      final users = results[7].data as List;

      // Filter sales reps
      final reps = users
          .where(
              (u) => u['role'] == 'SALES_EXEC' || u['role'] == 'BRANCH_MANAGER')
          .toList();

      // Initial vehicle selection: ONLY pre-select if explicitly passed via widget.vehicle
      Map<String, dynamic>? initialVehicle;
      if (widget.vehicle.isNotEmpty && widget.vehicle['id'] != null) {
        initialVehicle = widget.vehicle;
      }

      String? initialVehicleId = initialVehicle?['id']?.toString();
      String? initialColour;
      final vColours = (initialVehicle?['colours'] as List?) ?? [];
      if (vColours.isNotEmpty) {
        initialColour =
            vColours.first['colour']?['name']?.toString() ?? 'Black';
      }

      // Initial branch selection
      final user = ref.read(authStateProvider).user;
      final activeBranchId = ref.read(selectedBranchIdProvider);
      String? initialBranchId;
      if (activeBranchId != 'all' &&
          branches.any((b) => b['id'].toString() == activeBranchId)) {
        initialBranchId = activeBranchId;
      } else if (user != null && user.branches.isNotEmpty) {
        initialBranchId = user.branches.first.id;
      } else if (branches.isNotEmpty) {
        initialBranchId = branches.first['id'].toString();
      }

      // Initial sales rep selection: query param -> logged-in user -> first rep
      String? initialRepId = widget.initialRepId;
      if (initialRepId == null ||
          !reps.any((r) => r['id'].toString() == initialRepId)) {
        if (user != null && reps.any((r) => r['id'].toString() == user.id)) {
          initialRepId = user.id;
        } else if (reps.isNotEmpty) {
          initialRepId = reps.first['id'].toString();
        }
      }

      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _branches = branches;
        _settings = settings;
        _accessories = accessories;
        _financiers = financiers;
        _leadSources = leadSources;

        _selectedVehicle = initialVehicle;
        _selectedVehicleId = initialVehicleId;
        _selectedColour = initialColour;
        _selectedBranchId = initialBranchId;
        _salesReps = reps;

        // Start from scratch: leave source, area, financier unselected
        _selectedSourceId = null;
        _selectedAreaId = null;
        _selectedRepId = initialRepId ??
            (reps.isNotEmpty ? reps.first['id'].toString() : null);
        _selectedFinancierId = null;

        _isLoadingMasters = false;
      });

      if (initialVehicleId != null) {
        _calculateQuote();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMasters = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading master data: $e')),
        );
      }
    }
  }

  Future<void> _calculateQuote() async {
    if (_selectedVehicleId == null || _selectedBranchId == null) return;
    if (!mounted) return;
    setState(() {
      _isCalculating = true;
      _calculationError = false;
    });

    try {
      final dio = ref.read(dioProvider);
      final accList =
          _selectedAccessoryIds.map((id) => {'accessoryId': id}).toList();

      final res = await dio.post('/quotations/calculate', data: {
        'vehicleId': _selectedVehicleId,
        'branchId': _selectedBranchId,
        'colourName': _selectedColour,
        'purchaseMode': _purchaseMode,
        'accessories': accList,
        if (_purchaseMode == 'Finance')
          'hypothecationCharge':
              double.tryParse(_hypothecationController.text.trim()) ?? 0,
      });

      if (!mounted) return;
      setState(() {
        _liveCalculation = res.data;
        _isCalculating = false;
        _calculationError = false;
      });
      _syncLiveFloorSession();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCalculating = false;
        _calculationError = true;
        _liveCalculation = null;
      });
    }
  }

  void _onVehicleChanged(String? newVehicleId) {
    if (newVehicleId == null) {
      setState(() {
        _selectedVehicleId = null;
        _selectedVehicle = null;
        _selectedColour = null;
        _liveCalculation = null;
      });
      return;
    }
    final found = _vehicles.firstWhere(
        (v) => v['id'].toString() == newVehicleId,
        orElse: () => null);
    if (found != null) {
      String? newColour;
      final vColours = (found['colours'] as List?) ?? [];
      if (vColours.isNotEmpty) {
        newColour = vColours.first['colour']?['name']?.toString() ?? 'Black';
      }

      setState(() {
        _selectedVehicleId = newVehicleId;
        _selectedVehicle = found;
        _selectedColour = newColour;
      });
      _calculateQuote();
    }
  }

  Future<void> _saveEnquiry() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Customer Name')),
      );
      return;
    }

    if (mobile.isEmpty || mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid 10-digit Mobile Number')),
      );
      return;
    }

    if (_selectedVehicleId == null || _selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Vehicle and Branch')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      final accList =
          _selectedAccessoryIds.map((id) => {'accessoryId': id}).toList();

      final baseRemarks = _remarksController.text.trim();
      final exchParts = <String>[];
      if (_exchange != 'no') {
        final mm = _exchangeMakeModelController.text.trim();
        final yr = _exchangeYearController.text.trim();
        final kms = _exchangeKmsController.text.trim();
        final exp = _exchangeExpectedController.text.trim();
        if (mm.isNotEmpty) exchParts.add(mm);
        if (yr.isNotEmpty) exchParts.add('Year: $yr');
        if (kms.isNotEmpty) exchParts.add('Kms: $kms');
        if (exp.isNotEmpty) exchParts.add('Expected: ₹$exp');
      }
      final financeParts = <String>[];
      if (_purchaseMode == 'Finance') {
        final dp = _downPaymentController.text.trim();
        final e24 = _emi24Controller.text.trim();
        final e36 = _emi36Controller.text.trim();
        final e48 = _emi48Controller.text.trim();
        final hypo = _hypothecationController.text.trim();
        if (dp.isNotEmpty) financeParts.add('DP: ₹$dp');
        if (e24.isNotEmpty) financeParts.add('24m: ₹$e24');
        if (e36.isNotEmpty) financeParts.add('36m: ₹$e36');
        if (e48.isNotEmpty) financeParts.add('48m: ₹$e48');
        if (hypo.isNotEmpty) financeParts.add('Hypothecation: ₹$hypo');
      }
      final combinedRemarks = [
        if (financeParts.isNotEmpty) 'Financing (${financeParts.join(', ')})',
        if (exchParts.isNotEmpty) 'Exchange (${exchParts.join(', ')})',
        if (baseRemarks.isNotEmpty) baseRemarks,
      ].join(' • ');

      final res = await dio.post('/enquiries', data: {
        'branchId': _selectedBranchId,
        'customer': {
          'name': name,
          'mobile': mobile,
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'areaId': _selectedAreaId,
        },
        'enquiryType': _selectedType,
        'leadSourceId': _selectedSourceId,
        'assignedToId': _selectedRepId,
        'purchaseMode': _purchaseMode,
        'financierId': _purchaseMode == 'Finance' ? _selectedFinancierId : null,
        'exchange': _exchange == 'yes_print'
            ? 'Yes & Print'
            : (_exchange == 'yes' ? 'Yes' : 'No'),
        'buyingWhen': _buyingWhen,
        'remarks': combinedRemarks.isEmpty ? null : combinedRemarks,
        'quotation': {
          'vehicleId': _selectedVehicleId,
          'colourName': _selectedColour,
          'accessories': accList,
          if (_purchaseMode == 'Finance')
            'hypothecationCharge':
                double.tryParse(_hypothecationController.text.trim()) ?? 0,
        },
      });

      final enquiry = res.data;
      final quotation = (enquiry['quotations'] as List?)?.first ?? {};
      _endLiveFloorSession();

      // If user selected "Send by email" and provided customer email, dispatch quotation email
      final custEmail = _emailController.text.trim();
      if (_sendEmail && custEmail.isNotEmpty && quotation['id'] != null) {
        try {
          await dio.post('/communications/email', data: {
            'enquiryId': enquiry['id'],
            'recipientEmail': custEmail,
            'subject': 'Your Official Quotation - Yash Honda Pune',
            'quotationId': quotation['id'],
          });
        } catch (_) {}
      }

      if (mounted) {
        context.go('/enquiries/quote-actions', extra: {
          'enquiry': enquiry,
          'quotation': quotation,
        });
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save enquiry: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMasters) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 14),
              Text('Initializing Enquiry & Live Quotation Engine...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    final vehicleName = _selectedVehicle?['name'] ?? 'Select Vehicle';
    final grandTotal = _liveCalculation?['grandTotal'] ?? 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // Top Bar Header
              _buildTopHeader(vehicleName, grandTotal),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Main Body Content: Form (Left) & Live Quote Preview (Right)
              Expanded(
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Form (Flex 6)
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              child: _buildEnquiryForm(),
                            ),
                          ),
                          // Subtle vertical divider line
                          Container(width: 1, color: const Color(0xFFE2E8F0)),
                          // Right Live Quote Preview (Flex 5)
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.all(20),
                              child: _buildLiveQuotePreview(vehicleName),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildEnquiryForm(),
                            const SizedBox(height: 24),
                            _buildLiveQuotePreview(vehicleName),
                          ],
                        ),
                      ),
              ),

              // Bottom Action Footer Bar
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildBottomFooterBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(String vehicleName, dynamic grandTotal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: New Enquiry Title
          const Text(
            'New Enquiry',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),

          // Center Top Pill Badge & Switcher
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedVehicle != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$vehicleName + add-ons/charges',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(grandTotal),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.two_wheeler_outlined,
                          size: 14, color: Color(0xFF94A3B8)),
                      SizedBox(width: 6),
                      Text(
                        'Select a vehicle to configure quotation',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.go('/build-my-honda'),
                icon: const Icon(Icons.two_wheeler_outlined, size: 14),
                label: const Text('Build My Honda Wizard',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          // Right: Close Button
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnquiryForm() {
    final vColours = (_selectedVehicle?['colours'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Customer Name, Mobile, Email
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                label: 'Customer Name *',
                controller: _nameController,
                hint: 'e.g. Rahul Patil',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                label: 'Mobile Number *',
                controller: _mobileController,
                hint: '10-digit mobile',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                maxLength: 10,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                label: 'Email',
                controller: _emailController,
                hint: 'name@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 2: Type, Source, Buying When
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Type',
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'Walk-in', child: Text('Walk-in')),
                  DropdownMenuItem(
                      value: 'Telephonic', child: Text('Telephonic')),
                  DropdownMenuItem(
                      value: 'Online', child: Text('Online / Web')),
                ],
                onChanged: (val) =>
                    setState(() => _selectedType = val ?? 'Walk-in'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Source',
                value: _selectedSourceId,
                hintText: 'Select source',
                items: _leadSources.map((ls) {
                  return DropdownMenuItem(
                      value: ls['id'].toString(), child: Text(ls['name']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedSourceId = val),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Buying When',
                value: _buyingWhen,
                hintText: 'Select timeline',
                items: const [
                  DropdownMenuItem(
                      value: 'Immediate', child: Text('Immediate')),
                  DropdownMenuItem(
                      value: 'Within 7 Days', child: Text('Within 7 Days')),
                  DropdownMenuItem(
                      value: 'Within 15 Days', child: Text('Within 15 Days')),
                  DropdownMenuItem(
                      value: 'This Month', child: Text('This Month')),
                ],
                onChanged: (val) =>
                    setState(() => _buyingWhen = val ?? 'Immediate'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 3: Vehicle *, Colour, Purchase Mode, Financier
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _buildDropdownField<String>(
                label: 'Vehicle *',
                value: _selectedVehicleId,
                hintText: 'Select vehicle model',
                highlightBorder: _selectedVehicleId == null,
                items: _vehicles.map((v) {
                  return DropdownMenuItem(
                      value: v['id'].toString(), child: Text(v['name']));
                }).toList(),
                onChanged: _onVehicleChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildDropdownField<String>(
                label: 'Colour',
                value: _selectedColour,
                hintText: _selectedVehicle == null
                    ? 'Select vehicle first'
                    : 'Select colour',
                items: vColours.isEmpty
                    ? <DropdownMenuItem<String>>[]
                    : vColours.map<DropdownMenuItem<String>>((vc) {
                        final cName =
                            vc['colour']?['name']?.toString() ?? 'Colour';
                        return DropdownMenuItem<String>(
                            value: cName, child: Text(cName));
                      }).toList(),
                onChanged: _selectedVehicle == null
                    ? null
                    : (val) {
                        setState(() => _selectedColour = val);
                        _calculateQuote();
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildDropdownField<String>(
                label: 'Purchase Mode',
                value: _purchaseMode,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(
                      value: 'Finance', child: Text('Finance (Loan)')),
                ],
                onChanged: (val) {
                  setState(() => _purchaseMode = val ?? 'Cash');
                  _calculateQuote();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _buildDropdownField<String>(
                label: 'Financier',
                value: _purchaseMode == 'Finance' ? _selectedFinancierId : null,
                hintText: _purchaseMode == 'Finance'
                    ? 'Select financier'
                    : 'N/A (Cash)',
                items: _financiers.map((f) {
                  return DropdownMenuItem(
                      value: f['id'].toString(), child: Text(f['name']));
                }).toList(),
                onChanged: _purchaseMode == 'Finance'
                    ? (val) => setState(() => _selectedFinancierId = val)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // FINANCING Section (when Finance selected)
        if (_purchaseMode == 'Finance') ...[
          const Text(
            'FINANCING',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFinancingInput(
                  label: 'Down Payment',
                  controller: _downPaymentController,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancingInput(
                  label: 'EMI · 24m',
                  controller: _emi24Controller,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancingInput(
                  label: 'EMI · 36m',
                  controller: _emi36Controller,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancingInput(
                  label: 'EMI · 48m',
                  controller: _emi48Controller,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancingInput(
                  label: 'Hypothecation',
                  controller: _hypothecationController,
                  onChanged: (_) => _calculateQuote(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Down payment and each EMI tenure default from the vehicle\'s Model Master figures and are independently editable - changing one does not recalculate the others.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
        ],

        // ADD-ONS Section
        const Text(
          'ADD-ONS',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _accessories.map((acc) {
            final id = acc['id'].toString();
            final isChecked = _selectedAccessoryIds.contains(id);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _selectedAccessoryIds.remove(id);
                  } else {
                    _selectedAccessoryIds.add(id);
                  }
                });
                _calculateQuote();
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isChecked ? AppColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: isChecked,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedAccessoryIds.add(id);
                            } else {
                              _selectedAccessoryIds.remove(id);
                            }
                          });
                          _calculateQuote();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      acc['name'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isChecked
                            ? AppColors.primary
                            : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // EXCHANGE Section
        const Text(
          'EXCHANGE',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildExchangeSegment('no', 'No'),
            const SizedBox(width: 8),
            _buildExchangeSegment('yes', 'Yes'),
            const SizedBox(width: 8),
            _buildExchangeSegment('yes_print', 'Yes & Print'),
          ],
        ),
        if (_exchange != 'no') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Make & Model',
                  controller: _exchangeMakeModelController,
                  hint: 'e.g. Hero Splendor',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  label: 'Year',
                  controller: _exchangeYearController,
                  hint: 'e.g. 2018',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  label: 'Kms Run',
                  controller: _exchangeKmsController,
                  hint: 'e.g. 18000',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(
                  label: 'Expected ₹',
                  controller: _exchangeExpectedController,
                  hint: 'e.g. 25000',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),

        // Remarks Section
        const Text(
          'Remarks',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _remarksController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Notes about customer preferences...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
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
        const SizedBox(height: 14),

        // Checkboxes: Send by email, Send by WhatsApp, Marketing consent
        Row(
          children: [
            _buildCheckboxOption('Send by email', _sendEmail,
                (v) => setState(() => _sendEmail = v ?? false)),
            const SizedBox(width: 16),
            _buildCheckboxOption('Send by WhatsApp', _sendWhatsApp,
                (v) => setState(() => _sendWhatsApp = v ?? false)),
            const SizedBox(width: 16),
            _buildCheckboxOption('Marketing consent', _marketingConsent,
                (v) => setState(() => _marketingConsent = v ?? true)),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveQuotePreview(String vehicleName) {
    // Dynamic binding to customer & branch details
    final customerName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim().toUpperCase()
        : '-';
    final customerMobile = _mobileController.text.trim().isNotEmpty
        ? _mobileController.text.trim()
        : '-';

    final selectedBranch = _branches.firstWhere(
      (b) => b['id'].toString() == _selectedBranchId,
      orElse: () => null,
    );
    final branchAddress = selectedBranch != null
        ? '${selectedBranch['name']} · ${selectedBranch['address']}'
        : (_settings?['address'] ?? 'Pune, Maharashtra');

    final gstin = _settings?['gstNumber']?.toString().isNotEmpty == true
        ? _settings!['gstNumber']
        : 'Not configured';
    final bankName = _settings?['bankName']?.toString().isNotEmpty == true
        ? _settings!['bankName']
        : 'Not configured';
    final accountNo = _settings?['accountNumber']?.toString().isNotEmpty == true
        ? _settings!['accountNumber']
        : 'Not configured';
    final ifsc = _settings?['ifsc']?.toString().isNotEmpty == true
        ? _settings!['ifsc']
        : 'Not configured';
    final upiId = _settings?['upiId']?.toString().isNotEmpty == true
        ? _settings!['upiId']
        : 'Not configured';

    final rawEx = _liveCalculation?['exShowroom'];
    final exShowroom = _selectedVehicle != null
        ? (rawEx is num
            ? rawEx.toDouble()
            : (double.tryParse(rawEx?.toString() ?? '') ?? 0.0))
        : 0.0;

    final rawTax = _liveCalculation?['roadTax'];
    final roadTax = _selectedVehicle != null
        ? (rawTax is num
            ? rawTax.toDouble()
            : (double.tryParse(rawTax?.toString() ?? '') ?? 0.0))
        : 0.0;

    final rawIns = _liveCalculation?['insurance'];
    final insurance = _selectedVehicle != null
        ? (rawIns is num
            ? rawIns.toDouble()
            : (double.tryParse(rawIns?.toString() ?? '') ?? 0.0))
        : 0.0;

    final rawStd = _liveCalculation?['stdAccessories'];
    final stdAccessories = _selectedVehicle != null
        ? (rawStd is num
            ? rawStd.toDouble()
            : (double.tryParse(rawStd?.toString() ?? '') ?? 1800.0))
        : 0.0;

    final rawTotal = _liveCalculation?['grandTotal'];
    final grandTotal = _selectedVehicle != null
        ? (rawTotal is num
            ? rawTotal.toDouble()
            : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0))
        : 0.0;

    final calcAccessories = (_liveCalculation?['accessories'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _calculationError
                      ? 'Quote preview — price not verified'
                      : 'Quote Preview (live)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _calculationError ? AppColors.danger : AppColors.ink,
                  ),
                ),
                Text(
                  _selectedVehicle != null
                      ? vehicleName
                      : 'No vehicle selected',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
            Row(
              children: [
                Tooltip(
                  message: 'PDF available after the enquiry is created',
                  child: OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 14),
                    label: const Text('PDF after create',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Quotation email will be dispatched on creation.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.email_outlined, size: 14),
                  label: const Text('Email',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isCalculating)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child:
                LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          ),

        // The Official Yash Honda Quotation Paper Card
        Expanded(
          child: SingleChildScrollView(
            child: Builder(
              builder: (context) {
                final mgName = (_selectedVehicle?['modelGroup']?['name'] ?? '')
                    .toString()
                    .toLowerCase();
                final catName = (_selectedVehicle?['category'] ?? '')
                    .toString()
                    .toLowerCase();
                final isBigWing =
                    mgName.contains('big') || catName.contains('big');
                final accentColor = isBigWing
                    ? const Color(0xFFD97706)
                    : const Color(0xFFCC0000);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dealership Title & Official Honda Wing Header
                      Container(
                        padding: isBigWing
                            ? const EdgeInsets.all(14)
                            : EdgeInsets.zero,
                        decoration: isBigWing
                            ? BoxDecoration(
                                color: const Color(0xFF0B0D12),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yash Honda',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isBigWing
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFCC0000),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    branchAddress,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: isBigWing
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF64748B)),
                                  ),
                                  Text(
                                    'GSTIN: $gstin',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: isBigWing
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBigWing
                                        ? 'Authorised BigWing Dealer · Pune'
                                        : 'Authorised Dealer · Pune',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isBigWing
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFCC0000)),
                                  ),
                                ],
                              ),
                            ),
                            // Honda Wing Official Dealership Badge
                            _buildQuoteLogo(isBigWing: isBigWing),
                          ],
                        ),
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),

                      // Metadata Grid: Quote No, Date, Customer, Mobile
                      Row(
                        children: [
                          Expanded(child: _buildMetaCell('Quote No.', 'Draft')),
                          Expanded(
                              child: _buildMetaCell(
                                  'Date',
                                  DateFormat('dd MMM yyyy')
                                      .format(DateTime.now()))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildMetaCell('Customer', customerName)),
                          Expanded(
                              child: _buildMetaCell('Mobile', customerMobile)),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),

                      // Model, Colour & Purchase Mode
                      Row(
                        children: [
                          Text(
                            _selectedVehicle != null ? vehicleName : '—',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Color: ${_selectedColour ?? '—'}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mode: $_purchaseMode',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_selectedVehicle == null) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  size: 20, color: Color(0xFFDC2626)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No vehicle selected',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Choose a model from the left to calculate real-time on-road prices, road tax, and insurance.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Itemized Price List
                        _buildPriceRow('Ex-showroom',
                            CurrencyFormatter.format(exShowroom)),
                        _buildPriceRow(
                            'Road Tax', CurrencyFormatter.format(roadTax)),
                        _buildPriceRow(
                            'Insurance', CurrencyFormatter.format(insurance)),
                        _buildPriceRow('Standard Accessories',
                            CurrencyFormatter.format(stdAccessories)),

                        // Add-on Accessories List
                        ...calcAccessories.map((acc) {
                          final rawAmt = acc['amount'];
                          final amt = rawAmt is num
                              ? rawAmt.toDouble()
                              : (double.tryParse(rawAmt?.toString() ?? '') ??
                                  0.0);
                          return _buildPriceRow(acc['name'] ?? 'Accessory',
                              CurrencyFormatter.format(amt));
                        }),

                        // Hypothecation Charge if Finance
                        if (_purchaseMode == 'Finance' &&
                            (double.tryParse(
                                        _hypothecationController.text.trim()) ??
                                    0) >
                                0)
                          _buildPriceRow(
                            'Hypothecation Charge',
                            CurrencyFormatter.format(
                              double.tryParse(
                                      _hypothecationController.text.trim()) ??
                                  0,
                            ),
                          ),
                      ],

                      const Divider(height: 20, color: Color(0xFFE2E8F0)),

                      // Grand Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grand Total',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: accentColor),
                          ),
                          Text(
                            CurrencyFormatter.format(grandTotal),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: accentColor),
                          ),
                        ],
                      ),

                      // Finance Options Box (If Finance selected)
                      if (_purchaseMode == 'Finance') ...[
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        const Text(
                          'Finance Option',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                                child: _buildEmiBox(
                                    'Down Payment',
                                    _downPaymentController.text
                                            .trim()
                                            .isNotEmpty
                                        ? CurrencyFormatter.format(
                                            double.tryParse(
                                                    _downPaymentController.text
                                                        .trim()) ??
                                                0)
                                        : '—')),
                            Expanded(
                                child: _buildEmiBox(
                                    'EMI · 24m',
                                    _emi24Controller.text.trim().isNotEmpty
                                        ? CurrencyFormatter.format(
                                            double.tryParse(_emi24Controller
                                                    .text
                                                    .trim()) ??
                                                0)
                                        : '—')),
                            Expanded(
                                child: _buildEmiBox(
                                    'EMI · 36m',
                                    _emi36Controller.text.trim().isNotEmpty
                                        ? CurrencyFormatter.format(
                                            double.tryParse(_emi36Controller
                                                    .text
                                                    .trim()) ??
                                                0)
                                        : '—')),
                            Expanded(
                                child: _buildEmiBox(
                                    'EMI · 48m',
                                    _emi48Controller.text.trim().isNotEmpty
                                        ? CurrencyFormatter.format(
                                            double.tryParse(_emi48Controller
                                                    .text
                                                    .trim()) ??
                                                0)
                                        : '—')),
                          ],
                        ),
                      ],

                      const Divider(height: 20, color: Color(0xFFE2E8F0)),

                      // Payment Section & QR Code
                      const Text(
                        'Payment',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBankRow('Bank', bankName),
                                _buildBankRow('Account', accountNo),
                                _buildBankRow('IFSC', ifsc),
                                _buildBankRow('UPI', upiId),
                              ],
                            ),
                          ),
                          // UPI QR Code Card from Company Profile (or dynamic scan & pay QR)
                          _buildQuoteQrCode(upiId, grandTotal),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Prices indicative and subject to change. Insurance as applicable. Delivery subject to availability. Exchange value declared by customer and recorded for reference only. E&OE.',
                        style: TextStyle(
                            fontSize: 8, color: Color(0xFF94A3B8), height: 1.3),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
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

  Widget _buildQuoteLogo({bool isBigWing = false}) {
    if (isBigWing) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 68, maxWidth: 150),
        alignment: Alignment.centerRight,
        child: Image.asset(
          'assets/honda_bigwing_logo.png',
          height: 58,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const HondaWingLogo(),
        ),
      );
    }
    final logoUrl = _settings?['logoUrl']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 60, maxWidth: 140),
        alignment: Alignment.centerRight,
        child: _buildBrandingImage(logoUrl, fallback: const HondaWingLogo()),
      );
    }
    return const HondaWingLogo();
  }

  Widget _buildQuoteQrCode(String upiId, double grandTotal) {
    final upiQrUrl = _settings?['upiQrUrl']?.toString();
    if (upiQrUrl != null && upiQrUrl.isNotEmpty) {
      return Tooltip(
        message: 'Official dealership UPI QR code for advance payment',
        child: Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBrandingImage(
            upiQrUrl,
            fallback: _buildDynamicUpiQr(upiId, grandTotal),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Scan & Pay via UPI ($upiId)',
      child: Container(
        width: 58,
        height: 58,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildDynamicUpiQr(upiId, grandTotal),
      ),
    );
  }

  Widget _buildDynamicUpiQr(String upiId, double grandTotal) {
    final qrApiUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=upi://pay?pa=${Uri.encodeComponent(upiId)}%26pn=Yash%20Honda%26am=$grandTotal';
    return Image.network(
      qrApiUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Center(
        child:
            Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildMetaCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
          Text(amount,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildFinancingInput({
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: (val) {
            setState(() {});
            onChanged?.call(val);
          },
        ),
      ],
    );
  }

  Widget _buildEmiBox(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
        Text(amount,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
              width: 50,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 9.5, color: Color(0xFF64748B)))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  Widget _buildBottomFooterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveEnquiry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('+ Create Enquiry',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.normal),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    String? hintText,
    bool highlightBorder = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlightBorder ? AppColors.brand : AppColors.border,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hintText != null
                  ? Text(hintText,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.secondary))
                  : null,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeSegment(String id, String label) {
    final isSelected = _exchange == id;
    return InkWell(
      onTap: () => setState(() => _exchange = id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(
      String label, bool value, void Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class HondaWingLogo extends StatelessWidget {
  const HondaWingLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: const Size(46, 22),
          painter: _HondaWingPainter(),
        ),
        const SizedBox(height: 2),
        const Text(
          'HONDA',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Color(0xFFCC0000),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HondaWingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCC0000)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Feather 1 (Top / longest curved wing feather)
    final p1 = Path();
    p1.moveTo(size.width * 0.1, size.height * 0.95);
    p1.quadraticBezierTo(size.width * 0.5, size.height * 0.35,
        size.width * 0.98, size.height * 0.05);
    p1.quadraticBezierTo(size.width * 0.65, size.height * 0.25,
        size.width * 0.35, size.height * 0.65);
    p1.close();
    canvas.drawPath(p1, paint);

    // Feather 2 (Middle curved feather)
    final p2 = Path();
    p2.moveTo(size.width * 0.05, size.height * 0.95);
    p2.quadraticBezierTo(size.width * 0.45, size.height * 0.55,
        size.width * 0.85, size.height * 0.28);
    p2.quadraticBezierTo(size.width * 0.55, size.height * 0.45,
        size.width * 0.25, size.height * 0.78);
    p2.close();
    canvas.drawPath(p2, paint);

    // Feather 3 (Bottom curved feather)
    final p3 = Path();
    p3.moveTo(0, size.height * 0.95);
    p3.quadraticBezierTo(size.width * 0.35, size.height * 0.75,
        size.width * 0.70, size.height * 0.52);
    p3.quadraticBezierTo(size.width * 0.45, size.height * 0.65,
        size.width * 0.15, size.height * 0.90);
    p3.close();
    canvas.drawPath(p3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
