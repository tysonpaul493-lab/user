import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../models/emergency_contact_model.dart';
import '../../models/booking_model.dart';

class StorageService {
  final FlutterSecureStorage secureStorage;
  final SharedPreferences prefs;

  StorageService({
    required this.secureStorage,
    required this.prefs,
  });

  static Future<StorageService> init() async {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    return StorageService(secureStorage: secureStorage, prefs: prefs);
  }

  // Token Management (Sanctum)
  Future<void> saveToken(String token) async {
    await secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await secureStorage.read(key: AppConstants.tokenKey);
  }

  Future<void> clearToken() async {
    await secureStorage.delete(key: AppConstants.tokenKey);
  }

  // User Profile
  Future<void> saveUser(UserModel user) async {
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    if (user.phone.isNotEmpty) {
      await saveRegisteredUserByPhone(user);
      await saveLastRegisteredPhone(user.phone);
    }
  }

  UserModel? getUser() {
    final str = prefs.getString(AppConstants.userKey);
    if (str != null) {
      try {
        return UserModel.fromJson(jsonDecode(str));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    await prefs.remove(AppConstants.userKey);
  }

  // Persistent Phone-to-Registered-User Registry (Preserved across logouts)
  Future<void> saveRegisteredUserByPhone(UserModel user) async {
    final clean = user.phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isNotEmpty) {
      final key = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
      await prefs.setString('lr_registered_user_$key', jsonEncode(user.toJson()));
      await prefs.setString('lr_last_registered_phone', user.phone);
    }
  }

  UserModel? getRegisteredUserByPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isNotEmpty) {
      final key = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
      final raw = prefs.getString('lr_registered_user_$key');
      if (raw != null) {
        try {
          return UserModel.fromJson(jsonDecode(raw));
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> saveLastRegisteredPhone(String phone) async {
    await prefs.setString('lr_last_registered_phone', phone);
  }

  String? getLastRegisteredPhone() {
    return prefs.getString('lr_last_registered_phone');
  }

  // Language Preference
  Future<void> saveLocale(String langCode) async {
    await prefs.setString(AppConstants.localeKey, langCode);
  }

  String getLocale() {
    return prefs.getString(AppConstants.localeKey) ?? 'en';
  }

  // Demo Mode (disabled by default so live server dispatch is always enforced)
  bool isDemoMode() {
    return prefs.getBool(AppConstants.demoModeKey) ?? false;
  }

  Future<void> setDemoMode(bool enabled) async {
    await prefs.setBool(AppConstants.demoModeKey, enabled);
  }

  // Emergency Contacts
  Future<void> saveEmergencyContacts(List<EmergencyContactModel> contacts) async {
    final list = contacts.map((c) => c.toJson()).toList();
    await prefs.setString(AppConstants.emergencyContactsKey, jsonEncode(list));
  }

  List<EmergencyContactModel> getEmergencyContacts() {
    final str = prefs.getString(AppConstants.emergencyContactsKey);
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as List<dynamic>;
        return decoded.map((e) => EmergencyContactModel.fromJson(e)).toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  // Booking History Persistence
  Future<void> saveBookingHistory(List<BookingModel> bookings) async {
    final seen = <String>{};
    final deduped = <BookingModel>[];
    for (final b in bookings) {
      final key = b.id.isNotEmpty ? b.id : b.referenceNumber;
      if (seen.add(key)) {
        deduped.add(b);
      }
    }
    final list = deduped.map((b) => b.toJson()).toList();
    await prefs.setString(AppConstants.bookingHistoryKey, jsonEncode(list));
  }

  List<BookingModel> getBookingHistory() {
    final str = prefs.getString(AppConstants.bookingHistoryKey);
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as List<dynamic>;
        final seen = <String>{};
        final result = <BookingModel>[];
        for (final e in decoded) {
          final b = BookingModel.fromJson(e);
          final key = b.id.isNotEmpty ? b.id : b.referenceNumber;
          if (seen.add(key)) {
            result.add(b);
          }
        }
        return result;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  // Real Free SMS API Key Persistence
  Future<void> saveSmsApiKey(String key) async {
    await prefs.setString(AppConstants.smsApiKeyStorageKey, key);
  }

  String? getSmsApiKey() {
    return prefs.getString(AppConstants.smsApiKeyStorageKey);
  }

  // Dispatch Server Host Persistence (for LAN Wi-Fi / USB multi-device testing)
  Future<void> setServerHost(String? host) async {
    if (host == null || host.trim().isEmpty) {
      await prefs.remove(AppConstants.serverHostKey);
    } else {
      await prefs.setString(AppConstants.serverHostKey, host.trim());
    }
  }

  String? getServerHost() {
    return prefs.getString(AppConstants.serverHostKey);
  }
}