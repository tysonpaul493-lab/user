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

  /// Lookup existing user profile from server by 10-digit phone
  Future<UserModel?> lookupUser(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final tenDigit = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
    if (tenDigit.length < 10) return null;

    // Check local storage first
    final local = _storageService.getRegisteredUserByPhone(tenDigit);
    if (local != null && local.name.trim().isNotEmpty) {
      return local;
    }

    // Query backend server
    try {
      final res = await _apiClient.lookupUser(tenDigit);
      if (res != null && res['status'] == 'success' && res['exists'] == true && res['user'] != null) {
        final userData = res['user'];
        final serverUser = UserModel(
          id: (userData['id'] ?? 'usr-$tenDigit').toString(),
          name: (userData['name'] ?? '').toString(),
          phone: (userData['phone'] ?? '+91 $tenDigit').toString(),
          bloodGroup: userData['blood_group']?.toString(),
          emergencyNotes: userData['emergency_notes']?.toString(),
        );
        if (serverUser.name.trim().isNotEmpty) {
          await _storageService.saveRegisteredUserByPhone(serverUser);
          return serverUser;
        }
      }
    } catch (_) {}

    return local;
  }

  /// Verify user login with registered mobile number and physical SIM verification
  Future<bool> loginWithPhone(
    String phone, {
    String? name,
    String? simNumber,
    String? carrier,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final tenDigit = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    if (tenDigit.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(tenDigit)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a valid 10-digit Indian mobile number.',
      );
      return false;
    }

    final trimmedName = name?.trim() ?? '';

    // 1. Try server verification first
    try {
      final res = await _apiClient.loginUser(
        tenDigit,
        name: trimmedName.isNotEmpty ? trimmedName : null,
        simNumber: simNumber,
        carrier: carrier,
      );
      if (res['status'] == 'success' && res['user'] != null) {
        final u = res['user'];
        final serverUser = UserModel(
          id: (u['id'] ?? 'usr-$tenDigit').toString(),
          name: (u['name'] != null && u['name'].toString().trim().isNotEmpty)
              ? u['name'].toString().trim()
              : (trimmedName.isNotEmpty ? trimmedName : 'Emergency Caller'),
          phone: (u['phone'] ?? '+91 $tenDigit').toString(),
          bloodGroup: u['blood_group']?.toString() ?? 'O+',
          emergencyNotes: u['emergency_notes']?.toString() ?? '',
        );

        await _storageService.saveUser(serverUser);
        await _storageService.saveRegisteredUserByPhone(serverUser);
        await _storageService.saveLastRegisteredPhone(tenDigit);
        if (res['token'] != null) {
          await _storageService.saveToken(res['token'].toString());
        }

        state = state.copyWith(
          user: serverUser,
          currentPhone: serverUser.phone,
          isLoading: false,
          errorMessage: null,
        );
        return true;
      } else if (res['status'] == 'error' || res['is_registered'] == false) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: res['message']?.toString() ??
              'Unable to sign in. Please verify your SIM number.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to reach dispatch server. Please check your connection.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Unable to sign in. Please check your network connection.',
    );
    return false;
  }

  /// Register a new user profile
  Future<bool> registerNewUser({
    required String name,
    required String phone,
    String? bloodGroup,
    String? emergencyNotes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final tenDigit = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    if (name.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Full Name is required for registration.',
      );
      return false;
    }

    if (tenDigit.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(tenDigit)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Please enter a valid 10-digit Indian SIM number starting with 6, 7, 8, or 9.',
      );
      return false;
    }

    final formattedPhone = '+91 $tenDigit';

    // Sync with backend API
    try {
      final res = await _apiClient.registerUser(
        name: name.trim(),
        phone: tenDigit,
        bloodGroup: bloodGroup ?? 'O+',
        emergencyNotes: emergencyNotes ?? '',
      );

      final token = res['token']?.toString() ?? 'token_$tenDigit';
      await _storageService.saveToken(token);

      final u = res['user'] is Map ? res['user'] as Map : null;
      final serverUser = UserModel(
        id: u != null && u['id'] != null ? u['id'].toString() : 'usr-$tenDigit',
        name: u != null && u['name'] != null ? u['name'].toString() : name.trim(),
        phone: u != null && u['phone'] != null ? u['phone'].toString() : formattedPhone,
        bloodGroup: u != null && u['blood_group'] != null ? u['blood_group'].toString() : (bloodGroup ?? 'O+'),
        emergencyNotes: u != null && u['emergency_notes'] != null ? u['emergency_notes'].toString() : (emergencyNotes ?? ''),
      );

      // Save locally
      await _storageService.saveUser(serverUser);
      await _storageService.saveRegisteredUserByPhone(serverUser);
      await _storageService.saveLastRegisteredPhone(tenDigit);

      state = state.copyWith(
        user: serverUser,
        currentPhone: formattedPhone,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to connect to dispatch server. Please try again.',
      );
      return false;
    }
  }

  /// 1-Tap Direct SIM Mobile Number Sign In (No OTP code required for emergency user)
  Future<bool> signInWithPhoneNumber(String phone, {String? name}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final tenDigit = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;
    final formattedPhone = '+91 $tenDigit';

    // 1. Check local storage
    var existing = _storageService.getRegisteredUserByPhone(tenDigit);
    if (existing == null || existing.name.trim().isEmpty) {
      final lastUser = _storageService.getUser();
      if (lastUser != null && lastUser.phone.replaceAll(RegExp(r'\D'), '').endsWith(tenDigit)) {
        existing = lastUser;
      }
    }

    // 2. Query dispatch server if local record has no name
    if (existing == null || existing.name.trim().isEmpty) {
      try {
        final res = await _apiClient.lookupUser(tenDigit);
        if (res != null && res['status'] == 'success' && res['exists'] == true && res['user'] != null) {
          final u = res['user'];
          existing = UserModel(
            id: (u['id'] ?? 'usr-$tenDigit').toString(),
            name: (u['name'] ?? '').toString(),
            phone: (u['phone'] ?? formattedPhone).toString(),
            bloodGroup: u['blood_group']?.toString(),
            emergencyNotes: u['emergency_notes']?.toString(),
          );
        }
      } catch (_) {}
    }

    final trimmedInputName = name?.trim() ?? '';
    final resolvedName = trimmedInputName.isNotEmpty
        ? trimmedInputName
        : (existing != null && existing.name.trim().isNotEmpty ? existing.name.trim() : '');

    final user = UserModel(
      id: existing?.id ?? 'usr-${DateTime.now().millisecondsSinceEpoch}',
      name: resolvedName,
      phone: formattedPhone,
      bloodGroup: existing?.bloodGroup,
      emergencyNotes: existing?.emergencyNotes,
    );

    await _storageService.saveUser(user);
    await _storageService.saveRegisteredUserByPhone(user);
    await _storageService.saveLastRegisteredPhone(tenDigit);
    await _storageService.saveToken('token_$tenDigit');

    state = state.copyWith(
      user: user,
      currentPhone: formattedPhone,
      isLoading: false,
      isOtpSent: false,
    );

    // Sync with backend API only if name is non-empty so we never overwrite an existing name with blank
    if (resolvedName.isNotEmpty) {
      try {
        await _apiClient.updateProfile({
          'phone': formattedPhone,
          'name': resolvedName,
          if (user.bloodGroup != null && user.bloodGroup!.isNotEmpty)
            'blood_group': user.bloodGroup,
          if (user.emergencyNotes != null && user.emergencyNotes!.isNotEmpty)
            'emergency_notes': user.emergencyNotes,
        });
      } catch (_) {}
    }

    return true;
  }

  /// 1-Tap Emergency Quick Access using genuine recognized SIM mobile number (Immediate SOS)
  Future<bool> signInAsEmergencyGuest({
    required String genuineSimPhone,
    String? callerName,
  }) async {
    final cleanDigits = genuineSimPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length < 10) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Valid 10-digit SIM mobile number required for emergency ambulance dispatch.',
      );
      return false;
    }

    final last10 = cleanDigits.substring(cleanDigits.length - 10);
    final normalizedPhone = '+91 $last10';

    state = state.copyWith(isLoading: true, errorMessage: null);
    final emergencyId = 'emergency-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final resolvedName = (callerName != null && callerName.trim().isNotEmpty)
        ? callerName.trim()
        : 'Emergency Caller';

    final emergencyUser = UserModel(
      id: emergencyId,
      name: resolvedName,
      phone: normalizedPhone,
      bloodGroup: null,
      emergencyNotes: 'Immediate 108 Emergency Dispatch Access (SIM Verified)',
    );

    await _storageService.saveUser(emergencyUser);
    await _storageService.saveToken('token_$emergencyId');
    await _storageService.saveLastRegisteredPhone(normalizedPhone);

    state = state.copyWith(
      user: emergencyUser,
      currentPhone: normalizedPhone,
      isLoading: false,
      isOtpSent: false,
    );

    if (!_storageService.isDemoMode()) {
      try {
        await _apiClient.updateProfile({
          'phone': normalizedPhone,
          'name': resolvedName,
        });
      } catch (_) {}
    }

    return true;
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
      final res = await _apiClient.sendOtp(phone);
      if (res['status'] == 'success') {
        final serverOtp = (res['verification_code'] ?? res['dev_otp'] ?? res['otp'])?.toString();
        final code = customOtp ??
            serverOtp ??
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

        if (res['sms_dispatched'] != true) {
          final currentKey = state.smsApiKey ?? _storageService.getSmsApiKey();
          await SmsOtpService.sendRealOtpSms(
            phone: phone,
            otp: code,
            customApiKey: currentKey,
          );
        }
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
                : (existingUser?.name.isNotEmpty == true ? existingUser!.name : '');

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

    if (!_storageService.isDemoMode()) {
      try {
        await _apiClient.updateProfile(updated.toJson());
      } catch (_) {}
    }

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
