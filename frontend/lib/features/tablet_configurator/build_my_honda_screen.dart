import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../auth/auth_notifier.dart';

class BuildMyHondaScreen extends ConsumerStatefulWidget {
  final String? initialRepId;
  const BuildMyHondaScreen({super.key, this.initialRepId});

  @override
  ConsumerState<BuildMyHondaScreen> createState() => _BuildMyHondaScreenState();
}

class _BuildMyHondaScreenState extends ConsumerState<BuildMyHondaScreen> {
  // Stepper: 1: Choose Ride, 2: Vehicle, 3: Colour, 4: Accessories, 5: Finance, 6: Exchange, 7: Summary
  int _currentStep = 1;

  // Selected State
  String _selectedCategory = 'MC'; // 'MC', 'Scooter', 'BigBike'
  String _selectedCcFilter = 'All'; // 'All', '100 CC', '125 CC', '150 CC', 'On Road'
  Map<String, dynamic>? _selectedVehicle;

  // Colour State
  String _bodyColor = 'Sports Red';
  Color _bodyColorValue = const Color(0xFFDC2626);
  String _bodyFinish = 'Gloss';
  String _tankColor = 'Sports Red';
  Color _tankColorValue = const Color(0xFFDC2626);
  String _tankFinish = 'Gloss';
  String _seatColor = 'Black';
  Color _seatColorValue = const Color(0xFF1E293B);
  String _seatFinish = 'Waterproof Suede';
  String _forksColor = 'Gold';
  Color _forksColorValue = const Color(0xFFD97706);
  String _forksFinish = 'Matte';

  // Accessories State
  final Set<String> _selectedOptionalAccessories = {};

  // Finance State
  String _paymentMode = 'Cash'; // 'Cash' or 'Finance'
  int _loanTenureMonths = 24;
  double _downPaymentAmount = 25000;

  // Exchange State
  bool _wantExchange = false;
  final _exchangeModelController = TextEditingController();
  final _exchangeYearController = TextEditingController(text: '2022');
  final _exchangeKmsController = TextEditingController();
  final _exchangeOfferedPriceController = TextEditingController();
  final _exchangeExpectedPriceController = TextEditingController();

  // Customer Enquiry Submission State
  final _customerNameController = TextEditingController();
  final _customerMobileController = TextEditingController();
  String? _selectedRepId;
  bool _isSubmitting = false;

  // Loaded Vehicles from API
  List<Map<String, dynamic>> _vehiclesList = [];
  bool _isLoadingVehicles = true;

