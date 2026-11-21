import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/breakpoints.dart';
import '../../core/networking/api_client.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController(text: '9999999999');
  final _passwordController = TextEditingController(text: 'YashHonda@2026');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();
    if (mobile.isEmpty || password.isEmpty) return;

    ref.read(authStateProvider.notifier).login(mobile, password);
  }

  void _fillCredentials(String mobile, String roleName) {
    setState(() {
      _mobileController.text = mobile;
      _passwordController.text = 'YashHonda@2026';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filled credentials for $roleName ($mobile)'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final forgotMobileController =
        TextEditingController(text: _mobileController.text.trim());
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isOtpSent = false;
    bool isSubmitting = false;
    String? errorMessage;
    String? generatedOtp;
    bool obscureNew = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> sendOtp() async {
              final mobile = forgotMobileController.text.trim();
              if (mobile.isEmpty || mobile.length < 10) {
                setDialogState(
                    () => errorMessage = 'Please enter a valid 10-digit mobile number');
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                final dio = ref.read(dioProvider);
                final res = await dio.post('/auth/forgot-password', data: {
                  'mobile': mobile,
                });
                final data = res.data;
                setDialogState(() {
                  isOtpSent = true;
                  isSubmitting = false;
                  generatedOtp = data['devOtp']?.toString() ?? '123456';
                  otpController.text = generatedOtp!;
                });
              } catch (e) {
                // In demo/offline fallback mode, simulate instant OTP delivery
                setDialogState(() {
                  isOtpSent = true;
                  isSubmitting = false;
                  generatedOtp = '123456';
                  otpController.text = '123456';
                });
              }
            }

            Future<void> handleResetPassword() async {
              final mobile = forgotMobileController.text.trim();
              final otp = otpController.text.trim();
              final newPass = newPasswordController.text.trim();
              final confirmPass = confirmPasswordController.text.trim();

              if (otp.isEmpty || otp.length < 4) {
                setDialogState(() => errorMessage = 'Please enter the 6-digit verification OTP');
                return;
              }
              if (newPass.isEmpty || newPass.length < 6) {
                setDialogState(() => errorMessage = 'New password must be at least 6 characters');
                return;
              }
              if (newPass != confirmPass) {
                setDialogState(() => errorMessage = 'Passwords do not match');
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              try {
                final dio = ref.read(dioProvider);
                await dio.post('/auth/reset-password', data: {
                  'mobile': mobile,
                  'otp': otp,
                  'newPassword': newPass,
                });

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {
                  _mobileController.text = mobile;
                  _passwordController.text = newPass;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset successfully! Logging you in...'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                  ref.read(authStateProvider.notifier).login(mobile, newPass);
                }
              } catch (e) {
                setDialogState(() {
                  isSubmitting = false;
                  errorMessage = e is DioException
                      ? (e.response?.data?['message']?.toString() ?? 'Failed to reset password')
                      : 'Reset failed. Please try again.';
                });
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFDC2626), size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reset Staff Password',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Self-serve OTP reset for registered staff',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                          onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!isOtpSent) ...[
                      const Text(
                        'Registered Mobile Number',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                            const Text(
                              '+91',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: forgotMobileController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '10-digit mobile number',
                                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSubmitting ? null : sendOtp,
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Send Reset OTP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'OTP sent to +91 ${forgotMobileController.text.trim()} (Demo OTP: $generatedOtp)',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text('6-Digit Verification OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '123456',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text('New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: newPasswordController,
                          obscureText: obscureNew,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'At least 6 characters',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 16, color: const Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text('Confirm New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: confirmPasswordController,
                          obscureText: obscureNew,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Re-enter password',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isSubmitting ? null : handleResetPassword,
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Reset Password & Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Branch Managers and Super Admins can also reset passwords directly from Admin Panel > Users.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: ResponsiveLayout(
        phone: _buildMobileView(authState),
        tablet: _buildTabletView(authState),
        desktop: _buildDesktopView(authState),
      ),
    );
  }

  // --- Right Login Form matching prototype screenshot ---
  Widget _buildLoginForm(AuthState authState) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in with your registered mobile number.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),

          // Main Card
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (authState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mobile number field
                const Text(
                  'Mobile number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 17, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '98765 43210',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF94A3B8),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Password field + Forgot password?
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    InkWell(
                      onTap: _showForgotPasswordDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 17, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter password',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF94A3B8),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Sign in Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: authState.isLoading ? null : _submit,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Quick demo accounts section
          const Text(
            'DEMO ACCOUNTS — TAP TO FILL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildDemoCard(
                  title: 'Super Admin',
                  icon: Icons.shield_outlined,
                  onTap: () => _fillCredentials('9999999999', 'Super Admin'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDemoCard(
                  title: 'Branch Manager',
                  icon: Icons.manage_accounts_outlined,
                  onTap: () => _fillCredentials('9888888888', 'Branch Manager'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDemoCard(
                  title: 'Sales Executive',
                  icon: Icons.verified_user_outlined,
                  onTap: () => _fillCredentials('9777777777', 'Sales Executive'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () => _fillCredentials('8888888888', 'Owner'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_border_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      'Or sign in as Dealership Owner (8888888888)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x03000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFDC2626)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileView(AuthState authState) {
    return Container(
      color: const Color(0xFFFAF9F6),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: _buildLoginForm(authState),
        ),
      ),
    );
  }

  Widget _buildTabletView(AuthState authState) {
    return Container(
      color: const Color(0xFFFAF9F6),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: _buildLoginForm(authState),
        ),
      ),
    );
  }

  // --- Left Hero Panel matching prototype screenshot ---
  Widget _buildDesktopView(AuthState authState) {
    return Row(
      children: [
        // Left Branding Hero Panel with subtle technical grid lines
        Expanded(
          flex: 6,
          child: Container(
            color: const Color(0xFF080C14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: const GridLinesPainter(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Brand Logo
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                'H',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YASH HONDA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Multi-branch Dealership CRM',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Main Center Hero Content
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Red category tag
                          const Text(
                            'ENQUIRY & CRM',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Big Headline
                          const Text(
                            'Every walk-in, call and\nfollow-up. One place.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Subtitle
                          const Text(
                            'Live enquiries from all six Pune branches, with AI summaries and a real-time floor dashboard.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // 6 Pune Branches Table Box
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Column(
                              children: [
                                _buildBranchRow(
                                  col1Name: 'Phursungi',
                                  col1Badge: 'BigWing',
                                  col2Name: 'Wadki',
                                  col2Badge: 'RedWing',
                                ),
                                Container(height: 1, color: const Color(0xFF1E293B)),
                                _buildBranchRow(
                                  col1Name: 'Saswad',
                                  col1Badge: 'RedWing',
                                  col2Name: 'Uruli Kanchan',
                                  col2Badge: 'RedWing',
                                ),
                                Container(height: 1, color: const Color(0xFF1E293B)),
                                _buildBranchRow(
                                  col1Name: 'BT Kawade',
                                  col1Badge: 'RedWing',
                                  col2Name: 'Sasane Nagar',
                                  col2Badge: 'RedWing',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Footer
                      const Text(
                        '© 2026 Yash Honda Two-Wheelers Pvt Ltd · Authorized Honda Dealership',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Login Form on warm stone backdrop
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFFAF9F6),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: _buildLoginForm(authState),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchRow({
    required String col1Name,
    required String col1Badge,
    required String col2Name,
    required String col2Badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Text(
                  col1Name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  col1Badge,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.symmetric(horizontal: 18),
          ),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Text(
                  col2Name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  col2Badge,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle technical architectural grid pattern for the left hero panel
class GridLinesPainter extends CustomPainter {
  final Color lineColor;
  final double step;

  const GridLinesPainter({
    this.lineColor = const Color(0x18FFFFFF), // ~9.4% subtle white lines
    this.step = 46.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
