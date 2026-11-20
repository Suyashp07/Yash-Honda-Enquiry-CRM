import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/auth_notifier.dart';

class CustomizeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;

  const CustomizeScreen({super.key, this.vehicle = const {}});

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
  final _exchangeExpectedController = TextEditingController();

  // Master Data Lists
  List<dynamic> _vehicles = [];
  List<dynamic> _branches = [];
  List<dynamic> _accessories = [];
  List<dynamic> _financiers = [];
  List<dynamic> _areas = [];
  List<dynamic> _leadSources = [];
  List<dynamic> _salesReps = [];
  Map<String, dynamic>? _settings;

  // Selected State
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;
  String _selectedColour = 'Black';
  String? _selectedBranchId;
  String _selectedType = 'Walk-in';
  String? _selectedSourceId;
  String? _selectedAreaId;
  String? _selectedRepId;
  String _purchaseMode = 'Cash';
  String? _selectedFinancierId;
  String _buyingWhen = 'Immediate';
  String _exchange = 'no'; // 'no', 'yes', 'yes_print'

  final Set<String> _selectedAccessoryIds = {};
  bool _sendEmail = false;
  bool _sendWhatsApp = false;
  bool _marketingConsent = true;

  bool _isLoadingMasters = true;
  bool _isCalculating = false;
  Map<String, dynamic>? _liveCalculation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Listen to text changes for immediate dynamic update of the Quote Preview!
    _nameController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));

    _loadAllMasters();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    _exchangeMakeModelController.dispose();
    _exchangeYearController.dispose();
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
      final reps = users.where((u) => u['role'] == 'SALES_EXEC' || u['role'] == 'BRANCH_MANAGER').toList();

      // Initial vehicle selection
      Map<String, dynamic>? initialVehicle;
      if (widget.vehicle.isNotEmpty && widget.vehicle['id'] != null) {
        initialVehicle = widget.vehicle;
      } else if (vehicles.isNotEmpty) {
        initialVehicle = vehicles.first;
      }

      String? initialVehicleId = initialVehicle?['id']?.toString();
      String initialColour = 'Black';
      final vColours = (initialVehicle?['colours'] as List?) ?? [];
      if (vColours.isNotEmpty) {
        initialColour = vColours.first['colour']?['name'] ?? 'Black';
      }

      // Initial branch selection
      final user = ref.read(authStateProvider).user;
      String? initialBranchId;
      if (user != null && user.branches.isNotEmpty) {
        initialBranchId = user.branches.first.id;
      } else if (branches.isNotEmpty) {
        initialBranchId = branches.first['id'].toString();
      }

      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _branches = branches;
        _settings = settings;
        _accessories = accessories;
        _financiers = financiers;
        _areas = areas;
        _leadSources = leadSources;
        _salesReps = reps;

        _selectedVehicle = initialVehicle;
        _selectedVehicleId = initialVehicleId;
        _selectedColour = initialColour;
        _selectedBranchId = initialBranchId;

        if (leadSources.isNotEmpty) _selectedSourceId = leadSources.first['id'].toString();
        if (areas.isNotEmpty) _selectedAreaId = areas.first['id'].toString();
        if (reps.isNotEmpty) _selectedRepId = reps.first['id'].toString();
        if (financiers.isNotEmpty) _selectedFinancierId = financiers.first['id'].toString();

        _isLoadingMasters = false;
      });

      _calculateQuote();
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
    setState(() => _isCalculating = true);

    try {
      final dio = ref.read(dioProvider);
      final accList = _selectedAccessoryIds.map((id) => {'accessoryId': id}).toList();

      final res = await dio.post('/quotations/calculate', data: {
        'vehicleId': _selectedVehicleId,
        'branchId': _selectedBranchId,
        'colourName': _selectedColour,
        'purchaseMode': _purchaseMode,
        'accessories': accList,
      });

      if (!mounted) return;
      setState(() {
        _liveCalculation = res.data;
        _isCalculating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCalculating = false);
    }
  }

  void _onVehicleChanged(String? newVehicleId) {
    if (newVehicleId == null) return;
    final found = _vehicles.firstWhere((v) => v['id'].toString() == newVehicleId, orElse: () => null);
    if (found != null) {
      String newColour = 'Black';
      final vColours = (found['colours'] as List?) ?? [];
      if (vColours.isNotEmpty) {
        newColour = vColours.first['colour']?['name'] ?? 'Black';
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
        const SnackBar(content: Text('Please enter a valid 10-digit Mobile Number')),
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
      final accList = _selectedAccessoryIds.map((id) => {'accessoryId': id}).toList();

      final res = await dio.post('/enquiries', data: {
        'branchId': _selectedBranchId,
        'customer': {
          'name': name,
          'mobile': mobile,
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'areaId': _selectedAreaId,
        },
        'enquiryType': _selectedType,
        'leadSourceId': _selectedSourceId,
        'assignedToId': _selectedRepId,
        'purchaseMode': _purchaseMode,
        'financierId': _purchaseMode == 'Finance' ? _selectedFinancierId : null,
        'exchange': _exchange == 'yes_print' ? 'Yes & Print' : (_exchange == 'yes' ? 'Yes' : 'No'),
        'buyingWhen': _buyingWhen,
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        'quotation': {
          'vehicleId': _selectedVehicleId,
          'colourName': _selectedColour,
          'accessories': accList,
        },
      });

      final enquiry = res.data;
      final quotation = (enquiry['quotations'] as List?)?.first ?? {};

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
              Text('Initializing Enquiry & Live Quotation Engine...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

          // Center Top Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.format(grandTotal),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
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

        // Row 2: Type, Source, Area, Sales Executive
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Type',
                value: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'Walk-in', child: Text('Walk-in')),
                  DropdownMenuItem(value: 'Telephonic', child: Text('Telephonic')),
                  DropdownMenuItem(value: 'Online', child: Text('Online / Web')),
                ],
                onChanged: (val) => setState(() => _selectedType = val ?? 'Walk-in'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Source',
                value: _selectedSourceId,
                items: _leadSources.map((ls) {
                  return DropdownMenuItem(value: ls['id'].toString(), child: Text(ls['name']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedSourceId = val),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Area',
                value: _selectedAreaId,
                items: _areas.map((a) {
                  return DropdownMenuItem(value: a['id'].toString(), child: Text(a['name']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedAreaId = val),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Sales Executive',
                value: _selectedRepId,
                items: _salesReps.map((r) {
                  return DropdownMenuItem(value: r['id'].toString(), child: Text(r['name']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedRepId = val),
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
                items: _vehicles.map((v) {
                  return DropdownMenuItem(value: v['id'].toString(), child: Text(v['name']));
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
                highlightBorder: true,
                items: vColours.isEmpty
                    ? <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(value: 'Black', child: Text('Black'))
                      ]
                    : vColours.map<DropdownMenuItem<String>>((vc) {
                        final cName = vc['colour']?['name']?.toString() ?? 'Black';
                        return DropdownMenuItem<String>(value: cName, child: Text(cName));
                      }).toList(),
                onChanged: (val) {
                  setState(() => _selectedColour = val ?? 'Black');
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
                  DropdownMenuItem(value: 'Finance', child: Text('Finance (Loan)')),
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
                hintText: _purchaseMode == 'Finance' ? 'Select financier' : 'N/A (Cash)',
                items: _financiers.map((f) {
                  return DropdownMenuItem(value: f['id'].toString(), child: Text(f['name']));
                }).toList(),
                onChanged: _purchaseMode == 'Finance'
                    ? (val) => setState(() => _selectedFinancierId = val)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Row 4: Buying When & Branch Selector (if multiple)
        Row(
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Buying When',
                value: _buyingWhen,
                items: const [
                  DropdownMenuItem(value: 'Immediate', child: Text('Immediate')),
                  DropdownMenuItem(value: 'Within 7 Days', child: Text('Within 7 Days')),
                  DropdownMenuItem(value: 'Within 15 Days', child: Text('Within 15 Days')),
                  DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                ],
                onChanged: (val) => setState(() => _buyingWhen = val ?? 'Immediate'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Showroom Branch',
                value: _selectedBranchId,
                items: _branches.map((b) {
                  final wing = b['wing'] ?? (b['code'].toString().startsWith('BW') ? 'BigWing' : 'RedWing');
                  return DropdownMenuItem(value: b['id'].toString(), child: Text('[$wing] ${b['name']}'));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedBranchId = val);
                  _calculateQuote();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ADD-ONS Section
        const Text(
          'ADD-ONS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFFFEF2F2) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isChecked ? AppColors.primary : const Color(0xFFE2E8F0),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
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
                        color: isChecked ? AppColors.primary : const Color(0xFF334155),
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
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
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
            _buildCheckboxOption('Send by email', _sendEmail, (v) => setState(() => _sendEmail = v ?? false)),
            const SizedBox(width: 16),
            _buildCheckboxOption('Send by WhatsApp', _sendWhatsApp, (v) => setState(() => _sendWhatsApp = v ?? false)),
            const SizedBox(width: 16),
            _buildCheckboxOption('Marketing consent', _marketingConsent, (v) => setState(() => _marketingConsent = v ?? true)),
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

    final gstin = _settings?['gstNumber'] ?? '27AABCY1234F1Z5';
    final bankName = _settings?['bankName'] ?? 'HDFC Bank';
    final accountNo = _settings?['accountNumber'] ?? '50200012345678';
    final ifsc = _settings?['ifsc'] ?? 'HDFC0001234';
    final upiId = _settings?['upiId'] ?? 'yashhonda@hdfcbank';

    final rawEx = _liveCalculation?['exShowroom'];
    final exShowroom = rawEx is num ? rawEx.toDouble() : (double.tryParse(rawEx?.toString() ?? '') ?? 0.0);

    final rawTax = _liveCalculation?['roadTax'];
    final roadTax = rawTax is num ? rawTax.toDouble() : (double.tryParse(rawTax?.toString() ?? '') ?? 0.0);

    final rawIns = _liveCalculation?['insurance'];
    final insurance = rawIns is num ? rawIns.toDouble() : (double.tryParse(rawIns?.toString() ?? '') ?? 0.0);

    final rawStd = _liveCalculation?['stdAccessories'];
    final stdAccessories = rawStd is num ? rawStd.toDouble() : (double.tryParse(rawStd?.toString() ?? '') ?? 1800.0);

    final rawTotal = _liveCalculation?['grandTotal'];
    final grandTotal = rawTotal is num ? rawTotal.toDouble() : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0);

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
                const Text(
                  'Quote Preview (live)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                Text(
                  vehicleName,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rendering print-ready quotation PDF preview...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: const Text('View PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quotation email will be dispatched on creation.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.email_outlined, size: 14),
                  label: const Text('Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isCalculating)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          ),

        // The Official Yash Honda Quotation Paper Card
        Expanded(
          child: SingleChildScrollView(
            child: Container(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yash Honda',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFCC0000),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              branchAddress,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                            ),
                            Text(
                              'GSTIN: $gstin',
                              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Authorised Dealer · Pune',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFCC0000)),
                            ),
                          ],
                        ),
                      ),
                      // Honda Wing Official Dealership Badge or Custom Uploaded Logo from Company Profile
                      _buildQuoteLogo(),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  // Metadata Grid: Quote No, Date, Customer, Mobile
                  Row(
                    children: [
                      Expanded(child: _buildMetaCell('Quote No.', 'Draft')),
                      Expanded(child: _buildMetaCell('Date', DateFormat('dd MMM yyyy').format(DateTime.now()))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetaCell('Customer', customerName)),
                      Expanded(child: _buildMetaCell('Mobile', customerMobile)),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  // Model, Colour & Purchase Mode
                  Row(
                    children: [
                      Text(
                        vehicleName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Color: $_selectedColour',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mode: $_purchaseMode',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Itemized Price List
                  _buildPriceRow('Ex-showroom', CurrencyFormatter.format(exShowroom)),
                  _buildPriceRow('Road Tax', CurrencyFormatter.format(roadTax)),
                  _buildPriceRow('Insurance', CurrencyFormatter.format(insurance)),
                  _buildPriceRow('Standard Accessories', CurrencyFormatter.format(stdAccessories)),

                  // Add-on Accessories List
                  ...calcAccessories.map((acc) {
                    final rawAmt = acc['amount'];
                    final amt = rawAmt is num ? rawAmt.toDouble() : (double.tryParse(rawAmt?.toString() ?? '') ?? 0.0);
                    return _buildPriceRow(acc['name'] ?? 'Accessory', CurrencyFormatter.format(amt));
                  }),

                  // Hypothecation Charge if Finance
                  if (_purchaseMode == 'Finance')
                    _buildPriceRow('Hypothecation Charge', '₹1,500'),

                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  // Grand Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFCC0000)),
                      ),
                      Text(
                        CurrencyFormatter.format(grandTotal),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFCC0000)),
                      ),
                    ],
                  ),

                  // Finance Options Box (If Finance selected)
                  if (_purchaseMode == 'Finance') ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    const Text(
                      'Finance Option',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _buildEmiBox('Down Payment', CurrencyFormatter.format(grandTotal * 0.20))),
                        Expanded(child: _buildEmiBox('EMI · 24m', CurrencyFormatter.format((grandTotal * 0.80 * 1.12) / 24))),
                        Expanded(child: _buildEmiBox('EMI · 36m', CurrencyFormatter.format((grandTotal * 0.80 * 1.18) / 36))),
                        Expanded(child: _buildEmiBox('EMI · 48m', CurrencyFormatter.format((grandTotal * 0.80 * 1.24) / 48))),
                      ],
                    ),
                  ],

                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  // Payment Section & QR Code
                  const Text(
                    'Payment',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
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
                  const SizedBox(height: 8),
        if (_isCalculating)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
          ),

                  // Legal Disclaimer
                  const Text(
                    'Prices indicative and subject to change. Insurance as applicable. Delivery subject to availability. Exchange value declared by customer and recorded for reference only. E&OE.',
                    style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8), height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConstants.baseUrl.endsWith('/api')
        ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 4)
        : ApiConstants.baseUrl;
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }

  Widget _buildQuoteLogo() {
    final logoUrl = _settings?['logoUrl']?.toString();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 38, maxWidth: 110),
        alignment: Alignment.centerRight,
        child: Image.network(
          _resolveImageUrl(logoUrl),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const HondaWingLogo(),
        ),
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
          child: Image.network(
            _resolveImageUrl(upiQrUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildDynamicUpiQr(upiId, grandTotal),
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
        child: Icon(Icons.qr_code_2_rounded, size: 36, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildMetaCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
          Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
          Text(amount, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildEmiBox(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
        Text(amount, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveEnquiry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+ Create', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 8),
                      Text(
                        'Ctrl Enter',
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: highlightBorder ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hintText != null ? Text(hintText, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))) : null,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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

  Widget _buildCheckboxOption(String label, bool value, void Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
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
    p1.quadraticBezierTo(size.width * 0.5, size.height * 0.35, size.width * 0.98, size.height * 0.05);
    p1.quadraticBezierTo(size.width * 0.65, size.height * 0.25, size.width * 0.35, size.height * 0.65);
    p1.close();
    canvas.drawPath(p1, paint);

    // Feather 2 (Middle curved feather)
    final p2 = Path();
    p2.moveTo(size.width * 0.05, size.height * 0.95);
    p2.quadraticBezierTo(size.width * 0.45, size.height * 0.55, size.width * 0.85, size.height * 0.28);
    p2.quadraticBezierTo(size.width * 0.55, size.height * 0.45, size.width * 0.25, size.height * 0.78);
    p2.close();
    canvas.drawPath(p2, paint);

    // Feather 3 (Bottom curved feather)
    final p3 = Path();
    p3.moveTo(0, size.height * 0.95);
    p3.quadraticBezierTo(size.width * 0.35, size.height * 0.75, size.width * 0.70, size.height * 0.52);
    p3.quadraticBezierTo(size.width * 0.45, size.height * 0.65, size.width * 0.15, size.height * 0.90);
    p3.close();
    canvas.drawPath(p3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
