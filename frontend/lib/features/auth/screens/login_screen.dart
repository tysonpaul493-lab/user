import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/server_settings_dialog.dart';
import '../providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isRegisterMode = false;

  // Controllers
  final _loginPhoneController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerNotesController = TextEditingController();

  String _selectedBloodGroup = 'O+';
  String? _errorMessage;
  String? _successMessage;
  bool _isFraudDetected = false;

  final List<String> _bloodGroups = ['O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-'];

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _registerNameController.dispose();
    _registerPhoneController.dispose();
    _registerNotesController.dispose();
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
          _errorMessage = 'Invalid mobile number. Please enter a valid 10-digit Indian SIM number.';
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
    final rawInput = _loginPhoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
        _successMessage = null;
      });
      return;
    }

    final simNumberPattern = RegExp(r'^[6-9]\d{9}$');
    if (!simNumberPattern.hasMatch(digits)) {
      setState(() {
        _errorMessage = 'Invalid mobile number. Indian mobile numbers must start with 6, 7, 8, or 9.';
        _successMessage = null;
      });
      return;
    }

    if (_isFraudDetected) {
      setState(() {
        _errorMessage = 'Fraud Alert: Suspicious or dummy number cannot be used.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await ref.read(authProvider.notifier).loginWithPhone(digits);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      final authError = ref.read(authProvider).errorMessage;
      setState(() {
        _errorMessage = authError ?? 'Wrong mobile number: This number is not registered. Please register first.';
      });
    }
  }

  void _handleRegister() async {
    final name = _registerNameController.text.trim();
    final rawInput = _registerPhoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Full Name';
        _successMessage = null;
      });
      return;
    }

    if (digits.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
        _successMessage = null;
      });
      return;
    }

    final simNumberPattern = RegExp(r'^[6-9]\d{9}$');
    if (!simNumberPattern.hasMatch(digits)) {
      setState(() {
        _errorMessage = 'Invalid mobile number. Indian mobile numbers must start with 6, 7, 8, or 9.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await ref.read(authProvider.notifier).registerNewUser(
          name: name,
          phone: digits,
          bloodGroup: _selectedBloodGroup,
          emergencyNotes: _registerNotesController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _successMessage = 'Registration successful! You can now log in with $digits.';
        _loginPhoneController.text = digits;
        _isRegisterMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registered $name successfully. Please log in.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      final authError = ref.read(authProvider).errorMessage;
      setState(() {
        _errorMessage = authError ?? 'Registration failed. Please check your network and try again.';
      });
    }
  }

  void _handleEmergencyQuickAccess() async {
    final rawInput = _loginPhoneController.text.trim();
    final digits = rawInput.replaceAll(RegExp(r'\D'), '');
    final effectivePhone = digits.length == 10 ? '+91 $digits' : '+91 8428304510';

    final success = await ref.read(authProvider.notifier).signInAsEmergencyGuest(
          genuineSimPhone: effectivePhone,
          callerName: 'Emergency Caller',
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
                isTamil ? 'ஆல் இந்தியா தமிழ் அனைத்து அறக்கட்டளை' : 'All India Tamil All Trust',
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
              const SizedBox(height: 24),

              // Dual Tab Switcher: [ Login ] | [ Register ]
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isRegisterMode = false;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isRegisterMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !_isRegisterMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 18,
                                  color: !_isRegisterMode ? AppColors.primaryRed : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTamil ? 'உள்நுழைவு' : 'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: !_isRegisterMode ? AppColors.primaryRed : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isRegisterMode = true;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isRegisterMode ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isRegisterMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 18,
                                  color: _isRegisterMode ? AppColors.primaryRed : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTamil ? 'பதிவு செய்க' : 'Register',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _isRegisterMode ? AppColors.primaryRed : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Success Message Banner
              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
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

              // Error Message Banner (Wrong Number / Validation)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            if (!_isRegisterMode &&
                                (_errorMessage!.contains('not registered') || _errorMessage!.contains('பதிவு'))) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _registerPhoneController.text = _loginPhoneController.text;
                                    _isRegisterMode = true;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  isTamil ? '👉 புதிய கணக்கை பதிவு செய்ய இங்கே தொடவும்' : '👉 Tap here to Register this number now',
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Card Container
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.softCardShadow,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: !_isRegisterMode ? _buildLoginForm(isTamil, authState) : _buildRegisterForm(isTamil, authState),
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
                  icon: const Icon(Icons.emergency_rounded, color: AppColors.primaryRed, size: 20),
                  label: Text(
                    isTamil ? '1-தட்டு உடனடி அவசர உதவி (உள்நுழைவு தேவையில்லை)' : 'Instant 1-Tap Emergency SOS (Skip Login)',
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
      ),
    );
  }

  // LOGIN FORM
  Widget _buildLoginForm(bool isTamil, AuthState authState) {
    return Column(
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
              ? 'பதிவு செய்த 10-இலக்க மொபைல் எண்ணை உள்ளிடவும்.'
              : 'Enter your registered 10-digit SIM mobile number to sign in.',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),

        // Phone Input Field
        Text(
          isTamil ? 'மொபைல் எண் (SIM அட்டை) *' : 'Registered Mobile Number *',
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android_rounded, color: AppColors.primaryRed, size: 20),
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
                  Text('|', style: TextStyle(color: AppColors.border, fontSize: 18)),
                ],
              ),
            ),
            hintText: 'Enter 10-digit mobile number',
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
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Sign In Button
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: authState.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isTamil ? 'உள்நுழைக' : 'Verify & Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Switch to Register
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isTamil ? 'புதிய பயனரா?' : 'New user? ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _registerPhoneController.text = _loginPhoneController.text;
                  _isRegisterMode = true;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
              child: Text(
                isTamil ? 'புதிய கணக்கை பதிவு செய்க' : 'Register Profile',
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // REGISTER FORM
  Widget _buildRegisterForm(bool isTamil, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isTamil ? 'புதிய பயனர் பதிவு' : 'New User Registration',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isTamil
              ? 'உங்கள் பெயர் மற்றும் மொபைல் எண்ணை பதிவு செய்க.'
              : 'Register your mobile number so dispatchers can identify your profile.',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // Name Field
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
          controller: _registerNameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryRed, size: 20),
            hintText: 'Enter your full name',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
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
        const SizedBox(height: 14),

        // Mobile Number Field
        Text(
          isTamil ? 'மொபைல் எண் (SIM அட்டை) *' : 'Mobile Number (SIM Card) *',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _registerPhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: _onPhoneChanged,
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
                  Text('|', style: TextStyle(color: AppColors.border, fontSize: 18)),
                ],
              ),
            ),
            hintText: 'Enter 10-digit SIM number',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15, letterSpacing: 0),
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
        const SizedBox(height: 14),

        // Blood Group Dropdown
        Text(
          isTamil ? 'இரத்த வகை (விருப்பத்தேர்வு)' : 'Blood Group (Optional)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBloodGroup,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryRed),
              items: _bloodGroups.map((bg) {
                return DropdownMenuItem(
                  value: bg,
                  child: Row(
                    children: [
                      const Icon(Icons.bloodtype_rounded, color: AppColors.primaryRed, size: 18),
                      const SizedBox(width: 10),
                      Text(bg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBloodGroup = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Register Button
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
            onPressed: authState.isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: authState.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isTamil ? 'பதிவு செய்து உள்நுழைக' : 'Complete Registration',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Switch to Login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isTamil ? 'ஏற்கனவே பதிவு செய்துள்ளீர்களா? ' : 'Already registered? ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _loginPhoneController.text = _registerPhoneController.text;
                  _isRegisterMode = false;
                  _errorMessage = null;
                  _successMessage = null;
                });
              },
              child: Text(
                isTamil ? 'உள்நுழையவும்' : 'Sign In',
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
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
