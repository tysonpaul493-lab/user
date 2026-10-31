import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  UserModel? _matchedRegisteredUser;
  bool _showTopSmsNotification = false;
  bool _showAutoFillChip = false;
  Timer? _topSmsDismissTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _otpFocusNode.addListener(() {
      if (_otpFocusNode.hasFocus && _otpController.text.isEmpty) {
        setState(() => _showAutoFillChip = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      final lastPhone = storage.getLastRegisteredPhone();
      if (lastPhone != null && lastPhone.isNotEmpty) {
        final clean = lastPhone.replaceAll(RegExp(r'\D'), '');
        final tenDigits = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
        _phoneController.text = tenDigits;
      }
    });
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      final user = ref.read(storageServiceProvider).getRegisteredUserByPhone(clean);
      if (user != _matchedRegisteredUser) {
        setState(() => _matchedRegisteredUser = user);
      }
    } else if (_matchedRegisteredUser != null) {
      setState(() => _matchedRegisteredUser = null);
    }
  }

  void _triggerTopSmsNotification() {
    setState(() {
      _showTopSmsNotification = true;
      _showAutoFillChip = false;
    });
    _topSmsDismissTimer?.cancel();
    _topSmsDismissTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _showTopSmsNotification = false);
      }
    });
  }

  @override
  void dispose() {
    _topSmsDismissTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final strings = AppStrings(Locale(authState.selectedLocale));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Switcher (EN / TA)
              Align(
                alignment: Alignment.topRight,
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
              const SizedBox(height: 24),

              // Emergency Brand Badge
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.redGlowShadow,
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    color: Colors.white,
                    size: 42,
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
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
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
                    Text(
                      authState.isOtpSent
                          ? strings.get('verifyOtp')
                          : strings.get('phoneLogin'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!authState.isOtpSent) ...[
                      // Phone Input
                      Text(
                        strings.get('enterPhone'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_rounded, color: AppColors.primaryRed, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '+91',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          hintText: 'Enter 10-digit mobile number',
                        ),
                      ),

                      // If mobile number matches a registered user: Show instant 1-tap sign in banner
                      if (_matchedRegisteredUser != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Registered User: ${_matchedRegisteredUser!.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_matchedRegisteredUser!.bloodGroup != null && _matchedRegisteredUser!.bloodGroup!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Blood: ${_matchedRegisteredUser!.bloodGroup}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await ref.read(authProvider.notifier).signInWithRegisteredUser(_matchedRegisteredUser!);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('👋 Welcome back, ${_matchedRegisteredUser!.name}!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                                label: Text(
                                  'Sign In as ${_matchedRegisteredUser!.name}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Send OTP Button
                      Container(
                        height: 52,
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
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final phone = _phoneController.text.trim();
                                  if (phone.isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 10) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a valid 10-digit mobile number'),
                                        backgroundColor: AppColors.primaryRed,
                                      ),
                                    );
                                    return;
                                  }

                                  final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
                                  final success = await ref
                                      .read(authProvider.notifier)
                                      .sendOtp(phone, customOtp: code);

                                  if (success && context.mounted) {
                                    _triggerTopSmsNotification();
                                  }
                                },
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
                              : Text(
                                  strings.get('sendOtp'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Enter 6-digit OTP code sent to your mobile',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        onTap: () {
                          if (_otpController.text.isEmpty) {
                            setState(() => _showAutoFillChip = true);
                          }
                        },
                        onChanged: (val) {
                          if (val.isNotEmpty && _showAutoFillChip) {
                            setState(() => _showAutoFillChip = false);
                          }
                        },
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                        ),
                      ),
                      if (_showAutoFillChip && authState.lastGeneratedOtp != null && _otpController.text.isEmpty) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0xFFEFF6FF),
                            child: InkWell(
                              onTap: () {
                                _otpController.text = authState.lastGeneratedOtp!;
                                setState(() => _showAutoFillChip = false);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '⚡ Auto-fill code from SMS: ${authState.lastGeneratedOtp}',
                                      style: const TextStyle(
                                        color: Color(0xFF1E40AF),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Verify Button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: authState.isLoading
                              ? null
                              : () async {
                                  final code = _otpController.text.trim();
                                  if (code.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter the 6-digit verification code'),
                                        backgroundColor: AppColors.primaryRed,
                                      ),
                                    );
                                    return;
                                  }

                                  final success = await ref
                                      .read(authProvider.notifier)
                                      .verifyOtp(code);
                                  if (success && context.mounted) {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: authState.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  strings.get('verifyOtp'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Resend Countdown
                      Center(
                        child: authState.resendCountdown > 0
                            ? Text(
                                '${strings.get('resendOtp')} ${authState.resendCountdown}${strings.get('seconds')}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              )
                            : TextButton(
                                onPressed: () async {
                                  final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
                                  final res = await ref
                                      .read(authProvider.notifier)
                                      .sendOtp(_phoneController.text.trim(), customOtp: code);
                                  if (res && mounted) {
                                    _triggerTopSmsNotification();
                                  }
                                },
                                child: const Text(
                                  'Resend OTP Code',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ],

                    if (authState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        authState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Emergency Guest Bypass Button (Immediate Emergency)
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).continueAsGuest();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
                icon: const Icon(Icons.flash_on_rounded, color: AppColors.primaryRed),
                label: Text(
                  strings.get('skipForEmergency'),
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // 10-Second Heads-up SMS Notification banner at the top of the screen
      if (_showTopSmsNotification && authState.lastGeneratedOtp != null)
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: SafeArea(
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF0F172A),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Messages',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '• now',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'LifeRoute Emergency: Your OTP verification code is ${authState.lastGeneratedOtp}. Valid for 10 min.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                      onPressed: () {
                        _topSmsDismissTimer?.cancel();
                        setState(() => _showTopSmsNotification = false);
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _langChip(String code, String label, String currentCode) {
    final isSelected = currentCode == code;
    return GestureDetector(
      onTap: () => ref.read(authProvider.notifier).setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

}