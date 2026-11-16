import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/server_settings_dialog.dart';
import '../providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Name and mobile number start completely empty - no prefill
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _errorMessage;
  bool _isFraudDetected = false;

  void _onPhoneChanged(String val) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      final isRepeating = RegExp(r'^(\d)\1{9}$').hasMatch(digits);
      final isValidPrefix = RegExp(r'^[6-9]\d{9}$').hasMatch(digits);

      if (!isValidPrefix || isRepeating) {
        setState(() {
          _isFraudDetected = true;
          _errorMessage = 'Invalid mobile number. Please enter a valid 10-digit mobile number.';
        });
        return;
      }

      setState(() {
        _isFraudDetected = false;
      });
    } else {
      if (_isFraudDetected) {
        setState(() {
          _isFraudDetected = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleEmergencyQuickAccess() async {
    final rawInput = _phoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    final effectivePhone = digits.length == 10 ? '+91 $digits' : '+91 8428304510';
    await _completeEmergencyAccess(effectivePhone);
  }

  Future<void> _completeEmergencyAccess(String simPhone) async {
    final success = await ref.read(authProvider.notifier).signInAsEmergencyGuest(
          genuineSimPhone: simPhone,
          callerName: _nameController.text.trim(),
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _handleSignIn() async {
    final rawInput = _phoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');

    // Validate genuine Indian SIM mobile number (must be exactly 10 digits starting with 6, 7, 8, or 9)
    if (digits.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    final simNumberPattern = RegExp(r'^[6-9]\d{9}$');
    if (!simNumberPattern.hasMatch(digits)) {
      setState(() {
        _errorMessage = 'Invalid SIM mobile number. Indian mobile numbers must start with 6, 7, 8, or 9.';
      });
      return;
    }

    if (_isFraudDetected) {
      setState(() {
        _errorMessage = 'Fraud Alert: Suspicious or dummy number cannot be used. Please use your genuine SIM.';
      });
      return;
    }

    setState(() => _errorMessage = null);

    // Save user session with this verified SIM number and entered name (if any) and go to Home Screen
    final success = await ref
        .read(authProvider.notifier)
        .signInWithPhoneNumber(digits, name: _nameController.text.trim());

    if (success && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final strings = AppStrings(Locale(authState.selectedLocale));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Switcher (EN / TA)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _langChip('en', 'EN', authState.selectedLocale),
                      _langChip('ta', 'தமிழ்', authState.selectedLocale),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Emergency Brand Badge
              Center(
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.redGlowShadow,
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                strings.get('appName'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Rapid Emergency Medical Response & Real-Time Tracking',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),

              // Login Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softCardShadow,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Emergency Mobile Access',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your genuine SIM mobile number to connect with 108 emergency dispatchers and ambulances in real time.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Full Name Field (empty by default, no prefill)
                    const Text(
                      'Full Name (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                        hintText: 'Enter your full name',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primaryRed,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone Input Field
                    const Text(
                      'Mobile Number (SIM Card)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: _onPhoneChanged,
                      onSubmitted: (_) => _handleSignIn(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                color: AppColors.primaryRed,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '+91',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '|',
                                style: TextStyle(
                                  color: AppColors.border,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        hintText: 'Enter 10-digit SIM number',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 0,
                        ),
                        errorText: _errorMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primaryRed,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Direct Enter Button
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Enter LifeRoute Emergency',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showUserServerSettingsDialog(context, ref),
                        icon: const Icon(Icons.tune_rounded, size: 14, color: AppColors.textSecondary),
                        label: const Text(
                          'Emergency Dispatch Server Settings',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _langChip(String code, String label, String currentLocale) {
    final isSelected = currentLocale == code;
    return GestureDetector(
      onTap: () => ref.read(authProvider.notifier).setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