  // Default Fallback Vehicle Catalog (matches prototype images)
  final List<Map<String, dynamic>> _catalog = [
    // Motorcycles (MC)
    {
      'id': 'v-shine100',
      'name': 'Shine 100',
      'code': 'SHN100',
      'category': 'MC',
      'cc': 100,
      'ccCategory': '100 CC',
      'exShowroom': 68767,
      'roadTax': 7500,
      'insurance': 5200,
      'onRoad': 81467,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/shine-100/honda-shine-100-black-with-red-stripes.png',
      'bgGradient': [Color(0xFF881337), Color(0xFFE11D48)],
    },
    {
      'id': 'v-sp125',
      'name': 'SP 125 Disc',
      'code': 'SP125',
      'category': 'MC',
      'cc': 125,
      'ccCategory': '125 CC',
      'exShowroom': 73400,
      'roadTax': 8200,
      'insurance': 5600,
      'onRoad': 87200,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/sp-125/honda-sp-125-matte-marvel-blue-metallic.png',
      'bgGradient': [Color(0xFF1E293B), Color(0xFF334155)],
    },
    {
      'id': 'v-shine125',
      'name': 'Shine 125 Disc',
      'code': 'SHN125',
      'category': 'MC',
      'cc': 125,
      'ccCategory': '125 CC',
      'exShowroom': 78500,
      'roadTax': 8700,
      'insurance': 5800,
      'onRoad': 93000,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/shine/honda-shine-black.png',
      'bgGradient': [Color(0xFF14532D), Color(0xFF16A34A)],
    },
    {
      'id': 'v-cb300f',
      'name': 'CB300F Sports',
      'code': 'CB300F',
      'category': 'MC',
      'cc': 300,
      'ccCategory': '150 CC',
      'exShowroom': 170000,
      'roadTax': 18000,
      'insurance': 11000,
      'onRoad': 199000,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/cb300f/honda-cb300f-sports-red.png',
      'bgGradient': [Color(0xFF991B1B), Color(0xFFDC2626)],
    },
    // Scooters
    {
      'id': 'v-activa110',
      'name': 'Activa 110 Dlx',
      'code': 'ACT110DLX',
      'category': 'Scooter',
      'cc': 110,
      'ccCategory': '100 CC',
      'exShowroom': 82450,
      'roadTax': 9890,
      'insurance': 6240,
      'onRoad': 100380,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/activa-6g/honda-activa-6g-pearl-siren-blue.png',
      'bgGradient': [Color(0xFF0369A1), Color(0xFF0284C7)],
    },
    {
      'id': 'v-dio125',
      'name': 'Dio 125 Smart',
      'code': 'DIO125',
      'category': 'Scooter',
      'cc': 125,
      'ccCategory': '125 CC',
      'exShowroom': 85000,
      'roadTax': 10100,
      'insurance': 6400,
      'onRoad': 103200,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/dio-125/honda-dio-125-sports-red.png',
      'bgGradient': [Color(0xFFC2410C), Color(0xFFEA580C)],
    },
    // Big Bikes
    {
      'id': 'v-cb350hness',
      'name': 'Hness CB350 DLX Pro',
      'code': 'CB350H',
      'category': 'BigBike',
      'cc': 350,
      'ccCategory': 'On Road',
      'exShowroom': 215000,
      'roadTax': 24000,
      'insurance': 14000,
      'onRoad': 255000,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/hness-cb350/honda-hness-cb350-precious-red-metallic.png',
      'bgGradient': [Color(0xFF451A03), Color(0xFF78350F)],
    },
    {
      'id': 'v-cb300r',
      'name': 'CB300R Matte Steel Black',
      'code': 'CB300R',
      'category': 'BigBike',
      'cc': 300,
      'ccCategory': 'On Road',
      'exShowroom': 240000,
      'roadTax': 27000,
      'insurance': 15500,
      'onRoad': 284500,
      'image': 'https://images.carandbike.com/bike-images/colors/honda/cb300r/honda-cb300r-matte-steel-black.png',
      'bgGradient': [Color(0xFF0F172A), Color(0xFF1E293B)],
    },
  ];

  // Optional Accessories List with prices
  final List<Map<String, dynamic>> _optionalAccessoriesList = [
    {
      'name': 'Top Box',
      'price': 3200,
      'icon': Icons.inventory_2_outlined,
      'image': 'https://www.honda2wheelersindia.com/assets/images/accessories/top-box.png',
    },
    {
      'name': 'Windshield',
      'price': 1850,
      'icon': Icons.shield_outlined,
      'image': 'https://www.honda2wheelersindia.com/assets/images/accessories/windshield.png',
    },
    {
      'name': 'Phone Holder',
      'price': 850,
      'icon': Icons.phone_android_outlined,
      'image': 'https://www.honda2wheelersindia.com/assets/images/accessories/mobile-holder.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedRepId = widget.initialRepId;
    _selectedVehicle = _catalog.first; // default to first
    _fetchVehicles();
  }

  @override
  void dispose() {
    _exchangeModelController.dispose();
    _exchangeYearController.dispose();
    _exchangeKmsController.dispose();
    _exchangeOfferedPriceController.dispose();
    _exchangeExpectedPriceController.dispose();
    _customerNameController.dispose();
    _customerMobileController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/vehicles');
      if (res.data is List && (res.data as List).isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(res.data);
        setState(() {
          _vehiclesList = list;
          _isLoadingVehicles = false;
        });
      } else {
        setState(() => _isLoadingVehicles = false);
      }
    } catch (_) {
      setState(() => _isLoadingVehicles = false);
    }
  }

  List<Map<String, dynamic>> get _currentCategoryVehicles {
    List<Map<String, dynamic>> pool = _catalog.where((v) => v['category'] == _selectedCategory).toList();
    if (_selectedCcFilter != 'All' && _selectedCcFilter != 'On Road') {
      pool = pool.where((v) => v['ccCategory'] == _selectedCcFilter).toList();
    }
    if (pool.isEmpty) {
      pool = _catalog.where((v) => v['category'] == _selectedCategory).toList();
    }
    return pool;
  }

