import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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
  // Input Controllers - Name and Phone only
  final _nameController = TextEditingController();
  final _loginPhoneController = TextEditingController();

  String? _errorMessage;
  String? _successMessage;
  bool _isFraudDetected = false;
  SimInfoResult? _detectedSimInfo;

  @override
  void initState() {
    super.initState();
    _initSimAndUserData();
  }

  Future<void> _initSimAndUserData() async {
    // Prefill from cached user if available
    final savedUser = ref.read(authProvider).user;
    if (savedUser != null) {
      if (savedUser.name.isNotEmpty &&
          _nameController.text.isEmpty &&
          savedUser.name != 'Emergency Caller') {
        _nameController.text = savedUser.name;
      }
      final clean = savedUser.phone.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10 && _loginPhoneController.text.isEmpty) {
        _loginPhoneController.text = clean.substring(clean.length - 10);
      }
    }

    // Detect hardware SIM info from Android TelephonyManager/SubscriptionManager
    try {
      final simInfo = await SimDetectionService.detectSimInfo();
      if (mounted) {
        setState(() {
          _detectedSimInfo = simInfo;
          // Auto-fill phone field if hardware identified SIM number and field is currently empty
          if (_loginPhoneController.text.isEmpty && simInfo.simNumber != null) {
            final digits = simInfo.simNumber!.replaceAll(RegExp(r'\D'), '');
            if (digits.length >= 10) {
              _loginPhoneController.text = digits.substring(digits.length - 10);
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _loginPhoneController.dispose();
    super.dispose();
  }

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
          _errorMessage =
              'Invalid mobile number. Please enter a valid 10-digit Indian SIM number.';
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

  void _handleLogin() async {
    final authState = ref.read(authProvider);
    final isTamil = authState.selectedLocale == 'ta';

    final name = _nameController.text.trim();
    final rawInput = _loginPhoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty || name.length < 2) {
      setState(() {
        _errorMessage = isTamil
            ? 'தயவுசெய்து உங்கள் முழு பெயரை உள்ளிடவும் (குறைந்தபட்சம் 2 எழுத்துக்கள்).'
            : 'Please enter your Full Name (at least 2 characters).';
        _successMessage = null;
      });
      return;
    }

    if (digits.length != 10) {
      setState(() {
        _errorMessage = isTamil
            ? 'செல்லுபடியாகும் 10-இலக்க மொபைல் எண்ணை உள்ளிடவும்.'
            : 'Please enter a valid 10-digit mobile number';
        _successMessage = null;
      });
      return;
    }

    final simNumberPattern = RegExp(r'^[6-9]\d{9}$');
    if (!simNumberPattern.hasMatch(digits)) {
      setState(() {
        _errorMessage = isTamil
            ? 'தவறான மொபைல் எண். இந்திய எண்கள் 6, 7, 8 அல்லது 9 இல் தொடங்க வேண்டும்.'
            : 'Invalid mobile number. Indian mobile numbers must start with 6, 7, 8, or 9.';
        _successMessage = null;
      });
      return;
    }

    if (_isFraudDetected) {
      setState(() {
        _errorMessage = isTamil
            ? 'மோசடி எச்சரிக்கை: போலியான அல்லது மீண்டும் வரும் எண்களை பயன்படுத்த முடியாது.'
            : 'Fraud Alert: Suspicious repeating or dummy number cannot be used.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    // Enforce physical SIM verification (verifies phone number is inserted in this mobile device)
    final simResult = await SimDetectionService.verifyDeviceSim(
      enteredPhone: digits,
      isTamil: isTamil,
    );

    if (!simResult.isValid) {
      setState(() {
        _errorMessage = simResult.errorMessage ??
            (isTamil
                ? 'SIM அட்டை சரிபார்ப்பு தோல்வியடைந்தது.'
                : 'Device SIM card verification failed.');
      });
      return;
    }

    final success = await ref.read(authProvider.notifier).loginWithPhone(
          digits,
          name: name,
          simNumber: simResult.detectedSimNumber,
          carrier: simResult.carrier,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      final authError = ref.read(authProvider).errorMessage;
      setState(() {
        _errorMessage = authError ??
            (isTamil
                ? 'உள்நுழைவு தோல்வியடைந்தது. தயவுசெய்து உங்கள் SIM விவரங்களை சரிபார்க்கவும்.'
                : 'Unable to sign in. Please verify your SIM number and try again.');
      });
    }
  }

  void _handleEmergencyQuickAccess() async {
    final rawInput = _loginPhoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    final effectivePhone =
        digits.length == 10 ? '+91 $digits' : '+91 8428304510';
    final nameInput = _nameController.text.trim();
    final callerName = nameInput.isNotEmpty ? nameInput : 'Emergency Caller';

    final success =
        await ref.read(authProvider.notifier).signInAsEmergencyGuest(
              genuineSimPhone: effectivePhone,
              callerName: callerName,
            );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isTamil = authState.selectedLocale == 'ta';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
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
              const SizedBox(height: 20),

              // Trust Official Logo Brand Badge
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primaryRed.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                isTamil
                    ? 'ஆல் இந்தியா தமிழ் அனைத்து அறக்கட்டளை'
                    : 'All India Tamil All Trust',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isTamil
                    ? 'தமிழ்நாடு அவசர ஊர்தி சேவை • நேரடி கண்காணிப்பு'
                    : 'Tamil Nadu Emergency Medical Response & Tracking',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(height: 20),

              // Success Message Banner
              if (_successMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Error Message Banner (Validation / Fraud / SIM Mismatch)
              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Single Unified Card Container - Full Name & Phone Number with SIM Verification
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softCardShadow,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTamil ? 'அவசர கால உள்நுழைவு' : 'Emergency User Login',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isTamil
                          ? 'உங்கள் பெயர் மற்றும் SIM மொபைல் எண்ணை உள்ளிடவும்.'
                          : 'Enter your Full Name and active SIM mobile number to sign in.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // SIM Hardware Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sim_card_rounded,
                            size: 16,
                            color: AppColors.primaryRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _detectedSimInfo != null &&
                                      _detectedSimInfo!.carrier != null
                                  ? (isTamil
                                      ? 'செயலில் உள்ள SIM: ${_detectedSimInfo!.carrier} • வன்பொருள் சரிபார்ப்பு'
                                      : 'Active SIM: ${_detectedSimInfo!.carrier} • Hardware Guard')
                                  : (isTamil
                                      ? 'SIM சரிபார்ப்பு: இந்த போனில் உள்ள SIM மட்டுமே ஏற்கப்படும்'
                                      : 'SIM Verification: Only inserted SIM card permitted'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name Input Field
                    Text(
                      isTamil ? 'முழு பெயர் *' : 'Full Name *',
                      style: const TextStyle(
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
                          fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primaryRed,
                          size: 20,
                        ),
                        hintText: isTamil
                            ? 'உங்கள் முழு பெயரை உள்ளிடவும்'
                            : 'Enter your full name',
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
                              color: AppColors.primaryRed, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Input Field
                    Text(
                      isTamil
                          ? 'மொபைல் எண் (SIM அட்டை) *'
                          : 'Mobile Number (SIM Card) *',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _loginPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: _onPhoneChanged,
                      onSubmitted: (_) => _handleLogin(),
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
                              horizontal: 14, vertical: 12),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android_rounded,
                                  color: AppColors.primaryRed, size: 20),
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
                              Text('|',
                                  style: TextStyle(
                                      color: AppColors.border, fontSize: 18)),
                            ],
                          ),
                        ),
                        hintText: isTamil
                            ? '10-இலக்க மொபைல் எண்'
                            : 'Enter 10-digit mobile number',
                        hintStyle: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 0,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.primaryRed, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Verify SIM & Sign In Button
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isTamil
                                        ? 'SIM சரிபார்த்து உள்நுழைக'
                                        : 'Verify SIM & Sign In',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Anti-Spam Security Reassurance Note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security_rounded,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isTamil
                                ? 'தவறான பயன்பாட்டை தடுக்க உங்கள் போனில் உள்ள SIM மட்டுமே ஏற்கப்படும்.'
                                : 'To prevent spam, only the active SIM card on this phone is allowed.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Emergency 1-Tap SOS Access (For genuine distress)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextButton.icon(
                  onPressed: _handleEmergencyQuickAccess,
                  icon: const Icon(Icons.emergency_rounded,
                      color: AppColors.primaryRed, size: 20),
                  label: Text(
                    isTamil
                        ? '1-தட்டு உடனடி அவசர உதவி (உள்நுழைவு தேவையில்லை)'
                        : 'Instant 1-Tap Emergency SOS (Skip Login)',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  onPressed: () => showUserServerSettingsDialog(context, ref),
                  icon: const Icon(Icons.tune_rounded,
                      size: 14, color: AppColors.textSecondary),
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
