import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/file_download.dart';
import '../admin/widgets/configurator_media_dialogs.dart';
import '../auth/auth_notifier.dart';

class BuildMyHondaScreen extends ConsumerStatefulWidget {
  final String? initialRepId;
  const BuildMyHondaScreen({super.key, this.initialRepId});

  @override
  ConsumerState<BuildMyHondaScreen> createState() => _BuildMyHondaScreenState();
}

class _BuildMyHondaScreenState extends ConsumerState<BuildMyHondaScreen> {
  // 1: Choose Ride, 2: Vehicle, 3: Colour, 4: Accessories, 5: Finance, 6: Exchange, 7: Summary
  int _currentStep = 1;

  // Step 1-2 Selection State (Start fresh — nothing pre-selected)
  String? _selectedCategory; // 'MC' | 'Scooter' | 'BigBike'
  String _selectedCcFilter = 'All';
  bool _showOnRoadPrice = false;
  Map<String, dynamic>? _selectedVehicle;
  final ScrollController _vehicleCarouselCtrl = ScrollController();
  int _carouselDotIndex = 0;

  // Step 3 Colour State
  String _selectedColourName = 'Sports Red';
  Color _selectedColourValue = const Color(0xFFDC2626);
  String? _selectedColourImageUrl;

  // Step 4 Accessories State (admin-controlled Standard vs Optional)
  final Set<String> _selectedOptionalAccessoryIds = {};

  // Step 5 Finance State (Display only — does not affect price per spec)
  String _paymentMode = 'Cash'; // 'Cash' | 'Finance'
  String _selectedFinanceType = 'Bank Loan';
  String? _selectedFinancierId;
  String? _selectedFinancierName;

  // Step 6 Exchange State
  bool _wantExchange = false;
  final _exchangeModelController = TextEditingController();
  String _exchangeYear = 'Select Year';
  final _exchangeKmsController = TextEditingController();
  final _exchangeOfferedPriceController = TextEditingController();
  final _exchangeExpectedPriceController = TextEditingController();

  // Step 7 Customer Info & Generated Quote Cache
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _customerEmailController = TextEditingController();
  String? _selectedBranchId;
  String? _selectedRepId;
  bool _isSubmitting = false;
  String? _createdEnquiryId;
  String? _createdQuotationId;
  String? _createdQuoteNumber;

  // Backend Data Collections
  bool _isLoadingCatalog = true;
  List<Map<String, dynamic>> _backendVehicles = [];
  List<Map<String, dynamic>> _backendAccessories = [];
  List<Map<String, dynamic>> _backendFinanciers = [];
  List<Map<String, dynamic>> _backendBranches = [];
  List<Map<String, dynamic>> _backendColours = [];

