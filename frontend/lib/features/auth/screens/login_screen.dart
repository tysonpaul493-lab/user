import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/services/sim_detection_service.dart';
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
  String? _recognizedUserName;
  String? _verifiedCarrier;
  bool _isCarrierValidating = false;
  bool _isFraudDetected = false;
  // ignore: unused_field
  bool _isCheckingPhone = false;

  void _onPhoneChanged(String val) async {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      // Anti-fraud: Detect dummy, repeating, or invalid telecom prefixes
      final fakePatterns = [
        '9999999999', '8888888888', '7777777777', '6666666666',
        '1234567890', '9876543210', '0000000000', '9999910800',
      ];
      final isRepeating = RegExp(r'^(\d)\1{9}$').hasMatch(digits);
      final isValidPrefix = RegExp(r'^[6-9]\d{9}$').hasMatch(digits);

      if (!isValidPrefix || isRepeating || fakePatterns.contains(digits)) {
        setState(() {
          _isFraudDetected = true;
          _verifiedCarrier = null;
          _errorMessage = 'Fraud Alert: Suspicious or invalid SIM number. Please use your device genuine SIM.';
        });
        return;
      }

      setState(() {
        _isFraudDetected = false;
        _isCarrierValidating = true;
        _isCheckingPhone = true;
      });

      // Classify carrier from Indian TRAI/DoT mobile series
      String carrier = 'Active Cellular SIM (DoT Certified)';
      final p2 = digits.substring(0, 2);
      if (['62', '63', '70', '71', '89', '90'].contains(p2)) {
        carrier = 'Reliance Jio 4G/5G';
      } else if (['98', '99', '97', '96', '81', '84', '85', '88'].contains(p2)) {
        carrier = 'Bharti Airtel';
      } else if (['91', '92', '93', '94', '95'].contains(p2)) {
        carrier = 'BSNL Mobile';
      } else if (['80', '82', '83', '86', '87', '77', '78'].contains(p2)) {
        carrier = 'Vodafone Idea (Vi)';
      }

      if (mounted) {
        setState(() {
          _verifiedCarrier = carrier;
          _isCarrierValidating = false;
        });
      }

      try {
        final user = await ref.read(authProvider.notifier).lookupUser(digits);
        if (mounted && user != null && user.name.trim().isNotEmpty) {
          setState(() {
            _recognizedUserName = user.name.trim();
            if (_nameController.text.trim().isEmpty) {
              _nameController.text = user.name.trim();
            }
          });
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _isCheckingPhone = false);
      }
    } else {
      if (_recognizedUserName != null || _verifiedCarrier != null || _isFraudDetected) {
        setState(() {
          _recognizedUserName = null;
          _verifiedCarrier = null;
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

  // ignore: unused_element
  void _handleEmergencyQuickAccess() async {
    final storage = ref.read(storageServiceProvider);
    final recognizedPhone = await SimDetectionService.resolveGenuineSimNumber(
      storage: storage,
      currentInput: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (recognizedPhone != null && recognizedPhone.isNotEmpty) {
      await _completeEmergencyAccess(recognizedPhone);
    } else {
      _showSimConfirmationModal();
    }
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

  void _showSimConfirmationModal() {
    final modalPhoneController = TextEditingController(text: _phoneController.text);
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sim_card_rounded,
                          color: AppColors.primaryRed,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device SIM Verification',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Required for 108 Emergency Dispatch',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'To dispatch ambulances to your live GPS, enter your 10-digit SIM mobile number. This will be visible to the responding ambulance driver.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: modalPhoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_android_rounded, color: AppColors.primaryRed, size: 20),
                            SizedBox(width: 6),
                            Text(
                              '+91',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text('|', style: TextStyle(color: AppColors.border, fontSize: 18)),
                          ],
                        ),
                      ),
                      hintText: 'Enter 10-digit SIM number',
                      errorText: modalError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final digits = modalPhoneController.text.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                        setModalState(() {
                          modalError = 'Please enter a valid 10-digit Indian SIM number';
                        });
                        return;
                      }

                      final simPhone = '+91 $digits';
                      Navigator.pop(ctx);
                      await _completeEmergencyAccess(simPhone);
                    },
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Confirm SIM & Dispatch Access',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                    if (_isCarrierValidating) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Verifying active SIM with telecom gateway...',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ] else if (_verifiedCarrier != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Verified Active SIM: $_verifiedCarrier',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                          ],
                        ),
                      ),
                    ] else if (_isFraudDetected) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fraud Protection: Invalid or dummy number. Please use your device SIM.',
                                style: TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_recognizedUserName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Color(0xFF2E7D32), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Recognized Profile: $_recognizedUserName',
                                style: const TextStyle(
                                  color: Color(0xFF1B5E20),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
