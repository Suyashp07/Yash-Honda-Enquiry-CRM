import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/auth_notifier.dart';

class CustomizeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> vehicle;

  const CustomizeScreen({super.key, required this.vehicle});

  @override
  ConsumerState<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends ConsumerState<CustomizeScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  String _purchaseMode = 'Finance';
  String _exchange = 'No';
  String _selectedColour = '';
  String? _selectedBranchId;
  String? _selectedFinancierId;

  List<dynamic> _availableAccessories = [];
  List<dynamic> _financiers = [];
  final Set<String> _selectedAccessoryIds = {};
  final Map<String, double> _accessoryPriceOverrides = {};

  bool _isCalculating = false;
  Map<String, dynamic>? _liveCalculation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final colours = (widget.vehicle['colours'] as List?) ?? [];
    if (colours.isNotEmpty) {
      _selectedColour = colours.first['colour']?['name'] ?? '';
    }

    final user = ref.read(authStateProvider).user;
    if (user != null && user.branches.isNotEmpty) {
      _selectedBranchId = user.branches.first.id;
    }

    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final dio = ref.read(dioProvider);
      final [accRes, finRes] = await Future.wait([
        dio.get('/accessories'),
        dio.get('/financiers'),
      ]);

      setState(() {
        _availableAccessories = accRes.data;
        _financiers = finRes.data;
      });

      _calculateQuote();
    } catch (_) {}
  }

  Future<void> _calculateQuote() async {
    if (_selectedBranchId == null) return;
    setState(() => _isCalculating = true);

    try {
      final dio = ref.read(dioProvider);
      final accList = _selectedAccessoryIds.map((id) {
        return {
          'accessoryId': id,
          'amount': _accessoryPriceOverrides[id],
        };
      }).toList();

      final res = await dio.post('/quotations/calculate', data: {
        'vehicleId': widget.vehicle['id'],
        'branchId': _selectedBranchId,
        'colourName': _selectedColour,
        'purchaseMode': _purchaseMode,
        'accessories': accList,
      });

      setState(() {
        _liveCalculation = res.data;
        _isCalculating = false;
      });
    } catch (_) {
      setState(() => _isCalculating = false);
    }
  }

  Future<void> _saveEnquiry() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    if (name.isEmpty || mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Customer Name and 10-digit Mobile')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);
      final accList = _selectedAccessoryIds.map((id) {
        return {
          'accessoryId': id,
          'amount': _accessoryPriceOverrides[id],
        };
      }).toList();

      final res = await dio.post('/enquiries', data: {
        'branchId': _selectedBranchId,
        'customer': {
          'name': name,
          'mobile': mobile,
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        },
        'enquiryType': 'Walk-in',
        'purchaseMode': _purchaseMode,
        'financierId': _selectedFinancierId,
        'exchange': _exchange,
        'quotation': {
          'vehicleId': widget.vehicle['id'],
          'colourName': _selectedColour,
          'accessories': accList,
        },
      });

      final enquiry = res.data;
      final quotation = (enquiry['quotations'] as List).first;

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
    if (widget.vehicle.isEmpty || widget.vehicle['id'] == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Customize Enquiry')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.two_wheeler, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('Please select a vehicle model first to customize quote.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/enquiries/vehicle-picker'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Go to Vehicle Picker'),
              ),
            ],
          ),
        ),
      );
    }

    final colours = (widget.vehicle['colours'] as List?) ?? [];
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Customize — ${widget.vehicle['name']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/enquiries/vehicle-picker'),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Form Controls
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch selection (if user has multiple branches)
                  if (user != null && user.branches.length > 1) ...[
                    const Text('Dealership Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedBranchId,
                      items: user.branches.map((b) => DropdownMenuItem(value: b.id, child: Text('${b.code} - ${b.name}'))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedBranchId = val);
                        _calculateQuote();
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Customer Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer Contact Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(labelText: 'Customer Full Name *'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(labelText: '10-Digit Mobile *'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(labelText: 'Email Address (Optional)'),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _addressController,
                                  decoration: const InputDecoration(labelText: 'Locality / Address'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Colour Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vehicle Colour', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: colours.map((vc) {
                              final cName = vc['colour']?['name'] ?? '';
                              final hexStr = vc['colour']?['hex'] ?? '#CCCCCC';
                              final isSel = _selectedColour == cName;
                              final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));

                              return ChoiceChip(
                                avatar: CircleAvatar(backgroundColor: color, radius: 8),
                                label: Text(cName, style: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary)),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedColour = cName);
                                    _calculateQuote();
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Purchase Mode & Exchange
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Purchase & Commercial Options', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    SegmentedButton<String>(
                                      segments: const [
                                        ButtonSegment(value: 'Cash', label: Text('Cash')),
                                        ButtonSegment(value: 'Finance', label: Text('Finance (Loan)')),
                                      ],
                                      selected: {_purchaseMode},
                                      onSelectionChanged: (set) {
                                        setState(() => _purchaseMode = set.first);
                                        _calculateQuote();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Old Vehicle Exchange', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: _exchange,
                                      items: const [
                                        DropdownMenuItem(value: 'No', child: Text('No Exchange')),
                                        DropdownMenuItem(value: 'Yes', child: Text('Yes — Customer Exchange')),
                                        DropdownMenuItem(value: 'Yes & Print', child: Text('Yes & Print Evaluation')),
                                      ],
                                      onChanged: (val) => setState(() => _exchange = val ?? 'No'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_purchaseMode == 'Finance' && _financiers.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Preferred Financier Partner'),
                              value: _selectedFinancierId,
                              items: _financiers.map((f) => DropdownMenuItem(value: f['id'].toString(), child: Text(f['name']))).toList(),
                              onChanged: (val) => setState(() => _selectedFinancierId = val),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Accessories Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Add-on Accessories', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          const Text('Items tagged FIX cannot have amount modified; others can be discounted.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          const SizedBox(height: 12),
                          ..._availableAccessories.map((acc) {
                            final id = acc['id'].toString();
                            final isSel = _selectedAccessoryIds.contains(id);
                            final isEditable = acc['isPriceEditable'] == true;
                            final rawPrice = acc['defaultPrice'];
                            final defaultPrice = rawPrice is num
                                ? rawPrice.toDouble()
                                : (double.tryParse(rawPrice?.toString() ?? '') ?? 0.0);
                            final currentPrice = _accessoryPriceOverrides[id] ?? defaultPrice;

                            return CheckboxListTile(
                              value: isSel,
                              dense: true,
                              title: Row(
                                children: [
                                  Text(acc['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isEditable ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isEditable ? 'EDITABLE' : 'FIX',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isEditable ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(CurrencyFormatter.format(currentPrice)),
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
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Real-time Live Quotation Summary Card
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Live Quotation Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Model: ${widget.vehicle['name']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const Divider(height: 28),

                  if (_isCalculating)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  else if (_liveCalculation != null) ...[
                    // Itemized table
                    ...(_liveCalculation!['items'] as List).map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(it['label'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(CurrencyFormatter.format(it['amount']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    if ((_liveCalculation!['accessories'] as List).isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text('Selected Accessories:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      ...(_liveCalculation!['accessories'] as List).map((acc) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('+ ${acc['name']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(CurrencyFormatter.format(acc['amount']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                    ],
                    const Divider(height: 28),

                    // Grand Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GRAND TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        Text(
                          CurrencyFormatter.format(_liveCalculation!['grandTotal']),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEnquiry,
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Enquiry & Generate Quote', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

