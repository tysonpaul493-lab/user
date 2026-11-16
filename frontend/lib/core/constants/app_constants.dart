import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const String _kDefaultLiveWebBackend = 'https://assembled-rfc-tables-generators.trycloudflare.com/api';

String get _detectedUserHost {
  if (kIsWeb) {
    if (AppConstants.configuredApiUrl.isNotEmpty) {
      return AppConstants.configuredApiUrl;
    }
    return _kDefaultLiveWebBackend;
  }
  try {
    // Primary default for standalone Android APK on LAN Wi-Fi
    if (Platform.isAndroid) return AppConstants.fallbackLanHost;
    return 'localhost';
  } catch (_) {
    return 'localhost';
  }
}

class AppConstants {
  /// Default PC LAN IP used automatically on mobile devices when USB adb reverse is unavailable.
  /// Override at build time via `--dart-define=DEFAULT_LAN_HOST=...` or `--dart-define=DEFAULT_API_URL=...`.
  static const String fallbackLanHost = String.fromEnvironment(
    'DEFAULT_LAN_HOST',
    defaultValue: '192.168.0.112',
  );
  static const String configuredApiUrl = String.fromEnvironment(
    'DEFAULT_API_URL',
    defaultValue: '',
  );

  static String? _customServerHost;
  static String? _customFullBaseUrl;
  static String? _runtimeFallbackHost;

  /// Effective server IP/hostname for both REST API and live WebSocket dispatch
  static String get effectiveHost {
    if (kIsWeb) {
      if (_customServerHost != null &&
          _customServerHost!.isNotEmpty &&
          !_customServerHost!.contains('localhost') &&
          !_customServerHost!.contains('127.0.0.1')) {
        return _customServerHost!;
      }
      return _kDefaultLiveWebBackend;
    }
    return _customServerHost ?? _runtimeFallbackHost ?? _detectedUserHost;
  }

  static bool get hasCustomServerHost =>
      _customServerHost != null &&
      (!kIsWeb || (!_customServerHost!.contains('localhost') && !_customServerHost!.contains('127.0.0.1')));

  /// Ordered unique list of candidate backend hosts for automatic connection resolution.
  static List<String> get candidateHosts {
    if (kIsWeb) {
      return [
        if (hasCustomServerHost) _customServerHost! else _kDefaultLiveWebBackend,
      ];
    }

    final hosts = <String>[];
    void addHost(String? value) {
      final cleaned = value?.trim() ?? '';
      if (cleaned.isNotEmpty && !hosts.contains(cleaned)) {
        hosts.add(cleaned);
      }
    }

    if (_customServerHost != null && _customServerHost!.isNotEmpty) {
      addHost(_customServerHost);
      return hosts;
    }

    addHost(_runtimeFallbackHost);
    addHost(fallbackLanHost);
    try {
      if (Platform.isAndroid) {
        addHost('10.0.2.2');
        addHost('127.0.0.1');
      }
    } catch (_) {}
    addHost('localhost');
    return hosts;
  }

  /// Configure detected runtime fallback host without overwriting explicit user setting.
  static void setRuntimeFallbackHost(String? host) {
    final trimmed = host?.trim() ?? '';
    _runtimeFallbackHost = trimmed.isEmpty ? null : trimmed;
  }

  /// Configure custom server host/IP (or null/empty to revert to automatic detection)
  static void setServerHost(String? rawHost) {
    final trimmed = rawHost?.trim() ?? '';
    if (trimmed.isEmpty) {
      _customServerHost = null;
      _customFullBaseUrl = null;
      _runtimeFallbackHost = null;
      return;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      var url = trimmed;
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      if (!url.endsWith('/api') && !url.endsWith('/api/v1')) {
        url = '$url/api';
      }
      _customFullBaseUrl = url;

      var cleaned = trimmed.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
      cleaned = cleaned.split('/').first.trim();
      if (cleaned.contains(':')) {
        cleaned = cleaned.split(':').first.trim();
      }
      _customServerHost = cleaned.isEmpty ? null : cleaned;
      _runtimeFallbackHost = null;
      return;
    }

    var cleaned = trimmed.replaceAll(RegExp(r'^https?://', caseSensitive: false), '');
    cleaned = cleaned.split('/').first.trim();
    if (cleaned.contains(':')) {
      cleaned = cleaned.split(':').first.trim();
    }
    _customServerHost = cleaned.isEmpty ? null : cleaned;
    _customFullBaseUrl = null;
    _runtimeFallbackHost = null;
  }

  /// Build base API URL for an explicit host
  static String baseUrlForHost(String host) {
    if (kIsWeb) {
      if (_customFullBaseUrl != null &&
          _customFullBaseUrl!.isNotEmpty &&
          !_customFullBaseUrl!.contains('localhost') &&
          !_customFullBaseUrl!.contains('127.0.0.1')) {
        return _customFullBaseUrl!;
      }
      if (host.startsWith('http://') || host.startsWith('https://')) {
        if (!host.contains('localhost') && !host.contains('127.0.0.1')) {
          var url = host;
          if (url.endsWith('/')) url = url.substring(0, url.length - 1);
          if (!url.endsWith('/api') && !url.endsWith('/api/v1')) url = '$url/api';
          return url;
        }
      }
      return _kDefaultLiveWebBackend;
    }
    if (_customFullBaseUrl != null && _customFullBaseUrl!.isNotEmpty) {
      return _customFullBaseUrl!;
    }
    if (configuredApiUrl.isNotEmpty) {
      return configuredApiUrl;
    }
    if (host.startsWith('http://') || host.startsWith('https://')) {
      var url = host;
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      if (!url.endsWith('/api') && !url.endsWith('/api/v1')) url = '$url/api';
      return url;
    }
    return 'http://$host:8000/api';
  }

  static const String appName = 'LifeRoute Emergency';
  static const String appVersion = '1.0.0';

  // Emergency Hotlines (Prompt requirement: 108 India)
  static const String emergency108India = '108'; // Free Emergency Ambulance Service (India)
  static const String nationalEmergencyNumber = '112'; // Universal Emergency Hotline
  static const String alternateHotline = '999';

  // Dispatch Backend Defaults
  static String get defaultBaseUrl {
    if (kIsWeb) {
      if (_customFullBaseUrl != null &&
          _customFullBaseUrl!.isNotEmpty &&
          !_customFullBaseUrl!.contains('localhost') &&
          !_customFullBaseUrl!.contains('127.0.0.1')) {
        return _customFullBaseUrl!;
      }
      if (configuredApiUrl.isNotEmpty &&
          !configuredApiUrl.contains('localhost') &&
          !configuredApiUrl.contains('127.0.0.1')) {
        return configuredApiUrl;
      }
      return _kDefaultLiveWebBackend;
    }
    return configuredApiUrl.isNotEmpty
        ? configuredApiUrl
        : (_customFullBaseUrl ?? defaultLocalBaseUrl);
  }
  static String get defaultLocalBaseUrl => 'http://$effectiveHost:8000/api';
  static String get reverbHost => effectiveHost.contains('trycloudflare.com')
      ? 'measure-science-annually-query.trycloudflare.com'
      : effectiveHost;
  static int get reverbPort => reverbHost.contains('trycloudflare.com') ? 443 : 8080;
  static bool get reverbUseTls => reverbHost.contains('trycloudflare.com') || defaultBaseUrl.startsWith('https://');
  static const String reverbAppKey = 'liferoute_reverb_key';

  // Storage Keys
  static const String serverHostKey = 'lr_server_host';
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