  double get _totalAccessoriesPrice {
    double total = 0;
    for (final acc in _optionalAccessoriesList) {
      if (_selectedOptionalAccessories.contains(acc['name'])) {
        total += (acc['price'] as num).toDouble();
      }
    }
    return total;
  }

  double get _estimatedGrandTotal {
    final base = ((_selectedVehicle?['exShowroom'] ?? 68767) as num).toDouble();
    final acc = _totalAccessoriesPrice;
    final rto = ((_selectedVehicle?['roadTax'] ?? 7500) as num).toDouble();
    final ins = ((_selectedVehicle?['insurance'] ?? 5200) as num).toDouble();
    double total = base + acc + rto + ins;

    if (_wantExchange) {
      final exp = double.tryParse(_exchangeExpectedPriceController.text.trim()) ?? 0;
      total = total - exp;
      if (total < 0) total = 0;
    }
    return total;
  }

  void _nextStep() {
    if (_currentStep < 7) {
      setState(() => _currentStep++);
    } else {
      _showCustomerDetailsModal();
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
      backgroundColor: const Color(0xFFFAF9F6), // Warm stone showroom white
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP NAVIGATION HEADER (Honda Logo + Build My Honda + 7-Step Horizontal Stepper) ---
            _buildTopHeader(),

            // --- MAIN STAGE + FLOATING QUOTATION CARD ---
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Configurator Stage (Steps 1 to 7)
                  Expanded(
                    flex: 7,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 20, 24),
                      child: _buildCurrentStepStage(),
                    ),
                  ),