  final List<Map<String, dynamic>> _fallbackCatalog = [
    {
      'id': 'v-shine125',
      'name': 'Shine 125 Disc',
      'code': 'SHN125',
      'category': 'MC',
      'ccDisplacement': 125,
      'exShowroomPrice': 84000,
      'onRoadPrice': 99500,
      'colours': [
        {'name': 'Rebel Red Metallic', 'hex': '#DC2626'},
        {'name': 'Pearl Nightstar Black', 'hex': '#111827'},
        {'name': 'Decent Blue Metallic', 'hex': '#2563EB'},
      ],
    },
    {
      'id': 'v-sp125',
      'name': 'SP 125 Disc',
      'code': 'SP125',
      'category': 'MC',
      'ccDisplacement': 125,
      'exShowroomPrice': 90000,
      'onRoadPrice': 106000,
      'colours': [
        {'name': 'Pearl Siren Blue', 'hex': '#1E3A8A'},
        {'name': 'Matte Axis Grey Metallic', 'hex': '#4B5563'},
        {'name': 'Pearl Nightstar Black', 'hex': '#111827'},
      ],
    },
    {
      'id': 'v-activa110',
      'name': 'Activa 110 Dlx',
      'code': 'ACT110DLX',
      'category': 'Scooter',
      'ccDisplacement': 110,
      'exShowroomPrice': 82450,
      'onRoadPrice': 100380,
      'colours': [
        {'name': 'Black', 'hex': '#111827'},
        {'name': 'Pearl Siren Blue', 'hex': '#1E3A8A'},
        {'name': 'Rebel Red Metallic', 'hex': '#DC2626'},
        {'name': 'Pearl Night White', 'hex': '#F8FAFC'},
      ],
    },
    {
      'id': 'v-activa6g',
      'name': 'Activa 6G DLX',
      'code': 'ACT6G',
      'category': 'Scooter',
      'ccDisplacement': 110,
      'exShowroomPrice': 79000,
      'onRoadPrice': 94500,
      'colours': [
        {'name': 'Pearl Siren Blue', 'hex': '#1E3A8A'},
        {'name': 'Rebel Red Metallic', 'hex': '#DC2626'},
        {'name': 'Pearl Night White', 'hex': '#F8FAFC'},
      ],
    },
    {
      'id': 'v-dio125',
      'name': 'Dio 125 Smart',
      'code': 'DIO125',
      'category': 'Scooter',
      'ccDisplacement': 125,
      'exShowroomPrice': 85000,
      'onRoadPrice': 101000,
      'colours': [
        {'name': 'Matte Axis Grey Metallic', 'hex': '#4B5563'},
        {'name': 'Pearl Siren Blue', 'hex': '#1E3A8A'},
        {'name': 'Rebel Red Metallic', 'hex': '#DC2626'},
      ],
    },
    {
      'id': 'v-cb350h',
      'name': 'Hness CB350 DLX Pro',
      'code': 'CB350H',
      'category': 'BigBike',
      'ccDisplacement': 350,
      'exShowroomPrice': 215000,
      'onRoadPrice': 262000,
      'colours': [
        {'name': 'Pearl Nightstar Black', 'hex': '#111827'},
        {'name': 'Rebel Red Metallic', 'hex': '#DC2626'},
        {'name': 'Decent Blue Metallic', 'hex': '#2563EB'},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedRepId = widget.initialRepId;
    _vehicleCarouselCtrl.addListener(_onCarouselScroll);
    _fetchBackendData();
  }

  void _onCarouselScroll() {
    if (!_vehicleCarouselCtrl.hasClients) return;
    final idx = (_vehicleCarouselCtrl.offset / 285).round().clamp(0, 10);
    if (idx != _carouselDotIndex) {
      setState(() => _carouselDotIndex = idx);
    }
  }

  @override
  void dispose() {
    _vehicleCarouselCtrl.dispose();
    _exchangeModelController.dispose();
    _exchangeKmsController.dispose();
    _exchangeOfferedPriceController.dispose();
    _exchangeExpectedPriceController.dispose();
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _customerEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchBackendData() async {
    try {
      final dio = ref.read(dioProvider);
      Map<String, dynamic>? data;

      try {
        final bootRes = await dio.get('/vehicles/configurator-bootstrap');
        if (bootRes.data is Map<String, dynamic>) {
          data = bootRes.data as Map<String, dynamic>;
        }
      } catch (_) {
        // Fallback for authenticated sessions if bootstrap endpoint isn't deployed yet
        final results = await Future.wait([
          dio.get('/vehicles').catchError((_) =>
              Response(requestOptions: RequestOptions(path: ''), data: [])),
          dio.get('/accessories').catchError((_) =>
              Response(requestOptions: RequestOptions(path: ''), data: [])),
          dio.get('/financiers').catchError((_) =>
              Response(requestOptions: RequestOptions(path: ''), data: [])),
          dio.get('/branches').catchError((_) =>
              Response(requestOptions: RequestOptions(path: ''), data: [])),
          dio.get('/vehicles/colours').catchError((_) =>
              Response(requestOptions: RequestOptions(path: ''), data: [])),
        ]);
        data = {
          'vehicles': results[0].data is List ? results[0].data : [],
          'accessories': results[1].data is List ? results[1].data : [],
          'financiers': results[2].data is List ? results[2].data : [],
          'branches': results[3].data is List ? results[3].data : [],
          'colours': results[4].data is List ? results[4].data : [],
        };
      }

      if (!mounted || data == null) return;

      final rawVehicles = (data['vehicles'] as List? ?? []);
      final rawAccessories = (data['accessories'] as List? ?? []);
      final rawFinanciers = (data['financiers'] as List? ?? []);
      final rawBranches = (data['branches'] as List? ?? []);
      final rawColours = (data['colours'] as List? ?? []);

      setState(() {
        _backendVehicles = rawVehicles.map((raw) {
          final bv = Map<String, dynamic>.from(raw as Map);
          final code = bv['code']?.toString() ?? '';
          final nameStr = bv['name']?.toString() ?? 'Honda Vehicle';
          final exShow =
              double.tryParse(bv['exShowroomPrice']?.toString() ?? '0') ??
                  68767;
          final onRoad =
              double.tryParse(bv['onRoadPrice']?.toString() ?? '0') ??
                  (exShow * 1.18);

          final normCat = bv['normalizedCategory']?.toString() ??
              _normalizeCategory(bv['category']?.toString(),
                  bv['modelGroup']?['name']?.toString());

          final parsedColours = <Map<String, dynamic>>[];
          if (bv['colours'] is List) {
            for (final rel in bv['colours']) {
              final cObj = rel['colour'];
              if (cObj != null) {
                parsedColours.add({
                  'id': cObj['id']?.toString() ?? '',
                  'name': cObj['name']?.toString() ?? 'Standard',
                  'hex': cObj['hex']?.toString() ?? '#111827',
                  'colourImageUrl': rel['colourImageUrl']?.toString(),
                });
              }
            }
          }

          int? ccVal = bv['ccDisplacement'] is int
              ? bv['ccDisplacement'] as int
              : int.tryParse(bv['ccDisplacement']?.toString() ?? '');
          ccVal ??= _inferCcFromCode(code, nameStr);

          return {
            'id': bv['id']?.toString() ?? code,
            'code': code,
            'name': nameStr,
            'category': normCat,
            'modelGroup': bv['modelGroup']?['name']?.toString() ?? 'RedWing',
            'ccDisplacement': ccVal,
            'exShowroomPrice': exShow,
            'onRoadPrice': onRoad,
            'listingImageUrl': bv['listingImageUrl']?.toString(),
            'detailImageUrl': bv['detailImageUrl']?.toString(),
            'wordmarkImageUrl': bv['wordmarkImageUrl']?.toString(),
            'brochureUrl': bv['brochureUrl']?.toString(),
            'colours': parsedColours,
          };
        }).toList();

        _backendAccessories = rawAccessories
            .map((raw) {
              final acc = Map<String, dynamic>.from(raw as Map);
              return {
                'id': acc['id']?.toString() ?? '',
                'name': acc['name']?.toString() ?? '',
                'price':
                    double.tryParse(acc['defaultPrice']?.toString() ?? '0') ??
                        0,
                'isStandard': acc['isStandard'] == true,
                'imageUrl': acc['imageUrl']?.toString(),
                'isPriceEditable': acc['isPriceEditable'] == true,
              };
            })
            .where((a) => a['name'].toString().isNotEmpty)
            .toList();

        _backendFinanciers = rawFinanciers
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (_backendFinanciers.isNotEmpty) {
          _selectedFinancierId = _backendFinanciers.first['id']?.toString();
          _selectedFinancierName = _backendFinanciers.first['name']?.toString();
        }

        _backendBranches = rawBranches
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (_backendBranches.isNotEmpty) {
          final activeBranch = ref.read(selectedBranchIdProvider);
          final matching = _backendBranches.any((b) => b['id'] == activeBranch);
          _selectedBranchId = matching
              ? activeBranch
              : _backendBranches.first['id']?.toString();
        }

        _backendColours =
            rawColours.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  int? _inferCcFromCode(String code, String name) {
    final s = '$code $name'.toUpperCase();
    if (s.contains('350')) return 350;
    if (s.contains('300')) return 300;
    if (s.contains('200')) return 200;
    if (s.contains('160')) return 160;
    if (s.contains('150')) return 150;
    if (s.contains('125')) return 125;
    if (s.contains('110') || s.contains('6G')) return 110;
    if (s.contains('100')) return 100;
    return null;
  }

  String _normalizeCategory(String? rawCat, String? modelGroupName) {
    final c = (rawCat ?? '').toLowerCase();
    final mg = (modelGroupName ?? '').toLowerCase();
    if (c.contains('scooter')) return 'Scooter';
    if (c.contains('big') || c.contains('wing') || mg.contains('big')) {
      return 'BigBike';
    }
    return 'MC';
  }

  Color _parseColor(String? hexStr) {
    if (hexStr == null || hexStr.isEmpty) return const Color(0xFFDC2626);
    var cleaned = hexStr.replaceAll('#', '').trim();
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    try {
      return Color(int.parse(cleaned, radix: 16));
    } catch (_) {
      return const Color(0xFFDC2626);
    }
  }

  List<Map<String, dynamic>> get _allSourceVehicles => _backendVehicles;

  List<Map<String, dynamic>> get _categoryPool {
    if (_selectedCategory == null) return [];
    return _allSourceVehicles
        .where((v) => v['category'] == _selectedCategory)
        .toList();
  }

  List<String> get _availableCcChips {
    final ccs = <int>{};
    for (final v in _categoryPool) {
      final cc = v['ccDisplacement'];
      if (cc is int && cc > 0) ccs.add(cc);
    }
    final sorted = ccs.toList()..sort();
    return ['All', ...sorted.map((c) => '$c CC')];
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    final pool = _categoryPool;
    if (_selectedCcFilter == 'All') return pool;
    final numOnly =
        int.tryParse(_selectedCcFilter.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numOnly == null) return pool;
    return pool.where((v) => v['ccDisplacement'] == numOnly).toList();
  }

  List<Map<String, dynamic>> get _effectiveAccessories => _backendAccessories;

  static const List<Map<String, dynamic>> _fallbackAccessories = [
    {
      'id': 'acc-ceramic',
      'name': 'Ceramic Coating (2-Year)',
      'price': 3500,
      'isStandard': false
    },
    {
      'id': 'acc-warranty',
      'name': 'Extended Warranty (3+3 Yrs)',
      'price': 2200,
      'isStandard': false
    },
    {
      'id': 'acc-helmet',
      'name': 'Helmet (Studds/Honda ISI)',
      'price': 1250,
      'isStandard': false
    },
    {
      'id': 'acc-seat',
      'name': 'Designer Seat Cover',
      'price': 650,
      'isStandard': false
    },
    {
      'id': 'acc-mat',
      'name': 'Floor Mat Premium',
      'price': 450,
      'isStandard': false
    },
    {
      'id': 'acc-rsa',
      'name': 'RSA (Roadside Assistance - 1 Yr)',
      'price': 1499,
      'isStandard': false
    },
  ];

  List<Map<String, dynamic>> get _standardAccessories =>
      _effectiveAccessories.where((a) => a['isStandard'] == true).toList();

  List<Map<String, dynamic>> get _optionalAccessories =>
      _effectiveAccessories.where((a) => a['isStandard'] != true).toList();

  double get _selectedOptionalAccessoriesTotal {
    double sum = 0;
    for (final acc in _optionalAccessories) {
      if (_selectedOptionalAccessoryIds.contains(acc['id'].toString())) {
        sum += ((acc['price'] ?? 0) as num).toDouble();
      }
    }
    return sum;
  }

  double get _vehicleBasePrice {
    if (_selectedVehicle == null) return 0;
    if (_showOnRoadPrice) {
      return ((_selectedVehicle!['onRoadPrice'] ?? 0) as num).toDouble();
    }
    return ((_selectedVehicle!['exShowroomPrice'] ?? 0) as num).toDouble();
  }

  double get _estimatedTotal {
    if (_selectedVehicle == null) return 0;
    return _vehicleBasePrice + _selectedOptionalAccessoriesTotal;
  }

  void _invalidateQuoteCache() {
    _createdEnquiryId = null;
    _createdQuotationId = null;
    _createdQuoteNumber = null;
  }

  void _selectVehicle(Map<String, dynamic> v, {bool advance = false}) {
    final cols = _getColoursForVehicle(v);
    final firstCol = cols.isNotEmpty ? cols.first : null;
    setState(() {
      _selectedVehicle = v;
      _selectedColourName = firstCol?['name']?.toString() ?? 'Sports Red';
      _selectedColourValue = _parseColor(firstCol?['hex']?.toString());
      _selectedColourImageUrl = firstCol?['colourImageUrl']?.toString();
      _invalidateQuoteCache();
    });
    if (advance) _nextStep();
  }

  List<Map<String, dynamic>> _getColoursForVehicle(Map<String, dynamic>? v) {
    final mapped = (v?['colours'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (mapped.isNotEmpty) return mapped;
    if (_backendColours.isNotEmpty) {
      return _backendColours.take(4).toList();
    }
    return [
      {'name': 'Sports Red', 'hex': '#DC2626'},
      {'name': 'Black', 'hex': '#111827'},
      {'name': 'Pearl Night White', 'hex': '#F1F5F9'},
      {'name': 'Pearl Siren Blue', 'hex': '#1D4ED8'},
    ];
  }

  /// Returns the listing image URL for a vehicle card in Step 2.
  /// Priority: backend listingImageUrl → detailImageUrl → null (show placeholder).
  String? _resolveListingImage(Map<String, dynamic> v) {
    final uploaded = v['listingImageUrl']?.toString();
    if (uploaded != null && uploaded.isNotEmpty) return uploaded;
    final detail = v['detailImageUrl']?.toString();
    if (detail != null && detail.isNotEmpty) return detail;
    return null; // No image uploaded → show placeholder
  }

  /// Returns the showcase image URL for Steps 3-7 large panel.
  /// Priority: per-colour backend image → vehicle detail → vehicle listing → null.
  String? _resolveShowcaseImage() {
    if (_selectedColourImageUrl != null &&
        _selectedColourImageUrl!.isNotEmpty) {
      return _selectedColourImageUrl!;
    }
    final detail = _selectedVehicle?['detailImageUrl']?.toString();
    if (detail != null && detail.isNotEmpty) return detail;
    final listing = _selectedVehicle?['listingImageUrl']?.toString();
    if (listing != null && listing.isNotEmpty) return listing;
    return null; // No image → show placeholder
  }

  /// Full-size, responsive showcase stage for Steps 3–7.
  /// Displays the backend per-colour / detail / listing image at maximum stage size,
  /// or a clean studio placeholder when no image has been uploaded in Admin Panel yet.
  Widget _buildShowcaseImageBox({bool animate = false}) {
    final imgUrl = _resolveShowcaseImage();
    final vName = _selectedVehicle?['name']?.toString() ?? 'Selected Vehicle';
    final placeholder = Container(
      width: double.infinity,
      height: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 340),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.two_wheeler_outlined,
                    size: 34, color: Color(0xFF94A3B8)),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _selectedColourValue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$vName · $_selectedColourName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No image uploaded for this colour yet.\nUpload in Admin Panel → Vehicle Masters → Media.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    final media = SmartMediaImage(
      key: ValueKey(
          '${_selectedVehicle?['id']}-$_selectedColourName-${imgUrl ?? 'none'}'),
      source: imgUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      fallback: Center(child: placeholder),
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Center(
          child: animate
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: media,
                )
              : media,
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 1 && _selectedCategory == null) return;
    if (_currentStep == 2 && _selectedVehicle == null) {
      if (_filteredVehicles.isNotEmpty) {
        _selectVehicle(_filteredVehicles.first);
      } else {
        return;
      }
    }
    if (_currentStep < 7) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Original Honda Wing watermark in background
            if (_currentStep <= 6)
              Positioned(
                top: 48,
                right: 280,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.05,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF0F172A),
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/honda_wing_logo.png',
                        width: 520,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

            Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: _currentStep == 7
                      ? _buildStep7Layout()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(44, 24, 28, 24),
                                child: _buildMainStage(),
                              ),
                            ),
                            SizedBox(
                              width: 316,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 24, 40, 24),
                                child: _buildQuotationSidebar(),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER WITH OFFICIAL WING LOGO + 7-STEP STEPPER + PROFILE
  // ==========================================================
  Widget _buildTopHeader() {
    const steps = [
      {'num': 1, 'title': 'Choose Ride'},
      {'num': 2, 'title': 'Vehicle'},
      {'num': 3, 'title': 'Colour'},
      {'num': 4, 'title': 'Accessories'},
      {'num': 5, 'title': 'Finance'},
      {'num': 6, 'title': 'Exchange'},
      {'num': 7, 'title': 'Summary'},
    ];

    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: Color(0xFF64748B)),
              onPressed: _prevStep,
              tooltip: 'Back',
              splashRadius: 18,
            ),
            const SizedBox(width: 4),
          ],

          // Left: Red Honda Wing emblem + "HONDA" | "Build My Honda"
          InkWell(
            onTap: () => context.go('/dashboard'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/honda_wing_logo.png',
                      width: 44,
                      height: 26,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 1),
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
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: const Color(0xFFCBD5E1),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                const Text(
                  'Build My Honda',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 36),

          // Center: 7-Step Horizontal Stepper
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Row(
                  children: [
                    for (int i = 0; i < steps.length; i++) ...[
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 1.5,
                            margin: const EdgeInsets.only(bottom: 16),
                            color: _currentStep > i
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      Builder(builder: (context) {
                        final num = steps[i]['num'] as int;
                        final title = steps[i]['title'] as String;
                        final isCompleted = _currentStep > num;
                        final isActive = _currentStep == num;

                        return InkWell(
                          onTap: isCompleted
                              ? () => setState(() => _currentStep = num)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isCompleted || isActive)
                                        ? const Color(0xFFDC2626)
                                        : Colors.white,
                                    border: Border.all(
                                      color: (isCompleted || isActive)
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                      width: 1.4,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : Text(
                                          '$num',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: isActive
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Right: Simple icon to go directly to the normal Quick Enquiry form
          IconButton(
            tooltip: 'Go to Normal Form',
            onPressed: () => context.go('/tablet'),
            icon: const Icon(
              Icons.assignment_outlined,
              color: Color(0xFF0F172A),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStage() {
    switch (_currentStep) {
      case 1:
        return _buildStep1ChooseRide();
      case 2:
        return _buildStep2SelectVehicle();
      case 3:
        return _buildStep3ChooseColour();
      case 4:
        return _buildStep4AddAccessories();
      case 5:
        return _buildStep5PaymentOption();
      case 6:
        return _buildStep6ExchangeRide();
      default:
        return _buildStep1ChooseRide();
    }
  }

  Widget _buildHeroHeadline(String first, String redPart, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Color(0xFF0F172A),
              letterSpacing: -0.6,
              height: 1.08,
            ),
            children: [
              TextSpan(text: first),
              TextSpan(
                text: redPart,
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ],
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================
  // STEP 1: CHOOSE YOUR RIDE (EXACT 3 PORTRAIT CARDS)
  // ==========================================================
  Widget _buildStep1ChooseRide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroHeadline('CHOOSE YOUR ', 'RIDE'),
        const SizedBox(height: 26),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 530),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 500 / 736,
                      child: _buildCategoryCard(
                        code: 'MC',
                        title: 'MOTORCYCLES',
                        subtitle: 'Commuter & Sport',
                        imagePath: 'assets/configurator/cat_mc_hq.jpg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 500 / 736,
                      child: _buildCategoryCard(
                        code: 'Scooter',
                        title: 'SCOOTERS',
                        subtitle: 'Everyday Urban',
                        imagePath: 'assets/configurator/cat_scooter_hq.jpg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 500 / 736,
                      child: _buildCategoryCard(
                        code: 'BigBike',
                        title: 'BIG BIKES',
                        subtitle: 'BigWing Premium',
                        imagePath: 'assets/configurator/cat_bigbike_hq.jpg',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String code,
    required String title,
    required String subtitle,
    required String imagePath,
  }) {
    final isSelected = _selectedCategory == code;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = code;
            _selectedCcFilter = 'All';
            _selectedVehicle = null;
            _invalidateQuoteCache();
          });
          _nextStep();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFCC0000)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0x2ECC0000)
                    : const Color(0x12000000),
                blurRadius: isSelected ? 24 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SmartMediaImage(source: imagePath, fit: BoxFit.cover),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.92),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCC0000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STEP 2: SELECT YOUR VEHICLE (CC FILTER + CAROUSEL)
  // ==========================================================
  Widget _buildStep2SelectVehicle() {
    final vehicles = _filteredVehicles;
    final ccChips = _availableCcChips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroHeadline('SELECT YOUR ', 'VEHICLE'),
        const SizedBox(height: 16),

        // Filter Chips Row (All, 110 CC, 125 CC, ... + On Road toggle)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...ccChips.map((label) {
                final isSel = _selectedCcFilter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCcFilter = label),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // On Road price toggle pill matching Mockup 2
              InkWell(
                onTap: () =>
                    setState(() => _showOnRoadPrice = !_showOnRoadPrice),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _showOnRoadPrice
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'On Road',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _showOnRoadPrice
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Horizontal Vehicle Cards Carousel
        Expanded(
          child: _isLoadingCatalog
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFDC2626)),
                )
              : vehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.two_wheeler_outlined,
                              size: 48, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          const Text(
                            'No vehicles match this CC filter.',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedCcFilter = 'All'),
                            child: const Text('Show all models',
                                style: TextStyle(color: Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final colsCount =
                            constraints.maxWidth >= 640 ? 2 : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: colsCount,
                            mainAxisSpacing: 18,
                            crossAxisSpacing: 18,
                            childAspectRatio: colsCount == 2 ? 1.18 : 1.32,
                          ),
                          itemCount: vehicles.length,
                          itemBuilder: (context, index) {
                            final v = vehicles[index];
                            final isSel = _selectedVehicle?['id'] == v['id'] ||
                                _selectedVehicle?['code'] == v['code'];
                            final displayPrice = _showOnRoadPrice
                                ? (v['onRoadPrice'] ?? 0)
                                : (v['exShowroomPrice'] ?? 0);
                            final cc = v['ccDisplacement'];
                            final cols = _getColoursForVehicle(v);

                            return InkWell(
                            onTap: () => _selectVehicle(v, advance: true),
                            borderRadius: BorderRadius.circular(22),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFE2E8F0),
                                  width: isSel ? 2.2 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSel
                                        ? const Color(0x26DC2626)
                                        : const Color(0x0D000000),
                                    blurRadius: isSel ? 18 : 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Top Card Image Stage (fits full landscape vehicle cleanly)
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Color(0xFFFFFFFF),
                                                  Color(0xFFF8FAFC),
                                                  Color(0xFFF1F5F9),
                                                ],
                                              ),
                                            ),
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 36, 16, 12),
                                            child: SmartMediaImage(
                                              source: _resolveListingImage(v),
                                              fit: BoxFit.contain,
                                              fallback: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .two_wheeler_outlined,
                                                      size: 46,
                                                      color: Color(0xFF94A3B8),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      v['name']?.toString() ??
                                                          '',
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (cc != null)
                                            Positioned(
                                              top: 12,
                                              left: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0F172A)
                                                      .withValues(alpha: 0.82),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Text(
                                                  '$cc CC',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (cols.isNotEmpty)
                                            Positioned(
                                              top: 14,
                                              right: 14,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.92),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFE2E8F0),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ...cols.take(4).map((c) =>
                                                        Container(
                                                          width: 10,
                                                          height: 10,
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 3),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _parseColor(
                                                                c['hex']
                                                                    ?.toString()),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: const Color(
                                                                  0x33000000),
                                                              width: 0.7,
                                                            ),
                                                          ),
                                                        )),
                                                    if (cols.length > 4)
                                                      Text(
                                                        '+${cols.length - 4}',
                                                        style: const TextStyle(
                                                          fontSize: 9.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              Color(0xFF475569),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Bottom Vehicle Name & Price Bar
                                  Container(
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                          bottom: Radius.circular(20)),
                                      border: Border(
                                        top: BorderSide(
                                            color: Color(0xFFF1F5F9)),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 12, 18, 14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if ((v['wordmarkImageUrl']
                                                          ?.toString() ??
                                                      '')
                                                  .isNotEmpty)
                                                SizedBox(
                                                  height: 24,
                                                  width: double.infinity,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: SizedBox(
                                                      height: 24,
                                                      child: SmartMediaImage(
                                                        source: v[
                                                                'wordmarkImageUrl']
                                                            ?.toString(),
                                                        fit: BoxFit.contain,
                                                        fallback: Text(
                                                          v['name']
                                                                  ?.toString() ??
                                                              '',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Color(
                                                                0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  v['name']?.toString() ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${CurrencyFormatter.format(displayPrice)}*',
                                                style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFDC2626),
                                                  letterSpacing: -0.4,
                                                ),
                                              ),
                                              Text(
                                                _showOnRoadPrice
                                                    ? 'On-Road Price (Pune)'
                                                    : 'Ex-Showroom Price',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ==========================================================
  // STEP 3: CHOOSE YOUR COLOUR (HONDA STUDIO STAGE + SWATCHES)
  // ==========================================================
  Widget _buildStep3ChooseColour() {
    final v = _selectedVehicle;
    final swatches = _getColoursForVehicle(v);
    final activeColor = _selectedColourValue;
    final isVeryLight = activeColor.computeLuminance() > 0.72;
    final stageCenter = isVeryLight
        ? const Color(0xFF475569)
        : (Color.lerp(activeColor, Colors.white, 0.28) ?? activeColor);
    final stageMid = isVeryLight
        ? const Color(0xFF1E293B)
        : (Color.lerp(activeColor, Colors.black, 0.45) ?? activeColor);
    final stageEdge = isVeryLight
        ? const Color(0xFF0F172A)
        : (Color.lerp(activeColor, Colors.black, 0.78) ?? const Color(0xFF0F172A));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroHeadline('CHOOSE YOUR ', 'COLOUR',
            subtitle: '${v?['name'] ?? 'Honda'} · Make it truly yours.'),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                center: const Alignment(-0.15, -0.1),
                radius: 1.05,
                colors: [stageCenter, stageMid, stageEdge],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Subtle floor glow / ground shadow under the vehicle
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 130,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                ),

                if ((_selectedVehicle?['brochureUrl']?.toString() ?? '')
                    .isNotEmpty)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final url =
                              _selectedVehicle!['brochureUrl'].toString();
                          launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_rounded,
                                  size: 15, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Brochure (PDF)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Main Vehicle Showcase + Bottom Swatches & Colour Name Pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  child: Column(
                    children: [
                      _buildShowcaseImageBox(animate: true),
                      const SizedBox(height: 12),

                      // Centered Horizontal Colour Swatches (Shine 100 style)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: swatches.map((opt) {
                          final cName = opt['name']?.toString() ?? 'Standard';
                          final col = _parseColor(opt['hex']?.toString());
                          final isSel = _selectedColourName == cName;
                          final isDark = col.computeLuminance() < 0.45;

                          return Tooltip(
                            message: cName,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedColourName = cName;
                                  _selectedColourValue = col;
                                  _selectedColourImageUrl =
                                      opt['colourImageUrl']?.toString();
                                  _invalidateQuoteCache();
                                });
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: isSel ? 34 : 28,
                                height: isSel ? 34 : 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: col,
                                  border: Border.all(
                                    color: isSel
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.55),
                                    width: isSel ? 2.5 : 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x40000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isSel
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // White Pill showing selected colour name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _selectedColourName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STEP 4: ADD ACCESSORIES (STANDARD INCLUDED + OPTIONAL GRID)
  // ==========================================================
  Widget _buildStep4AddAccessories() {
    final standardAccs = _standardAccessories;
    final optionalAccs = _optionalAccessories;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeadline('ADD ', 'ACCESSORIES',
                  subtitle: 'Personalise your ride, your way.'),
              _buildShowcaseImageBox(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (standardAccs.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A)),
                            children: [
                              TextSpan(text: 'Standard Accessories '),
                              TextSpan(
                                  text: '(Included)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF475569))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: standardAccs
                              .map((acc) => _buildAccessoryTile(acc,
                                  isStandardCard: true))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                          children: [
                            TextSpan(text: 'Optional Accessories '),
                            TextSpan(
                                text: '(Add to your build)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (optionalAccs.isEmpty)
                        const Text(
                          'No optional add-ons available.',
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF94A3B8)),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: optionalAccs
                              .map((acc) => _buildAccessoryTile(acc,
                                  isStandardCard: false))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessoryTile(Map<String, dynamic> acc,
      {required bool isStandardCard}) {
    final id = acc['id'].toString();
    final name = acc['name']?.toString() ?? 'Accessory';
    final price = ((acc['price'] ?? 0) as num).toDouble();
    final imgUrl = acc['imageUrl']?.toString();
    final isSel = isStandardCard || _selectedOptionalAccessoryIds.contains(id);

    return InkWell(
      onTap: isStandardCard
          ? null
          : () {
              setState(() {
                if (_selectedOptionalAccessoryIds.contains(id)) {
                  _selectedOptionalAccessoryIds.remove(id);
                } else {
                  _selectedOptionalAccessoryIds.add(id);
                }
                _invalidateQuoteCache();
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 162,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 162,
              height: 136,
              decoration: BoxDecoration(
                color: isSel && !isStandardCard
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSel && !isStandardCard
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFE2E8F0),
                  width: isSel && !isStandardCard ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSel && !isStandardCard
                        ? const Color(0x22DC2626)
                        : const Color(0x0C0F172A),
                    blurRadius: isSel && !isStandardCard ? 14 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14.5),
                      child: SmartMediaImage(
                        source: imgUrl,
                        fit: BoxFit.cover,
                        fallback: Center(
                          child: Icon(
                            _getAccessoryFallbackIcon(name),
                            size: 40,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: isStandardCard
                        ? Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 13, color: Colors.white),
                          )
                        : Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel
                                  ? const Color(0xFFDC2626)
                                  : Colors.white,
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0F172A),
                                width: 1.4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: isSel
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                height: 1.25,
              ),
            ),
            if (!isStandardCard) ...[
              const SizedBox(height: 3),
              Text(
                '+${CurrencyFormatter.format(price)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getAccessoryFallbackIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('ceramic')) return Icons.auto_awesome_outlined;
    if (lower.contains('seat')) {
      return Icons.airline_seat_recline_normal_outlined;
    }
    if (lower.contains('warranty')) return Icons.verified_outlined;
    if (lower.contains('mat')) return Icons.layers_outlined;
    if (lower.contains('grip') || lower.contains('lever')) {
      return Icons.sports_motorsports_outlined;
    }
    if (lower.contains('helmet')) return Icons.sports_motorsports;
    if (lower.contains('rsa') || lower.contains('roadside')) {
      return Icons.emergency_outlined;
    }
    if (lower.contains('guard') || lower.contains('crash')) {
      return Icons.shield_outlined;
    }
    if (lower.contains('tank')) return Icons.crop_portrait_outlined;
    if (lower.contains('box')) return Icons.luggage_outlined;
    if (lower.contains('wind')) return Icons.air_outlined;
    if (lower.contains('phone') || lower.contains('holder')) {
      return Icons.smartphone_outlined;
    }
    if (lower.contains('pdi')) return Icons.fact_check_outlined;
    return Icons.inventory_2_outlined;
  }

  // ==========================================================
  // STEP 5: CHOOSE YOUR PAYMENT OPTION (DISPLAY ONLY FINANCE)
  // ==========================================================
  Widget _buildStep5PaymentOption() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeadline('CHOOSE YOUR ', 'PAYMENT OPTION',
                  subtitle: 'Pick what works best for you.'),
              _buildShowcaseImageBox(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card 1: Pay in Cash
                  InkWell(
                    onTap: () => setState(() {
                      _paymentMode = 'Cash';
                      _invalidateQuoteCache();
                    }),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 18),
                      decoration: BoxDecoration(
                        color: _paymentMode == 'Cash'
                            ? const Color(0xFFFFFBFB)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _paymentMode == 'Cash'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFE2E8F0),
                          width: _paymentMode == 'Cash' ? 1.8 : 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.credit_card_rounded,
                                size: 30, color: Color(0xFFDC2626)),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pay in Cash',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Make a one-time payment and own your Honda.',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                          _RadioRing(isSelected: _paymentMode == 'Cash'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Finance (with Bank Loan / Dealer Finance / Flexi EMI Plans)
                  InkWell(
                    onTap: () => setState(() {
                      _paymentMode = 'Finance';
                      _invalidateQuoteCache();
                    }),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _paymentMode == 'Finance'
                            ? const Color(0xFFFFF5F5)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _paymentMode == 'Finance'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFE2E8F0),
                          width: _paymentMode == 'Finance' ? 1.8 : 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFECACA)),
                                ),
                                child: const Icon(Icons.event_note_rounded,
                                    size: 30, color: Color(0xFFDC2626)),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Finance',
                                      style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Own your ride with easy EMI options.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ),
                              _RadioRing(isSelected: _paymentMode == 'Finance'),
                            ],
                          ),
                          if (_paymentMode == 'Finance') ...[
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(
                                    child: Divider(color: Color(0xFFFECACA))),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Choose a Finance Option',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(color: Color(0xFFFECACA))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _buildFinanceOptionBtn(
                                    'Bank Loan', Icons.account_balance_rounded),
                                const SizedBox(width: 10),
                                _buildFinanceOptionBtn(
                                    'Dealer Finance', Icons.handshake_outlined),
                                const SizedBox(width: 10),
                                _buildFinanceOptionBtn(
                                    'Flexi EMI Plans', Icons.currency_rupee),
                              ],
                            ),
                            if (_backendFinanciers.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedFinancierId,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelText: 'Preferred Financier (Optional)',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                                items: _backendFinanciers
                                    .map((f) => DropdownMenuItem<String>(
                                          value: f['id']?.toString(),
                                          child: Text(
                                            f['name']?.toString() ?? '',
                                            style:
                                                const TextStyle(fontSize: 12.5),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  final match = _backendFinanciers.firstWhere(
                                      (f) => f['id'] == val,
                                      orElse: () => {});
                                  setState(() {
                                    _selectedFinancierId = val;
                                    _selectedFinancierName =
                                        match['name']?.toString();
                                    _invalidateQuoteCache();
                                  });
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _TrustFeatureItem(
                                    icon: Icons.percent,
                                    label: 'Low\nInterest Rates'),
                                _TrustFeatureItem(
                                    icon: Icons.calendar_month_outlined,
                                    label: 'Flexible\nEMI Tenure'),
                                _TrustFeatureItem(
                                    icon: Icons.handshake_outlined,
                                    label: 'Hassle-Free\nApproval'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceOptionBtn(String label, IconData icon) {
    final isSel = _selectedFinanceType == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedFinanceType = label;
          _invalidateQuoteCache();
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
              width: isSel ? 1.8 : 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // STEP 6: EXCHANGE YOUR OLD RIDE
  // ==========================================================
  Widget _buildStep6ExchangeRide() {
    final years = [
      'Select Year',
      for (int y = 2026; y >= 2005; y--) y.toString(),
    ];

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeadline('EXCHANGE YOUR ', 'OLD RIDE',
                  subtitle:
                      'Trade in your current two-wheeler for a better deal.'),
              _buildShowcaseImageBox(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                // Card 1: Exchange Choice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Do you want to exchange your old vehicle?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ExchangeChoicePill(
                              label: 'Yes, I want to exchange',
                              isSelected: _wantExchange,
                              onTap: () => setState(() {
                                _wantExchange = true;
                                _invalidateQuoteCache();
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ExchangeChoicePill(
                              label: 'No, Continue without exchange',
                              isSelected: !_wantExchange,
                              onTap: () => setState(() {
                                _wantExchange = false;
                                _invalidateQuoteCache();
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_wantExchange) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tell us about your current vehicle',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _ExchangeTextField(
                                label: 'Model',
                                hint: 'e.g. Honda Activa',
                                icon: Icons.two_wheeler_outlined,
                                controller: _exchangeModelController,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.calendar_month_outlined,
                                          size: 14, color: Color(0xFF64748B)),
                                      SizedBox(width: 6),
                                      Text('Year of Purchase',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: years.contains(_exchangeYear)
                                            ? _exchangeYear
                                            : 'Select Year',
                                        isExpanded: true,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF0F172A)),
                                        items: years
                                            .map((y) => DropdownMenuItem(
                                                value: y, child: Text(y)))
                                            .toList(),
                                        onChanged: (val) => setState(() =>
                                            _exchangeYear =
                                                val ?? 'Select Year'),
                                      ),
                                    ),
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
                              child: _ExchangeTextField(
                                label: 'Kms Driven',
                                hint: 'e.g. 25,000',
                                icon: Icons.speed_outlined,
                                controller: _exchangeKmsController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ExchangeTextField(
                                label: 'Offered Price',
                                hint: '₹ e.g. 45,000',
                                icon: Icons.sell_outlined,
                                controller: _exchangeOfferedPriceController,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ExchangeTextField(
                          label: 'Your Expected Price',
                          hint: '₹ e.g. 50,000',
                          icon: Icons.payments_outlined,
                          controller: _exchangeExpectedPriceController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STEP 7: YOUR BUILD SUMMARY (3-COLUMN + RED ACTION PILL BAR)
  // ==========================================================
  Widget _buildStep7Layout() {
    final v = _selectedVehicle;
    final accSummaryParts = <String>[];
    if (_standardAccessories.isNotEmpty) {
      accSummaryParts
          .addAll(_standardAccessories.map((a) => a['name']?.toString() ?? ''));
    }
    for (final a in _optionalAccessories) {
      if (_selectedOptionalAccessoryIds.contains(a['id'].toString())) {
        accSummaryParts.add(a['name']?.toString() ?? '');
      }
    }
    final accText = accSummaryParts.isEmpty
        ? 'No accessories added'
        : accSummaryParts.join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 24, 40, 28),
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final cardHeight =
              (outerConstraints.maxHeight - 84).clamp(380.0, 468.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Title + Clean Studio Vehicle
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeadline('YOUR BUILD ', 'SUMMARY',
                        subtitle: 'Here\'s your personalised Honda.'),
                    if (_createdQuoteNumber != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined,
                                size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text(
                              'Quote Ready · #$_createdQuoteNumber',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildShowcaseImageBox(),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Right Column spanning Config + Quotation sidebar ABOVE + Red Action Bar BELOW
              Expanded(
                flex: 7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: cardHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Center: Your Configuration White Card
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 22, 20, 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border:
                                    Border.all(color: const Color(0xFFF1F5F9)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x0D000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Configuration',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (_, innerConstraints) {
                                        return SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight:
                                                  innerConstraints.maxHeight,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                _buildSummaryConfigRow(
                                                  icon: Icons
                                                      .two_wheeler_outlined,
                                                  label: 'Vehicle',
                                                  value:
                                                      v?['name']?.toString() ??
                                                          'Honda',
                                                  onEdit: () => setState(
                                                      () => _currentStep = 2),
                                                ),
                                                const Divider(
                                                    height: 1,
                                                    color: Color(0xFFF1F5F9)),
                                                _buildSummaryConfigRow(
                                                  icon: Icons.palette_outlined,
                                                  label: 'Colour',
                                                  value: _selectedColourName,
                                                  leadingSwatch:
                                                      _selectedColourValue,
                                                  onEdit: () => setState(
                                                      () => _currentStep = 3),
                                                ),
                                                const Divider(
                                                    height: 1,
                                                    color: Color(0xFFF1F5F9)),
                                                _buildSummaryConfigRow(
                                                  icon: Icons.settings_outlined,
                                                  label: 'Accessories',
                                                  value: accText,
                                                  onEdit: () => setState(
                                                      () => _currentStep = 4),
                                                ),
                                                const Divider(
                                                    height: 1,
                                                    color: Color(0xFFF1F5F9)),
                                                _buildSummaryConfigRow(
                                                  icon: Icons
                                                      .monetization_on_outlined,
                                                  label: 'Finance',
                                                  value: _paymentMode == 'Cash'
                                                      ? 'Pay in Cash'
                                                      : 'Finance · $_selectedFinanceType',
                                                  onEdit: () => setState(
                                                      () => _currentStep = 5),
                                                ),
                                                const Divider(
                                                    height: 1,
                                                    color: Color(0xFFF1F5F9)),
                                                _buildSummaryConfigRow(
                                                  icon: Icons.sync_alt_rounded,
                                                  label: 'Exchange',
                                                  value: _wantExchange
                                                      ? (_exchangeModelController
                                                              .text.isNotEmpty
                                                          ? _exchangeModelController
                                                              .text
                                                          : 'Exchange Old Vehicle')
                                                      : 'No Exchange',
                                                  onEdit: () => setState(
                                                      () => _currentStep = 6),
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
                          ),

                          const SizedBox(width: 20),

                          // Right: Quotation Summary Card (no Continue btn on Step 7)
                          SizedBox(
                            width: 290,
                            child: _buildQuotationSidebar(hideButton: true),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Bottom Red Action Bar:
                    // Before customer details -> "Fill Customer Details & Generate Quote"
                    // After enquiry & quote created -> (Email | WhatsApp | Print | Download)
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33DC2626),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: (_createdEnquiryId == null ||
                              _createdQuotationId == null)
                          ? Row(
                              children: [
                                _buildBottomActionBtn(
                                  icon: Icons.person_add_alt_1_outlined,
                                  label:
                                      'Fill Customer Details & Generate Quote',
                                  onTap: () => _handleAction('register'),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                _buildBottomActionBtn(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  onTap: () => _handleAction('email'),
                                ),
                                _verticalDivider(),
                                _buildBottomActionBtn(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: 'WhatsApp',
                                  onTap: () => _handleAction('whatsapp'),
                                ),
                                _verticalDivider(),
                                _buildBottomActionBtn(
                                  icon: Icons.print_outlined,
                                  label: 'Print',
                                  onTap: () => _handleAction('print'),
                                ),
                                _verticalDivider(),
                                _buildBottomActionBtn(
                                  icon: Icons.download_outlined,
                                  label: 'Download',
                                  onTap: () => _handleAction('download'),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _verticalDivider() => Container(
        width: 1,
        height: 24,
        color: Colors.white.withValues(alpha: 0.35),
      );

  Widget _buildBottomActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryConfigRow({
    required IconData icon,
    required String label,
    required String value,
    Color? leadingSwatch,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Icon(icon, size: 21, color: const Color(0xFF0F172A)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (leadingSwatch != null)
                    Container(
                      width: 13,
                      height: 13,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: leadingSwatch,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: Color(0xFFDC2626)),
          onPressed: onEdit,
          splashRadius: 18,
        ),
      ],
    );
  }

  // ==========================================================
  // RIGHT FLOATING QUOTATION SIDEBAR
  // ==========================================================
  Widget _buildQuotationSidebar({bool hideButton = false}) {
    final bool canContinue;
    if (_currentStep == 1) {
      canContinue = _selectedCategory != null;
    } else if (_currentStep == 2) {
      canContinue = _selectedVehicle != null;
    } else {
      canContinue = true;
    }

    final accCount =
        _standardAccessories.length + _selectedOptionalAccessoryIds.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Quotation',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Build, customise and see your price in real time.',
            style: TextStyle(
                fontSize: 12.5, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSidebarPriceRow(
                    icon: Icons.two_wheeler_outlined,
                    label: 'Vehicle',
                    subtitle: _selectedVehicle == null
                        ? null
                        : '${_selectedVehicle!['name']} · ${_showOnRoadPrice ? 'On-Road' : 'Ex-Showroom'}',
                    valueText: _selectedVehicle == null
                        ? '—'
                        : CurrencyFormatter.format(_vehicleBasePrice),
                    valueColor: _selectedVehicle != null
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                  if (_selectedVehicle != null && _showOnRoadPrice) ...[
                    Builder(builder: (context) {
                      final ex = ((_selectedVehicle!['exShowroomPrice'] ?? 0)
                              as num)
                          .toDouble();
                      final onR =
                          ((_selectedVehicle!['onRoadPrice'] ?? 0) as num)
                              .toDouble();
                      final diff = onR - ex;
                      if (ex <= 0 || diff <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 29, top: 6),
                        child: Column(
                          children: [
                            _buildSidebarSubRow(
                                'Ex-Showroom', CurrencyFormatter.format(ex)),
                            const SizedBox(height: 3),
                            _buildSidebarSubRow('RTO, Insurance & Misc',
                                '+${CurrencyFormatter.format(diff)}'),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 14),
                  _buildSidebarPriceRow(
                    icon: Icons.palette_outlined,
                    label: 'Colour',
                    subtitle: _selectedVehicle != null &&
                            _selectedColourName.isNotEmpty
                        ? _selectedColourName
                        : null,
                    colorDot:
                        _selectedVehicle != null ? _selectedColourValue : null,
                    valueText: _selectedVehicle == null ? '—' : 'Included',
                    valueColor: _selectedVehicle != null
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 14),
                  Builder(builder: (context) {
                    final selectedOptionals = _optionalAccessories
                        .where((a) => _selectedOptionalAccessoryIds
                            .contains(a['id'].toString()))
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSidebarPriceRow(
                          icon: Icons.settings_outlined,
                          label: 'Accessories',
                          subtitle: selectedOptionals.isEmpty &&
                                  _standardAccessories.isNotEmpty &&
                                  _currentStep >= 4
                              ? 'Standard included'
                              : null,
                          valueText: _selectedVehicle == null
                              ? '—'
                              : (_selectedOptionalAccessoriesTotal > 0
                                  ? '+${CurrencyFormatter.format(_selectedOptionalAccessoriesTotal)}'
                                  : (_currentStep >= 4 ? '₹0' : '—')),
                          valueColor: _selectedOptionalAccessoriesTotal > 0
                              ? const Color(0xFFDC2626)
                              : (_currentStep >= 4 && _selectedVehicle != null
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF94A3B8)),
                        ),
                        if (selectedOptionals.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 29),
                            child: Column(
                              children: selectedOptionals.map((acc) {
                                final accName =
                                    acc['name']?.toString() ?? 'Accessory';
                                final accPrice =
                                    ((acc['price'] ?? 0) as num).toDouble();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _buildSidebarSubRow(
                                    '• $accName',
                                    '+${CurrencyFormatter.format(accPrice)}',
                                    valueColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                  const SizedBox(height: 14),
                  _buildSidebarPriceRow(
                    icon: Icons.monetization_on_outlined,
                    label: 'Finance',
                    subtitle: _currentStep >= 5 || _paymentMode == 'Finance'
                        ? (_paymentMode == 'Finance'
                            ? (_selectedFinancierName ?? _selectedFinanceType)
                            : 'Pay in Cash')
                        : null,
                    valueText: _currentStep >= 5 || _paymentMode == 'Finance'
                        ? (_paymentMode == 'Finance' ? 'Finance' : 'Cash')
                        : '—',
                    valueColor: _currentStep >= 5 || _paymentMode == 'Finance'
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 14),
                  Builder(builder: (context) {
                    final exVal = double.tryParse(
                            _exchangeExpectedPriceController.text.trim()) ??
                        0;
                    return _buildSidebarPriceRow(
                      icon: Icons.sync_alt_rounded,
                      label: 'Exchange',
                      subtitle: _wantExchange &&
                              _exchangeModelController.text.trim().isNotEmpty
                          ? _exchangeModelController.text.trim()
                          : null,
                      valueText: _wantExchange
                          ? (exVal > 0
                              ? '-${CurrencyFormatter.format(exVal)}'
                              : 'Yes')
                          : (_currentStep >= 6 ? 'No' : '—'),
                      valueColor: _wantExchange
                          ? const Color(0xFF16A34A)
                          : (_currentStep >= 6
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8)),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          Builder(builder: (context) {
            final exVal = _wantExchange
                ? (double.tryParse(
                        _exchangeExpectedPriceController.text.trim()) ??
                    0)
                : 0.0;
            final netAfterExchange =
                (_estimatedTotal - exVal).clamp(0, double.infinity);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedVehicle != null && exVal > 0) ...[
                  _buildSidebarSubRow(
                    'Net Payable (after Exchange)',
                    CurrencyFormatter.format(netAfterExchange),
                    valueColor: const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Estimated Price',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedVehicle == null
                      ? '₹--,---'
                      : '${CurrencyFormatter.format(_estimatedTotal)}*',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            );
          }),
          if (!hideButton) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF4A5A5),
                  disabledBackgroundColor: const Color(0xFFF4A5A5),
                  foregroundColor: Colors.white,
                  elevation: canContinue ? 4 : 0,
                  shadowColor: const Color(0x33DC2626),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: canContinue ? _nextStep : null,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarSubRow(String label, String valueText,
      {Color valueColor = const Color(0xFF475569)}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarPriceRow({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? colorDot,
    required String valueText,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 19, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (colorDot != null) ...[
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: colorDot,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0x33000000),
                            width: 0.6,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // STEP 7 ACTIONS: CAPTURE CUSTOMER DETAILS -> CREATE REAL QUOTE -> DISPATCH
  // ==========================================================
  Future<void> _handleAction(String actionType) async {
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Please sign in on this showroom tablet before creating & sending official quotations.'),
          action: SnackBarAction(
            label: 'Sign in',
            textColor: Colors.white,
            onPressed: () => context.go('/login'),
          ),
        ),
      );
      return;
    }

    if (_backendVehicles.isEmpty ||
        (_selectedVehicle?['id']?.toString().startsWith('v-') ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Preview mode only (live dealership catalog offline). Reload when connected before submitting a quote.'),
        ),
      );
      return;
    }

    if (_createdEnquiryId != null && _createdQuotationId != null) {
      await _executeDispatchAction(actionType);
      return;
    }

    // Prompt customer details cleanly
    final needsEmail = actionType == 'email';
    final user = authState.user;

    String? chosenBranchId = _selectedBranchId;
    final activeBranch = ref.read(selectedBranchIdProvider);
    if (activeBranch != 'all' && activeBranch.isNotEmpty) {
      chosenBranchId = activeBranch;
    } else if (user?.branches.isNotEmpty == true) {
      chosenBranchId = user!.branches.first.id;
    } else if (_backendBranches.isNotEmpty) {
      chosenBranchId = _backendBranches.first['id']?.toString();
    }

    String chosenBuyingWhen = 'Immediate';
    DateTime? customBuyDate;
    const buyingOptions = <Map<String, String>>[
      {'label': 'Immediately', 'value': 'Immediate'},
      {'label': '3 Days', 'value': 'Within 3 Days'},
      {'label': 'This Week', 'value': 'This Week'},
      {'label': 'This Month', 'value': 'This Month'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  actionType == 'register'
                      ? 'Customer Details & Quote'
                      : actionType == 'email'
                          ? 'Email Your Quotation'
                          : (actionType == 'whatsapp'
                              ? 'Send Quote on WhatsApp'
                              : 'Generate Official Quote'),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedVehicle?['name'] ?? 'Honda'} · $_selectedColourName',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                Text(
                  'Estimated Price: ${CurrencyFormatter.format(_estimatedTotal)}*',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _customerNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customerMobileController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number (WhatsApp) *',
                    hintText: '10-digit mobile number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText:
                        needsEmail ? 'Email Address *' : 'Email (Optional)',
                    hintText: 'name@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'When are you planning to buy?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...buyingOptions.map((opt) {
                      final val = opt['value']!;
                      final isSel =
                          customBuyDate == null && chosenBuyingWhen == val;
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSel,
                        onSelected: (_) => setDlgState(() {
                          customBuyDate = null;
                          chosenBuyingWhen = val;
                        }),
                        selectedColor: const Color(0xFFDC2626),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: BorderSide(
                          color: isSel
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      );
                    }),
                    ChoiceChip(
                      avatar: Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: customBuyDate != null
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                      label: Text(
                        customBuyDate != null
                            ? '${customBuyDate!.day.toString().padLeft(2, '0')}/${customBuyDate!.month.toString().padLeft(2, '0')}/${customBuyDate!.year}'
                            : 'Custom Date',
                      ),
                      selected: customBuyDate != null,
                      onSelected: (_) async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate:
                              customBuyDate ?? now.add(const Duration(days: 7)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDlgState(() {
                            customBuyDate = picked;
                            chosenBuyingWhen =
                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      selectedColor: const Color(0xFFDC2626),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: BorderSide(
                        color: customBuyDate != null
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFE2E8F0),
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: customBuyDate != null
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final name = _customerNameController.text.trim();
                      final mobile = _customerMobileController.text.trim();
                      final email = _customerEmailController.text.trim();

                      if (name.isEmpty || mobile.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter your Name and valid 10-digit Mobile Number.')),
                        );
                        return;
                      }
                      if (needsEmail && !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter a valid Email address to email your quote.')),
                        );
                        return;
                      }

                      setDlgState(() => _isSubmitting = true);
                      _selectedBranchId = chosenBranchId;
                      final ok = await _submitRealEnquiry(
                        name: name,
                        mobile: mobile,
                        email: email.isEmpty ? null : email,
                        branchId: chosenBranchId ?? '',
                        buyingWhen: chosenBuyingWhen,
                      );
                      setDlgState(() => _isSubmitting = false);
                      if (ok && ctx.mounted) {
                        Navigator.pop(ctx);
                        if (actionType == 'register') {
                          await _autoDispatchOnRegister();
                        } else {
                          await _executeDispatchAction(actionType);
                        }
                      }
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Generate & Continue',
                      style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _submitRealEnquiry({
    required String name,
    required String mobile,
    String? email,
    required String branchId,
    String buyingWhen = 'Immediate',
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      final authState = ref.read(authStateProvider);
      final user = authState.user;

      final v = _selectedVehicle!;
      final quoteAccessories = <Map<String, dynamic>>[
        for (final acc in _standardAccessories)
          if (!acc['id'].toString().startsWith('acc-'))
            {'accessoryId': acc['id'], 'amount': 0},
        for (final acc in _optionalAccessories)
          if (_selectedOptionalAccessoryIds.contains(acc['id'].toString()) &&
              !acc['id'].toString().startsWith('acc-'))
            {'accessoryId': acc['id'], 'amount': acc['price']},
      ];

      final exchangeDesc = _wantExchange
          ? 'Exchange: Yes (${_exchangeModelController.text.trim()} ${_exchangeYear != 'Select Year' ? _exchangeYear : ''}, Expected: ₹${_exchangeExpectedPriceController.text.trim()})'
          : 'No';

      final remarks =
          'Build My Honda • $_selectedCategory • $_selectedColourName'
          '${_paymentMode == 'Finance' ? ' • $_selectedFinanceType${_selectedFinancierName != null ? ' ($_selectedFinancierName)' : ''}' : ' • Pay in Cash'}'
          '${_wantExchange ? ' • $exchangeDesc' : ''}';

      final payload = {
        'branchId': branchId,
        'customer': {
          'name': name,
          'mobile': mobile,
          if (email != null) 'email': email,
        },
        'enquiryType': 'Walk-in',
        'purchaseMode': _paymentMode,
        if (_paymentMode == 'Finance' && _selectedFinancierId != null)
          'financierId': _selectedFinancierId,
        'exchange': _wantExchange ? 'Yes' : 'No',
        'buyingWhen': buyingWhen,
        'remarks': remarks,
        if (_selectedRepId != null) 'assignedToId': _selectedRepId,
        'quotation': {
          'vehicleId': v['id'],
          'colourName': _selectedColourName,
          if (quoteAccessories.isNotEmpty) 'accessories': quoteAccessories,
        },
      };

      final res = await dio.post('/enquiries', data: payload);

      final created = res.data as Map<String, dynamic>;
      final quotes = (created['quotations'] as List? ?? []);
      final firstQuote = quotes.isNotEmpty
          ? Map<String, dynamic>.from(quotes.first as Map)
          : null;

      // Update live rep session indicator if logged in
      final repId = _selectedRepId ?? user?.id;
      if (repId != null) {
        final storage = ref.read(secureStorageProvider);
        await storage.write(
          key: 'yash_live_session_$repId',
          value: jsonEncode({
            'salesExecId': repId,
            'salesExecName': user?.name ?? 'Showroom Tablet',
            'customerName': name,
            'customerMobile': mobile,
            'vehicleName': v['name'],
            'colourName': _selectedColourName,
            'grandTotal': firstQuote?['grandTotal'] ?? _estimatedTotal,
            'branchId': branchId,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      }

      if (mounted) {
        setState(() {
          _createdEnquiryId = created['id']?.toString();
          _createdQuotationId = firstQuote?['id']?.toString();
          _createdQuoteNumber = firstQuote?['quoteNumber']?.toString();
          _isSubmitting = false;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String msg = 'Could not generate quotation: $e';
        if (e is DioException && e.response?.data != null) {
          msg = e.response?.data['message']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      return false;
    }
  }

  Future<void> _autoDispatchOnRegister() async {
    final dio = ref.read(dioProvider);
    final quoteNo = _createdQuoteNumber ?? _createdQuotationId ?? '';
    final email = _customerEmailController.text.trim();
    final parts = <String>['Enquiry & Quote #$quoteNo saved'];

    if (email.contains('@')) {
      try {
        final emailRes = await dio.post('/communications/email', data: {
          'enquiryId': _createdEnquiryId,
          'recipientEmail': email,
          'subject':
              'Your Official Honda Quotation (#$quoteNo) - Yash Honda Pune',
          'quotationId': _createdQuotationId,
        });
        final emailOk =
            emailRes.data is Map && emailRes.data['success'] == true;
        parts.add(emailOk ? 'Email sent' : 'Email failed');
      } catch (_) {
        parts.add('Email pending');
      }
    }

    try {
      await dio.post('/communications/whatsapp', data: {
        'enquiryId': _createdEnquiryId,
        'templateName': 'quotation_send',
        'quotationId': _createdQuotationId,
      });
      parts.add('WhatsApp logged');
    } catch (_) {
      // Formal WhatsApp Business API queued for next version
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text('${parts.join(' • ')}.'),
        ),
      );
    }
  }

  Future<void> _executeDispatchAction(String actionType) async {
    final dio = ref.read(dioProvider);
    final quoteNo = _createdQuoteNumber ?? _createdQuotationId ?? '';

    if (actionType == 'print') {
      if (quoteNo.isEmpty) return;
      final printUrl = '${ApiConstants.baseUrl}/quotations/$quoteNo/print';
      final uri = Uri.parse(printUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Opening printable quotation #$quoteNo...'),
          ),
        );
      }
      return;
    }

    if (actionType == 'download') {
      if (quoteNo.isEmpty) return;
      await _downloadQuotationPdf(quoteNo);
      return;
    }

    if (actionType == 'email') {
      String email = _customerEmailController.text.trim();
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(email)) {
        final entered = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final ctrl = TextEditingController(text: email);
            String? errText;
            return StatefulBuilder(
              builder: (context, setDlgState) => AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Email Quotation',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                content: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Customer Email Address *',
                    hintText: 'name@example.com',
                    errorText: errText,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final val = ctrl.text.trim();
                      if (!emailRegex.hasMatch(val)) {
                        setDlgState(
                            () => errText = 'Enter a valid email address');
                        return;
                      }
                      Navigator.pop(ctx, val);
                    },
                    child: const Text('Send Email'),
                  ),
                ],
              ),
            );
          },
        );
        if (entered == null || entered.isEmpty) return;
        email = entered;
        _customerEmailController.text = entered;
      }
      try {
        final res = await dio.post('/communications/email', data: {
          'enquiryId': _createdEnquiryId,
          'recipientEmail': email,
          'subject':
              'Your Official Honda Quotation (#$quoteNo) - Yash Honda Pune',
          if (_createdQuotationId != null) 'quotationId': _createdQuotationId,
        });
        if (mounted) {
          final ok = res.data is Map && res.data['success'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor:
                  ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              content: Text(res.data?['message']?.toString() ??
                  (ok
                      ? 'Quotation emailed successfully!'
                      : 'Failed to send email.')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String msg = 'Failed to send email.';
          if (e is DioException && e.response?.data is Map) {
            final errData = e.response!.data as Map;
            final rawMsg = errData['message'];
            msg = rawMsg is List ? rawMsg.join(', ') : (rawMsg?.toString() ?? msg);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFDC2626),
              content: Text(msg),
            ),
          );
        }
      }
      return;
    }

    if (actionType == 'whatsapp') {
      try {
        final res = await dio.post('/communications/whatsapp', data: {
          'enquiryId': _createdEnquiryId,
          'templateName': 'quotation_send',
          'quotationId': _createdQuotationId,
        });
        final mode = res.data?['mode']?.toString();
        if (mode != 'live_meta') {
          final custName = _customerNameController.text.trim();
          final mobile = _customerMobileController.text
              .trim()
              .replaceAll(RegExp(r'[^0-9]'), '');
          final vName = _selectedVehicle?['name']?.toString() ?? 'Honda';
          final totalStr = CurrencyFormatter.format(_estimatedTotal);
          final text = Uri.encodeComponent(
            'Namaste $custName, thank you for configuring your $vName ($_selectedColourName) at Yash Honda!\n\n'
            '• Quote No: $quoteNo\n'
            '• Estimated Total: $totalStr*\n'
            '• Print / View Quote: ${ApiConstants.baseUrl}/quotations/$quoteNo/print\n\n'
            'Yash Honda Authorised Dealership, Pune.',
          );
          await launchUrl(Uri.parse('https://wa.me/91$mobile?text=$text'),
              mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF16A34A),
              content: Text('Official quotation sent via WhatsApp!'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('WhatsApp error: $e')));
        }
      }
    }
  }

  String _pdfRs(num amount) =>
      CurrencyFormatter.format(amount).replaceAll('₹', 'Rs. ');

  Future<void> _downloadQuotationPdf(String quoteNo) async {
    try {
      final doc = pw.Document();
      final custName = _customerNameController.text.trim();
      final custMobile = _customerMobileController.text.trim();
      final custEmail = _customerEmailController.text.trim();
      final vName = _selectedVehicle?['name']?.toString() ?? 'Honda Vehicle';
      final mgName = _selectedVehicle?['modelGroup']?.toString() ?? '';
      final isBigWing = mgName.toLowerCase().contains('big') ||
          _selectedCategory == 'BigBike' ||
          quoteNo.toUpperCase().startsWith('BW');
      pw.MemoryImage? wingLogoImg;
      try {
        final byteData = await rootBundle.load(
          isBigWing
              ? 'assets/honda_bigwing_logo.png'
              : 'assets/honda_wing_logo.png',
        );
        wingLogoImg = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {}
      final branchObj = _backendBranches.firstWhere(
        (b) => b['id']?.toString() == _selectedBranchId,
        orElse: () => <String, dynamic>{},
      );
      final branchLabel = branchObj.isNotEmpty
          ? '${branchObj['name']} (${branchObj['wing'] ?? ''})'
          : 'Yash Honda Pune';

      final selectedOptional = _optionalAccessories
          .where(
              (a) => _selectedOptionalAccessoryIds.contains(a['id'].toString()))
          .toList();
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Brand Header (BigWing = Black + Silver Wing + Gold; RedWing = White + Red Wing)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: isBigWing
                      ? PdfColor.fromHex('#0F172A')
                      : PdfColors.white,
                  border: isBigWing
                      ? null
                      : pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'YASH HONDA',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColors.white
                                : PdfColor.fromHex('#DC2626'),
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          isBigWing
                              ? 'Authorised Honda BigWing Dealer · $branchLabel'
                              : 'Authorised Honda RedWing Dealer · $branchLabel',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColor.fromHex('#F59E0B')
                                : PdfColor.fromHex('#DC2626'),
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Quotation #$quoteNo  ·  Date: $dateStr',
                          style: pw.TextStyle(
                            color: isBigWing
                                ? PdfColor.fromHex('#CBD5E1')
                                : PdfColor.fromHex('#475569'),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    if (wingLogoImg != null)
                      pw.Image(
                        wingLogoImg,
                        width: isBigWing ? 64 : 48,
                        height: isBigWing ? 42 : 34,
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Customer Details
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PREPARED FOR',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#64748B'))),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            custName.isNotEmpty ? custName : 'Valued Customer',
                            style: pw.TextStyle(
                                fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        if (custMobile.isNotEmpty)
                          pw.Text('Mobile: +91 $custMobile',
                              style: const pw.TextStyle(fontSize: 10.5)),
                        if (custEmail.isNotEmpty)
                          pw.Text('Email: $custEmail',
                              style: const pw.TextStyle(fontSize: 10.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PAYMENT MODE',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#64748B'))),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _paymentMode == 'Finance'
                              ? 'Finance (${_selectedFinancierName ?? _selectedFinanceType})'
                              : 'Pay in Cash',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          _wantExchange
                              ? 'Exchange: ${_exchangeModelController.text.trim()}'
                              : 'Exchange: No',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // Vehicle & Accessories Breakdown Table
              pw.Text(
                'VEHICLE & CONFIGURATION BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0F172A'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Item / Description',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Type',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$vName\nColour: $_selectedColourName',
                            style: const pw.TextStyle(fontSize: 10.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            _showOnRoadPrice ? 'On-Road' : 'Ex-Showroom',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(_pdfRs(_vehicleBasePrice),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 10.5,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  for (final acc in _standardAccessories)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(acc['name']?.toString() ?? '',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Standard',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Included',
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  for (final acc in selectedOptional)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(acc['name']?.toString() ?? '',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Optional Add-on',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              _pdfRs(((acc['price'] ?? 0) as num).toDouble()),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Estimated Grand Total Box
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: isBigWing
                      ? PdfColor.fromHex('#FFFBEB')
                      : PdfColor.fromHex('#FEF2F2'),
                  border: pw.Border.all(
                      color: isBigWing
                          ? PdfColor.fromHex('#FDE68A')
                          : PdfColor.fromHex('#FECACA')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Estimated Total (${_showOnRoadPrice ? 'On-Road' : 'Ex-Showroom'} + Add-ons)',
                      style: pw.TextStyle(
                          fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${_pdfRs(_estimatedTotal)}*',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: isBigWing
                            ? PdfColor.fromHex('#D97706')
                            : PdfColor.fromHex('#DC2626'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.Text(
                '* Prices are indicative and subject to RTO/insurance charges and final dealership confirmation at delivery.',
                style: pw.TextStyle(
                    fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
              ),
            ],
          ),
        ),
      );

      final bytes = await doc.save();
      downloadFileBytes(bytes, 'Quotation-$quoteNo.pdf', 'application/pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('Downloaded Quotation-$quoteNo.pdf'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download PDF: $e')),
        );
      }
    }
  }
}

// ==========================================================
// VECTOR HONDA WING LOGO + REUSABLE ATOMIC WIDGETS
// ==========================================================
class _HondaWingPainter extends CustomPainter {
  final Color color;
  _HondaWingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Stylized sculpted Honda Wing silhouette
    final outer = Path()
      ..moveTo(w * 0.06, h * 0.92)
      ..lineTo(w * 0.96, h * 0.92)
      ..lineTo(w * 0.78, h * 0.78)
      ..lineTo(w * 0.14, h * 0.78)
      ..close();
    canvas.drawPath(outer, paint);

    // 4 swept feathers rising right
    for (int i = 0; i < 4; i++) {
      final yTop = h * (0.10 + i * 0.17);
      final yBot = h * (0.21 + i * 0.17);
      final xStart = w * (0.14 + i * 0.04);
      final xEnd = w * (0.98 - i * 0.06);
      final feather = Path()
        ..moveTo(xStart, h * 0.74)
        ..quadraticBezierTo(xStart + w * 0.18, yTop + h * 0.04, xEnd, yTop)
        ..lineTo(xEnd - w * 0.05, yBot)
        ..quadraticBezierTo(
            xStart + w * 0.22, yBot + h * 0.05, xStart + w * 0.10, h * 0.74)
        ..close();
      canvas.drawPath(feather, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HondaWingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RadioRing extends StatelessWidget {
  final bool isSelected;
  const _RadioRing({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          width: 1.8,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _TrustFeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustFeatureItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFFDC2626)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ExchangeChoicePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExchangeChoicePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            _RadioRing(isSelected: isSelected),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExchangeTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _ExchangeTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
