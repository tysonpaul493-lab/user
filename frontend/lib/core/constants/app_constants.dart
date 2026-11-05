import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

String get _detectedUserHost {
  if (kIsWeb) return 'localhost';
  try {
    // 127.0.0.1 works with adb reverse for both physical devices and emulators
    if (Platform.isAndroid) return '127.0.0.1';
    return 'localhost';
  } catch (_) {
    return 'localhost';
  }
}

class AppConstants {
  static const String appName = 'LifeRoute Emergency';
  static const String appVersion = '1.0.0';

  // Emergency Hotlines (Prompt requirement: 108 India)
  static const String emergency108India = '108'; // Free Emergency Ambulance Service (India)
  static const String nationalEmergencyNumber = '112'; // Universal Emergency Hotline
  static const String alternateHotline = '999';

  // Laravel Backend Defaults
  static const String defaultBaseUrl = 'https://api.liferoute-emergency.com/api';
  static String get defaultLocalBaseUrl => 'http://$_detectedUserHost:8000/api';
  static String get reverbHost => _detectedUserHost;
  static const int reverbPort = 8080;
  static const String reverbAppKey = 'liferoute_reverb_key';

  // Storage Keys
  static const String tokenKey = 'lr_auth_token';
  static const String userKey = 'lr_user_data';
  static const String localeKey = 'lr_locale_pref';
  static const String emergencyContactsKey = 'lr_emergency_contacts';
  static const String demoModeKey = 'lr_demo_mode_active';
  static const String smsApiKeyStorageKey = 'lr_sms_api_key';
  static const String bookingHistoryKey = 'lr_booking_history';

  // Real Free SMS OTP Gateway Configuration (India)
  // Fast2SMS: Get instant 100% free API key at https://www.fast2sms.com (free trial credits upon registration)
  // 2Factor: Get 100 free OTP SMS at https://2factor.in
  static const String fast2SmsApiKey = ''; // Paste your Fast2SMS API key here
  static const String twoFactorApiKey = ''; // Or paste your 2Factor API key here

  // Tracking Thresholds
  static const int staleLocationSeconds = 15;
  static const int otpTimeoutSeconds = 60;
  static const int maxOtpResendAttempts = 3;

  // Default Coordinates (Live GPS anchor)
  static const double defaultLat = 11.0318; // Kovilmedu, Coimbatore
  static const double defaultLng = 76.9437;
  static const String defaultLocationName = 'Locating Current GPS Position...';
}
