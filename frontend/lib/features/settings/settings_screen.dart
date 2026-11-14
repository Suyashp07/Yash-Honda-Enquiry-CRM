import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/networking/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankController = TextEditingController();
  final _accController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();
  final _hypoController = TextEditingController();
  bool _applyHypo = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/settings');
      final s = res.data;

      setState(() {
        _nameController.text = s['companyName'] ?? '';
        _gstController.text = s['gstNumber'] ?? '';
        _addressController.text = s['address'] ?? '';
        _bankController.text = s['bankName'] ?? '';
        _accController.text = s['accountNumber'] ?? '';
        _ifscController.text = s['ifsc'] ?? '';
        _upiController.text = s['upiId'] ?? '';
        _hypoController.text = s['hypothecationCharge']?.toString() ?? '0';
        _applyHypo = s['applyHypothecationDefault'] ?? true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/settings', data: {
        'companyName': _nameController.text.trim(),
        'gstNumber': _gstController.text.trim(),
        'address': _addressController.text.trim(),
        'bankName': _bankController.text.trim(),
        'accountNumber': _accController.text.trim(),
        'ifsc': _ifscController.text.trim(),
        'upiId': _upiController.text.trim(),
        'hypothecationCharge': num.tryParse(_hypoController.text.trim()) ?? 0,
        'applyHypothecationDefault': _applyHypo,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company Profile & Settings updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dealership Profile & Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Company billing defaults, official quotation headers, and bank details', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Company Legal Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Company Trade Name')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _gstController, decoration: const InputDecoration(labelText: 'GSTIN Number'))),
                          const SizedBox(width: 14),
                          Expanded(child: TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Registered Office Address'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dealership Bank Account (Quotation Proforma)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _bankController, decoration: const InputDecoration(labelText: 'Bank Name'))),
                          const SizedBox(width: 14),
                          Expanded(child: TextField(controller: _accController, decoration: const InputDecoration(labelText: 'Account Number'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _ifscController, decoration: const InputDecoration(labelText: 'IFSC Code'))),
                          const SizedBox(width: 14),
                          Expanded(child: TextField(controller: _upiController, decoration: const InputDecoration(labelText: 'UPI VPA / QR ID'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commercial Finance Defaults', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _hypoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Default Hypothecation Charge (₹)'),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto-apply Hypothecation on Finance Quotes', style: TextStyle(fontSize: 14)),
                        value: _applyHypo,
                        onChanged: (val) => setState(() => _applyHypo = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

