import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sms_otp_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/emergency_contact_model.dart';
import '../../../models/user_model.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main.dart');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiClient(storage);
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isOtpSent;
  final int resendCountdown;
  final int resendAttempts;
  final String? currentPhone;
  final String? lastGeneratedOtp;
  final List<EmergencyContactModel> emergencyContacts;
  final String selectedLocale;
  final String? smsApiKey;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isOtpSent = false,
    this.resendCountdown = 0,
    this.resendAttempts = 0,
    this.currentPhone,
    this.lastGeneratedOtp,
    this.emergencyContacts = const [],
    this.selectedLocale = 'en',
    this.smsApiKey,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isOtpSent,
    int? resendCountdown,
    int? resendAttempts,
    String? currentPhone,
    String? lastGeneratedOtp,
    List<EmergencyContactModel>? emergencyContacts,
    String? selectedLocale,
    String? smsApiKey,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      resendCountdown: resendCountdown ?? this.resendCountdown,
      resendAttempts: resendAttempts ?? this.resendAttempts,
      currentPhone: currentPhone ?? this.currentPhone,
      lastGeneratedOtp: lastGeneratedOtp ?? this.lastGeneratedOtp,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      selectedLocale: selectedLocale ?? this.selectedLocale,
      smsApiKey: smsApiKey ?? this.smsApiKey,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final StorageService _storageService;
  Timer? _countdownTimer;

  AuthNotifier(this._apiClient, this._storageService)
      : super(AuthState(
          selectedLocale: _storageService.getLocale(),
          emergencyContacts: _storageService.getEmergencyContacts(),
          smsApiKey: _storageService.getSmsApiKey() ?? AppConstants.fast2SmsApiKey,
        )) {
    _loadInitialUser();
  }

  void _loadInitialUser() {
    final savedUser = _storageService.getUser();
    if (savedUser != null) {
      state = state.copyWith(user: savedUser);
    }
  }

  /// 1-Tap Sign In for already registered user without repeating registration
  Future<bool> signInWithRegisteredUser(UserModel registeredUser) async {
    await _storageService.saveUser(registeredUser);
    state = state.copyWith(user: registeredUser, isOtpSent: false);
    return true;
  }

  /// Send Phone OTP (Both Real SMS Gateway & Local Verification)
  Future<bool> sendOtp(String phone, {String? customOtp}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final code = customOtp ?? (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

      // Dispatch real SMS OTP to Indian mobile number via Fast2SMS / 2Factor gateway
      final currentKey = state.smsApiKey ?? _storageService.getSmsApiKey();
      await SmsOtpService.sendRealOtpSms(
        phone: phone,
        otp: code,
        customApiKey: currentKey,
      );

      final res = await _apiClient.sendOtp(phone);
      if (res['status'] == 'success') {
        state = state.copyWith(
          isLoading: false,
          isOtpSent: true,
          currentPhone: phone,
          lastGeneratedOtp: code,
          resendCountdown: AppConstants.otpTimeoutSeconds,
          resendAttempts: state.resendAttempts + 1,
        );
        _startCountdown();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res['message'] ?? 'Failed to send OTP',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> updateSmsApiKey(String key) async {
    await _storageService.saveSmsApiKey(key);
    state = state.copyWith(smsApiKey: key);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCountdown > 0) {
        state = state.copyWith(resendCountdown: state.resendCountdown - 1);
      } else {
        timer.cancel();
      }
    });
  }

  /// Verify OTP and store session while preserving existing registered user details
  Future<bool> verifyOtp(String otp) async {
    if (state.currentPhone == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _apiClient.verifyOtp(state.currentPhone!, otp);
      if (res['status'] == 'success') {
        final rawUser = Map<String, dynamic>.from(res['user'] ?? {});
        final registeredUser = _storageService.getRegisteredUserByPhone(state.currentPhone!);
        final existingUser = _storageService.getUser();

        final name = (registeredUser != null && registeredUser.name.isNotEmpty)
            ? registeredUser.name
            : (rawUser['name']?.toString().isNotEmpty == true)
                ? rawUser['name'].toString()
                : (existingUser?.name.isNotEmpty == true ? existingUser!.name : 'Emergency User');

        final bloodGroup = (registeredUser?.bloodGroup != null && registeredUser!.bloodGroup!.isNotEmpty)
            ? registeredUser.bloodGroup
            : (existingUser?.bloodGroup != null && existingUser!.bloodGroup!.isNotEmpty)
                ? existingUser.bloodGroup
                : rawUser['blood_group']?.toString();

        final emergencyNotes = (registeredUser?.emergencyNotes != null && registeredUser!.emergencyNotes!.isNotEmpty)
            ? registeredUser.emergencyNotes
            : (existingUser?.emergencyNotes != null && existingUser!.emergencyNotes!.isNotEmpty)
                ? existingUser.emergencyNotes
                : rawUser['emergency_notes']?.toString();

        final userData = UserModel(
          id: registeredUser?.id.isNotEmpty == true
              ? registeredUser!.id
              : (existingUser?.id.isNotEmpty == true ? existingUser!.id : 'usr-${DateTime.now().millisecondsSinceEpoch}'),
          name: name,
          phone: state.currentPhone!,
          bloodGroup: bloodGroup,
          emergencyNotes: emergencyNotes,
          isGuest: false,
        );

        await _storageService.saveUser(userData);
        await _storageService.saveRegisteredUserByPhone(userData);

        state = state.copyWith(
          isLoading: false,
          user: userData,
          isOtpSent: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res['message'] ?? 'Invalid code',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Proceed as Guest for Immediate Emergency (Prompt requirement)
  void continueAsGuest() {
    final existingUser = _storageService.getUser();
    final guestUser = UserModel(
      id: existingUser?.id.isNotEmpty == true ? existingUser!.id : 'guest-${DateTime.now().millisecondsSinceEpoch}',
      name: (existingUser?.name.isNotEmpty == true) ? existingUser!.name : 'Emergency Guest',
      phone: (existingUser?.phone.isNotEmpty == true) ? existingUser!.phone : (state.currentPhone ?? ''),
      bloodGroup: existingUser?.bloodGroup,
      emergencyNotes: existingUser?.emergencyNotes,
      isGuest: true,
    );
    _storageService.saveUser(guestUser);
    state = state.copyWith(user: guestUser);
  }

  /// Update User Profile permanently
  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? bloodGroup,
    String? emergencyNotes,
  }) async {
    final current = state.user;
    final updated = UserModel(
      id: (current?.id.isNotEmpty == true) ? current!.id : 'usr-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      email: email,
      bloodGroup: bloodGroup,
      emergencyNotes: emergencyNotes,
      isGuest: false,
    );

    // Save permanently to local SharedPreferences and registered phone registry
    await _storageService.saveUser(updated);
    await _storageService.saveRegisteredUserByPhone(updated);

    try {
      await _apiClient.updateProfile(updated.toJson());
    } catch (_) {}

    state = state.copyWith(user: updated);
  }

  /// Change Language (English <-> Tamil <-> Hindi)
  Future<void> setLocale(String langCode) async {
    await _storageService.saveLocale(langCode);
    state = state.copyWith(selectedLocale: langCode);
  }

  /// Add / Remove Emergency Contact
  Future<void> addEmergencyContact(EmergencyContactModel contact) async {
    final updated = [...state.emergencyContacts, contact];
    await _storageService.saveEmergencyContacts(updated);
    state = state.copyWith(emergencyContacts: updated);
  }

  Future<void> removeEmergencyContact(String id) async {
    final updated = state.emergencyContacts.where((c) => c.id != id).toList();
    await _storageService.saveEmergencyContacts(updated);
    state = state.copyWith(emergencyContacts: updated);
  }

  /// Logout
  Future<void> logout() async {
    await _storageService.clearToken();
    await _storageService.clearUser();
    state = AuthState(
      selectedLocale: state.selectedLocale,
      emergencyContacts: state.emergencyContacts,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthNotifier(apiClient, storage);
});