                  // Floating Quotation Sidebar Card (matching prototype)
                  SizedBox(
                    width: 330,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 28, 24),
                      child: _buildQuotationSummaryCard(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER WITH STEPPER (7 STEPS)
  // ==========================================
  Widget _buildTopHeader() {
    final steps = [
      {'num': 1, 'title': 'Choose Ride'},
      {'num': 2, 'title': 'Vehicle'},
      {'num': 3, 'title': 'Colour'},
      {'num': 4, 'title': 'Accessories'},
      {'num': 5, 'title': 'Finance'},
      {'num': 6, 'title': 'Exchange'},
      {'num': 7, 'title': 'Summary'},
    ];

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Honda Red Wing Logo + "Build My Honda"
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentStep > 1) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF64748B)),
                  onPressed: _prevStep,
                  tooltip: 'Previous Step',
                  splashRadius: 18,
                ),
                const SizedBox(width: 4),
              ],
              InkWell(
                onTap: () => context.go('/dashboard'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'H',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'HONDA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      height: 22,
                      width: 1,
                      color: const Color(0xFFCBD5E1),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    const Text(
                      'Build My Honda',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // 7-Step Stepper in Center
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep > i ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  InkWell(
                    onTap: () {
                      if (_currentStep > (steps[i]['num'] as int)) {
                        setState(() => _currentStep = steps[i]['num'] as int);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentStep > (steps[i]['num'] as int)
                                  ? const Color(0xFFDC2626)
                                  : (_currentStep == (steps[i]['num'] as int) ? const Color(0xFFDC2626) : Colors.white),
                              border: Border.all(
                                color: _currentStep >= (steps[i]['num'] as int)
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: _currentStep > (steps[i]['num'] as int)
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : Text(
                                    '${steps[i]['num']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _currentStep == (steps[i]['num'] as int)
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            steps[i]['title'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: _currentStep == (steps[i]['num'] as int)
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: _currentStep == (steps[i]['num'] as int)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Right: Fast Form Switcher + User Avatar + Close button
          OutlinedButton.icon(
            onPressed: () => context.go('/tablet'),
            icon: const Icon(Icons.flash_on, size: 14, color: Color(0xFFDC2626)),
            label: const Text('Quick Form', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Exit to Floor Dashboard',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. CURRENT STEP ROUTING
  // ==========================================
  Widget _buildCurrentStepStage() {
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
      case 7:
        return _buildStep7BuildSummary();
      default:
        return _buildStep1ChooseRide();
    }
  }

  // ==========================================
  // STEP 1: CHOOSE YOUR RIDE (3 CARDS)
  // ==========================================
  Widget _buildStep1ChooseRide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
            children: [
              TextSpan(text: 'CHOOSE YOUR '),
              TextSpan(text: 'RIDE', style: TextStyle(color: Color(0xFFDC2626))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select your two-wheeler category to explore custom configurations',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: Row(
            children: [
              // 1. MC (Motorcycles)
              Expanded(
                child: _buildCategoryCard(
                  code: 'MC',
                  badgeTitle: 'MC',
                  subtitle: 'MOTORCYCLES',
                  imageUrl: 'https://images.carandbike.com/bike-images/colors/honda/cb300f/honda-cb300f-sports-red.png',
                  gradient: const [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFB91C1C)],
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 18),

              // 2. Scooters
              Expanded(
                child: _buildCategoryCard(
                  code: 'Scooter',
                  badgeTitle: 'SCOOTERS',
                  subtitle: 'URBAN COMMUTER',
                  imageUrl: 'https://images.carandbike.com/bike-images/colors/honda/activa-6g/honda-activa-6g-pearl-siren-blue.png',
                  gradient: const [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                  textColor: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 18),

              // 3. Big Bikes
              Expanded(
                child: _buildCategoryCard(
                  code: 'BigBike',
                  badgeTitle: 'BIG BIKES',
                  subtitle: 'PREMIUM & ADVENTURE',
                  imageUrl: 'https://images.carandbike.com/bike-images/colors/honda/hness-cb350/honda-hness-cb350-precious-red-metallic.png',
                  gradient: const [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String code,
    required String badgeTitle,
    required String subtitle,
    required String imageUrl,
    required List<Color> gradient,
    required Color textColor,
  }) {
    final isSelected = _selectedCategory == code;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = code;
          final pool = _catalog.where((v) => v['category'] == code).toList();
          if (pool.isNotEmpty) _selectedVehicle = pool.first;
        });
        _nextStep();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
            width: isSelected ? 3.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x33DC2626) : const Color(0x15000000),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top Title
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badgeTitle,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Center Vehicle Graphic
            Positioned.fill(
              top: 70,
              bottom: 40,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.two_wheeler_outlined, size: 80, color: textColor.withOpacity(0.3)),
                  ),
                ),
              ),
            ),

            // Bottom-Right Red Action Button
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFFDC2626), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: SELECT YOUR VEHICLE (CARDS CAROUSEL)
  // ==========================================
  Widget _buildStep2SelectVehicle() {
    final vehicles = _currentCategoryVehicles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
            children: [
              TextSpan(text: 'SELECT YOUR '),
              TextSpan(text: 'VEHICLE', style: TextStyle(color: Color(0xFFDC2626))),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Filter Chips Row (100 CC, 125 CC, 150 CC, On Road)
        Row(
          children: ['All', '100 CC', '125 CC', '150 CC', 'On Road'].map((f) {
            final isSel = _selectedCcFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedCcFilter = f),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFFDC2626) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Horizontal Row of Vehicle Cards
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final v = vehicles[index];
              final isSel = _selectedVehicle?['id'] == v['id'];

              return SizedBox(
                width: 250,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0), width: isSel ? 2.5 : 1),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Vehicle Visual with background tint
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: (v['bgGradient'] as List<Color>?) ?? [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.network(
                                    v['image'] ?? '',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 70, color: Colors.white70),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chevron_right, color: Color(0xFFDC2626), size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Price & Customise Button
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(v['exShowroom'] ?? 0),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Text(
                                    'Ex-Showroom Price',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                foregroundColor: const Color(0xFFDC2626),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                setState(() => _selectedVehicle = v);
                                _nextStep();
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Customise', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  SizedBox(width: 3),
                                  Icon(Icons.arrow_forward, size: 12),
                                ],
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
          ),
        ),

        const SizedBox(height: 12),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            width: i == 0 ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == 0 ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: CHOOSE YOUR COLOUR (360° + SWATCHES)
  // ==========================================
  Widget _buildStep3ChooseColour() {
    final v = _selectedVehicle ?? _catalog.first;

    return Row(
      children: [
        // Left: 360 View of Vehicle
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'CHOOSE YOUR '),
                    TextSpan(text: 'COLOUR', style: TextStyle(color: Color(0xFFDC2626))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Make it truly yours.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),

              // Big Bike Display
              Center(
                child: SizedBox(
                  height: 240,
                  child: Image.network(
                    v['image'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 140, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // 360° indicator
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_left, size: 18, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text('360°', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_right, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // Right Column: / COLOUR CONFIGURE
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('/ ', style: TextStyle(color: Color(0xFFDC2626), fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'COLOUR CONFIGURE',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Body
                _buildColourRow(
                  label: 'Body',
                  finish: _bodyFinish,
                  selectedColor: _bodyColor,
                  options: [
                    {'name': 'Sports Red', 'color': const Color(0xFFDC2626)},
                    {'name': 'Pearl Siren Blue', 'color': const Color(0xFF1D4ED8)},
                    {'name': 'Matte Steel Black', 'color': const Color(0xFF0F172A)},
                    {'name': 'Pearl White', 'color': const Color(0xFFF1F5F9)},
                  ],
                  onSelect: (name, col) => setState(() {
                    _bodyColor = name;
                    _bodyColorValue = col;
                  }),
                ),

                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                // 2. Tank
                _buildColourRow(
                  label: 'Tank',
                  finish: _tankFinish,
                  selectedColor: _tankColor,
                  options: [
                    {'name': 'Sports Red', 'color': const Color(0xFFDC2626)},
                    {'name': 'Matte Black', 'color': const Color(0xFF0F172A)},
                    {'name': 'Pearl White', 'color': const Color(0xFFF1F5F9)},
                  ],
                  onSelect: (name, col) => setState(() {
                    _tankColor = name;
                    _tankColorValue = col;
                  }),
                ),

                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                // 3. Seat
                _buildColourRow(
                  label: 'Seat',
                  finish: _seatFinish,
                  selectedColor: _seatColor,
                  options: [
                    {'name': 'Black', 'color': const Color(0xFF1E293B)},
                    {'name': 'Dark Brown', 'color': const Color(0xFF78350F)},
                    {'name': 'Gray', 'color': const Color(0xFF94A3B8)},
                  ],
                  onSelect: (name, col) => setState(() {
                    _seatColor = name;
                    _seatColorValue = col;
                  }),
                ),

                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                // 4. Forks
                _buildColourRow(
                  label: 'Forks',
                  finish: _forksFinish,
                  selectedColor: _forksColor,
                  options: [
                    {'name': 'Gold', 'color': const Color(0xFFD97706)},
                    {'name': 'Black', 'color': const Color(0xFF1E293B)},
                  ],
                  onSelect: (name, col) => setState(() {
                    _forksColor = name;
                    _forksColorValue = col;
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColourRow({
    required String label,
    required String finish,
    required String selectedColor,
    required List<Map<String, dynamic>> options,
    required Function(String, Color) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Text(finish, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            final isSel = selectedColor == opt['name'];
            final col = opt['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => onSelect(opt['name'] as String, col),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                      width: isSel ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isSel) const BoxShadow(color: Color(0x33DC2626), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: ADD ACCESSORIES
  // ==========================================
  Widget _buildStep4AddAccessories() {
    final v = _selectedVehicle ?? _catalog.first;

    return Row(
      children: [
        // Left: Bike Hero
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'ADD '),
                    TextSpan(text: 'ACCESSORIES', style: TextStyle(color: Color(0xFFDC2626))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Personalise your ride, your way.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              Center(
                child: SizedBox(
                  height: 240,
                  child: Image.network(
                    v['image'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 140, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // Right Column: Standard Accessories + Optional Accessories
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card 1: Standard Accessories (Included)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standard Accessories (Included)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildAccessoryCard(name: 'Engine Guard', icon: Icons.shield, isIncluded: true, isSelected: true),
                          const SizedBox(width: 10),
                          _buildAccessoryCard(name: 'Tank Pad', icon: Icons.crop_portrait, isIncluded: true, isSelected: true),
                          const SizedBox(width: 10),
                          _buildAccessoryCard(name: 'Seat Cover', icon: Icons.airline_seat_recline_normal, isIncluded: true, isSelected: true),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Card 2: Optional Accessories
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optional Accessories (Add to your build)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _optionalAccessoriesList.map((acc) {
                          final name = acc['name'] as String;
                          final isSel = _selectedOptionalAccessories.contains(name);
                          final price = acc['price'] as int;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isSel) {
                                      _selectedOptionalAccessories.remove(name);
                                    } else {
                                      _selectedOptionalAccessories.add(name);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Icon(
                                          isSel ? Icons.check_circle : Icons.radio_button_unchecked,
                                          size: 16,
                                          color: isSel ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      Icon(acc['icon'] as IconData, size: 28, color: const Color(0xFF334155)),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '+₹$price',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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

  Widget _buildAccessoryCard({required String name, required IconData icon, required bool isIncluded, required bool isSelected}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
            Icon(icon, size: 26, color: const Color(0xFF334155)),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Included',
              style: TextStyle(fontSize: 9.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 5: PAYMENT OPTION (CASH OR FINANCE)
  // ==========================================
  Widget _buildStep5PaymentOption() {
    final v = _selectedVehicle ?? _catalog.first;

    return Row(
      children: [
        // Left: Bike Hero
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'CHOOSE YOUR '),
                    TextSpan(text: 'PAYMENT OPTION', style: TextStyle(color: Color(0xFFDC2626))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Pick what works best for you.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              Center(
                child: SizedBox(
                  height: 240,
                  child: Image.network(
                    v['image'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 140, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // Right: Pay in Cash & Finance Options
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Pay in Cash
              _buildPaymentCard(
                title: 'Pay in Cash',
                subtitle: 'Make a one-time payment and own your Honda.',
                icon: Icons.credit_card_outlined,
                isSelected: _paymentMode == 'Cash',
                onTap: () => setState(() => _paymentMode = 'Cash'),
              ),
              const SizedBox(height: 16),

              // 2. Finance
              _buildPaymentCard(
                title: 'Finance',
                subtitle: 'Own your ride with easy EMI options.',
                icon: Icons.calendar_month_outlined,
                isSelected: _paymentMode == 'Finance',
                onTap: () => setState(() => _paymentMode = 'Finance'),
              ),
              const SizedBox(height: 24),

              // Bottom 3 Value Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _ValueBadge(icon: Icons.percent, text: 'Low Interest Rates'),
                  _ValueBadge(icon: Icons.calendar_today_outlined, text: 'Flexible EMI Tenure'),
                  _ValueBadge(icon: Icons.handshake_outlined, text: 'Hassle-Free Approval'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected) const BoxShadow(color: Color(0x15DC2626), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF475569)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1), width: 2),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 6: EXCHANGE YOUR OLD RIDE
  // ==========================================
  Widget _buildStep6ExchangeRide() {
    final v = _selectedVehicle ?? _catalog.first;

    return Row(
      children: [
        // Left: Bike Hero
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'EXCHANGE YOUR '),
                    TextSpan(text: 'OLD RIDE', style: TextStyle(color: Color(0xFFDC2626))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text('Trade in your current two-wheeler for a better deal.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              Center(
                child: SizedBox(
                  height: 240,
                  child: Image.network(
                    v['image'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 140, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // Right Column: Exchange Form
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Prompt: Do you want to exchange?
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Do you want to exchange your old vehicle?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _wantExchange = true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _wantExchange ? const Color(0xFFFEF2F2) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _wantExchange ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _wantExchange ? const Color(0xFFDC2626) : const Color(0xFF94A3B8), width: 2),
                                      ),
                                      child: _wantExchange
                                          ? Center(
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Yes, I want to exchange', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _wantExchange = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: !_wantExchange ? const Color(0xFFFEF2F2) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !_wantExchange ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: !_wantExchange ? const Color(0xFFDC2626) : const Color(0xFF94A3B8), width: 2),
                                      ),
                                      child: !_wantExchange
                                          ? Center(
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('No, Continue without exchange', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_wantExchange) ...[
                  const SizedBox(height: 16),
                  // Details form
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tell us about your current vehicle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Model',
                                hint: 'e.g. Honda Activa',
                                icon: Icons.two_wheeler,
                                controller: _exchangeModelController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                label: 'Year of Purchase',
                                hint: 'e.g. 2021',
                                icon: Icons.calendar_today,
                                controller: _exchangeYearController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Kms Driven',
                                hint: 'e.g. 25,000',
                                icon: Icons.speed,
                                controller: _exchangeKmsController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                label: 'Offered Price',
                                hint: '₹ e.g. 45,000',
                                icon: Icons.local_offer,
                                controller: _exchangeOfferedPriceController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildInputField(
                          label: 'Your Expected Price',
                          hint: '₹ e.g. 50,000',
                          icon: Icons.account_balance_wallet,
                          controller: _exchangeExpectedPriceController,
                          onChanged: (_) => setState(() {}),
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 7: BUILD SUMMARY
  // ==========================================
  Widget _buildStep7BuildSummary() {
    final v = _selectedVehicle ?? _catalog.first;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Left: Bike Hero + Actions (View 360, Save Build, Share)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                        children: [
                          TextSpan(text: 'YOUR BUILD '),
                          TextSpan(text: 'SUMMARY', style: TextStyle(color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Here\'s your personalised Honda.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    const Spacer(),

                    Center(
                      child: SizedBox(
                        height: 220,
                        child: Image.network(
                          v['image'] ?? '',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.two_wheeler, size: 140, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Action buttons underneath (360°, Save Build, Share)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSummaryIconBtn(icon: Icons.visibility_outlined, label: 'View in 360°'),
                        const SizedBox(width: 16),
                        _buildSummaryIconBtn(icon: Icons.file_download_outlined, label: 'Save Build'),
                        const SizedBox(width: 16),
                        _buildSummaryIconBtn(icon: Icons.share_outlined, label: 'Share'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Right: Your Configuration Card with Edit Pencil Icons
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Your Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),

                      _buildConfigRow(
                        icon: Icons.two_wheeler_outlined,
                        label: 'Vehicle',
                        value: v['name'] ?? 'CB300F',
                        onEdit: () => setState(() => _currentStep = 2),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      _buildConfigRow(
                        icon: Icons.palette_outlined,
                        label: 'Colour',
                        value: _bodyColor,
                        leadingWidget: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: _bodyColorValue, shape: BoxShape.circle),
                        ),
                        onEdit: () => setState(() => _currentStep = 3),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      _buildConfigRow(
                        icon: Icons.settings_outlined,
                        label: 'Accessories',
                        value: _selectedOptionalAccessories.isEmpty
                            ? 'Engine Guard, Tank Pad, Seat Cover'
                            : 'Engine Guard, Tank Pad, ${_selectedOptionalAccessories.join(', ')}',
                        onEdit: () => setState(() => _currentStep = 4),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      _buildConfigRow(
                        icon: Icons.monetization_on_outlined,
                        label: 'Finance',
                        value: _paymentMode == 'Cash' ? 'Pay in Cash' : 'Finance (EMI)',
                        onEdit: () => setState(() => _currentStep = 5),
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      _buildConfigRow(
                        icon: Icons.sync_alt_outlined,
                        label: 'Exchange',
                        value: _wantExchange ? (_exchangeModelController.text.isNotEmpty ? _exchangeModelController.text : 'Exchange Old Ride') : 'No Exchange',
                        onEdit: () => setState(() => _currentStep = 6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bottom Red Action Bar (Email Quote | WhatsApp | Print Quote / Save)
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: Color(0x33DC2626), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBottomActionItem(
                icon: Icons.email_outlined,
                label: 'Email Quote',
                onTap: _showCustomerDetailsModal,
              ),
              Container(width: 1, height: 24, color: Colors.white.withOpacity(0.4)),
              _buildBottomActionItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'WhatsApp',
                onTap: _showCustomerDetailsModal,
              ),
              Container(width: 1, height: 24, color: Colors.white.withOpacity(0.4)),
              _buildBottomActionItem(
                icon: Icons.print_outlined,
                label: 'Print Quote / Save Enquiry',
                onTap: _showCustomerDetailsModal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryIconBtn({required IconData icon, required String label}) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFDC2626)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildConfigRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? leadingWidget,
    required VoidCallback onEdit,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Row(
              children: [
                if (leadingWidget != null) leadingWidget,
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFDC2626)),
          onPressed: onEdit,
          splashRadius: 16,
        ),
      ],
    );
  }

  Widget _buildBottomActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FLOATING QUOTATION CARD (RIGHT SIDEBAR)
  // ==========================================
  Widget _buildQuotationSummaryCard() {
    final v = _selectedVehicle;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Your Quotation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          const Text(
            'Build, customise and see your price in real time.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 24),

          // 5-Point Stage Checklist matching prototype
          _buildQuotationItem(
            icon: Icons.two_wheeler_outlined,
            label: 'Vehicle',
            value: v != null ? (v['name'] as String) : '—',
            isComplete: _currentStep >= 2,
          ),
          const SizedBox(height: 14),

          _buildQuotationItem(
            icon: Icons.palette_outlined,
            label: 'Colour',
            value: _currentStep >= 3 ? _bodyColor : '—',
            isComplete: _currentStep >= 3,
          ),
          const SizedBox(height: 14),

          _buildQuotationItem(
            icon: Icons.settings_outlined,
            label: 'Accessories',
            value: _currentStep >= 4 ? '${_selectedOptionalAccessories.length + 3} Items' : '—',
            isComplete: _currentStep >= 4,
          ),
          const SizedBox(height: 14),

          _buildQuotationItem(
            icon: Icons.monetization_on_outlined,
            label: 'Finance',
            value: _currentStep >= 5 ? (_paymentMode == 'Cash' ? 'Cash' : 'EMI') : '—',
            isComplete: _currentStep >= 5,
          ),
          const SizedBox(height: 14),

          _buildQuotationItem(
            icon: Icons.sync_alt_outlined,
            label: 'Exchange',
            value: _currentStep >= 6 ? (_wantExchange ? 'Exchange' : 'No') : '—',
            isComplete: _currentStep >= 6,
          ),

          const Spacer(),

          // Estimated Price section
          const Text('Estimated Price', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            _currentStep == 1 ? '₹0' : CurrencyFormatter.format(_estimatedGrandTotal),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFFDC2626),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),

          // Big Red Continue Pill Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _nextStep,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep == 7 ? 'Complete Enquiry' : 'Continue',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Icon(_currentStep == 7 ? Icons.check_circle_outline : Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isComplete,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const Spacer(),
        if (isComplete && value != '—') ...[
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 11, color: Colors.white),
          ),
        ] else ...[
          Text('—', style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
        ],
      ],
    );
  }

  // ==========================================
  // CUSTOMER DETAILS & INSTANT SUBMISSION MODAL
  // ==========================================
  void _showCustomerDetailsModal() {
    final v = _selectedVehicle ?? _catalog.first;
    final authState = ref.read(authStateProvider);
    final user = authState.user;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Generate Quotation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configured: ${v['name']} (${_bodyColor})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Estimated Price: ${CurrencyFormatter.format(_estimatedGrandTotal)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Full Name *',
                      hintText: 'Enter customer name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _customerMobileController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Customer Mobile Number *',
                      hintText: '10-digit mobile number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showroom: ${user?.branches.isNotEmpty == true ? user!.branches.first.name : "Phursungi"}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final name = _customerNameController.text.trim();
                        final mobile = _customerMobileController.text.trim();

                        if (name.isEmpty || mobile.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter Customer Name and Mobile Number')),
                          );
                          return;
                        }

                        setDialogState(() => _isSubmitting = true);
                        Navigator.pop(ctx);
                        await _submitEnquiry(name, mobile);
                      },
                child: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save & Generate Quote', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitEnquiry(String customerName, String customerMobile) async {
    setState(() => _isSubmitting = true);
    final authState = ref.read(authStateProvider);
    final user = authState.user;
    final v = _selectedVehicle ?? _catalog.first;

    try {
      final dio = ref.read(dioProvider);
      final branchId = ref.read(selectedBranchIdProvider);
      final activeBranchId = (branchId != 'all' && branchId.isNotEmpty)
          ? branchId
          : (user?.branches.isNotEmpty == true ? user!.branches.first.id : '');

      final payload = {
        'customerName': customerName,
        'customerMobile': customerMobile,
        'enquiryType': 'Walk-in',
        'branchId': activeBranchId,
        'salesExecId': _selectedRepId ?? user?.id,
        'purchaseMode': _paymentMode,
        'buyingWhen': 'Immediate',
        'exchange': _wantExchange ? 'Yes' : 'No',
        'vehicleId': v['id'],
        'colourName': _bodyColor,
        'grandTotal': _estimatedGrandTotal,
        'remarks': 'Build My Honda Tab Generator · ${_selectedCategory} · $_bodyColor',
      };

      await dio.post('/enquiries', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Quotation generated successfully for $customerName! Broadcasted to live floor.')),
              ],
            ),
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit enquiry: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _ValueBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ValueBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFDC2626)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
      ],
    );
  }
}
