import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const String _kDefaultLiveWebBackend = 'http://localhost:8000/api';

String get _detectedUserHost {
  if (AppConstants.configuredApiUrl.isNotEmpty) {
    return AppConstants.configuredApiUrl;
  }
  // Primary default for mobile and web: Live Cloudflare Dispatch Gateway
  return _kDefaultLiveWebBackend;
}

class AppConstants {
  /// Default PC LAN IP used automatically on mobile devices when USB adb reverse is unavailable.
  /// Override at build time via `--dart-define=DEFAULT_LAN_HOST=...` or `--dart-define=DEFAULT_API_URL=...`.
  static const String fallbackLanHost = String.fromEnvironment(
    'DEFAULT_LAN_HOST',
    defaultValue: '192.168.0.106',
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
    if (_customServerHost != null && _customServerHost!.isNotEmpty) {
      return _customServerHost!;
    }
    if (_runtimeFallbackHost != null && _runtimeFallbackHost!.isNotEmpty) {
      return _runtimeFallbackHost!;
    }
    if (kIsWeb) {
      try {
        final webHost = Uri.base.host.trim();
        if (webHost.isNotEmpty && (webHost == 'localhost' || webHost == '127.0.0.1' || webHost.startsWith('192.168.'))) {
          return webHost;
        }
      } catch (_) {}
      return _kDefaultLiveWebBackend;
    }
    return _detectedUserHost;
  }

  static bool get hasCustomServerHost =>
      _customServerHost != null && _customServerHost!.isNotEmpty;

  /// User-friendly label of the current server endpoint for notifications and error messages
  static String get displayServerEndpoint {
    if (_customFullBaseUrl != null && _customFullBaseUrl!.isNotEmpty) {
      return _customFullBaseUrl!.replaceAll(RegExp(r'^https?://'), '');
    }
    if (_customServerHost != null && _customServerHost!.isNotEmpty) {
      return '$_customServerHost:8000';
    }
    if (_runtimeFallbackHost != null && _runtimeFallbackHost!.isNotEmpty) {
      return '$_runtimeFallbackHost:8000';
    }
    if (kIsWeb) {
      try {
        final webHost = Uri.base.host.trim();
        if (webHost.isNotEmpty && (webHost == 'localhost' || webHost == '127.0.0.1' || webHost.startsWith('192.168.'))) {
          return '$webHost:8000';
        }
      } catch (_) {}
      return 'Cloudflare Dispatch Gateway';
    }
    if (effectiveHost.startsWith('http://') || effectiveHost.startsWith('https://')) {
      return effectiveHost.replaceAll(RegExp(r'^https?://'), '');
    }
    return '$effectiveHost:8000';
  }

  /// Ordered unique list of candidate backend hosts for automatic connection resolution.
  static List<String> get candidateHosts {
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

    if (kIsWeb) {
      try {
        final webHost = Uri.base.host.trim();
        if (webHost.isNotEmpty) {
          addHost(webHost);
        }
      } catch (_) {}
    }

    addHost('localhost');
    addHost('127.0.0.1');
    addHost(fallbackLanHost);
    addHost(_kDefaultLiveWebBackend);

    try {
      if (Platform.isAndroid) {
        addHost('10.0.2.2');
      }
    } catch (_) {}

    return hosts;
  }

  /// Configure detected runtime fallback host without overwriting explicit user setting.
  static void setRuntimeFallbackHost(String? host) {
    final trimmed = host?.trim() ?? '';
    _runtimeFallbackHost = trimmed.isEmpty ? null : trimmed;
  }

  static String? get customFullBaseUrl => _customFullBaseUrl;

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

    // Auto-detect cloud tunnel domains entered without scheme
    if (trimmed.contains('trycloudflare.com') ||
        trimmed.contains('ngrok') ||
        (trimmed.contains('.') &&
            !RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(trimmed) &&
            !trimmed.contains(':8000'))) {
      var url = 'https://$trimmed';
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      if (!url.endsWith('/api') && !url.endsWith('/api/v1')) {
        url = '$url/api';
      }
      _customFullBaseUrl = url;
      var cleaned = trimmed.split('/').first.trim();
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
    if (_customFullBaseUrl != null &&
        _customFullBaseUrl!.isNotEmpty &&
        (host == _customServerHost || host == effectiveHost)) {
      return _customFullBaseUrl!;
    }
    if (host.startsWith('http://') || host.startsWith('https://')) {
      var url = host;
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      if (!url.endsWith('/api') && !url.endsWith('/api/v1')) url = '$url/api';
      return url;
    }
    if (host.contains('trycloudflare.com') || host.contains('ngrok')) {
      return 'https://$host/api';
    }
    if (configuredApiUrl.isNotEmpty) {
      return configuredApiUrl;
    }
    return 'http://$host:8000/api';
  }

  static const String appName = 'A2I';
  static const String appVersion = '1.0.0';

  // Emergency Hotlines (Prompt requirement: 108 India)
  static const String emergency108India = '108'; // Free Emergency Ambulance Service (India)
  static const String nationalEmergencyNumber = '112'; // Universal Emergency Hotline
  static const String alternateHotline = '999';

  // Dispatch Backend Defaults
  static String get defaultBaseUrl {
    if (_customFullBaseUrl != null && _customFullBaseUrl!.isNotEmpty) {
      return _customFullBaseUrl!;
    }
    if (_customServerHost != null && _customServerHost!.isNotEmpty) {
      return baseUrlForHost(_customServerHost!);
    }
    if (configuredApiUrl.isNotEmpty) {
      return configuredApiUrl;
    }
    if (_runtimeFallbackHost != null && _runtimeFallbackHost!.isNotEmpty) {
      return baseUrlForHost(_runtimeFallbackHost!);
    }
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin.trim();
        if (origin.isNotEmpty && !origin.startsWith('file:') && origin != 'null') {
          return '$origin/api';
        }
      } catch (_) {}
    }
    return _kDefaultLiveWebBackend;
  }
  static String get defaultLocalBaseUrl => 'http://$effectiveHost:8000/api';
  static String get reverbHost {
    if (kIsWeb) {
      try {
        final host = Uri.base.host.trim();
        if (host.isNotEmpty && !host.contains('trycloudflare.com')) {
          return host;
        }
      } catch (_) {}
    }
    return effectiveHost == 'localhost' || effectiveHost == '127.0.0.1' ? '127.0.0.1' : effectiveHost;
  }
  static int get reverbPort => 8080;
  static bool get reverbUseTls => false;
  static const String reverbAppKey = 'liferoute_reverb_key';

  // Storage Keys
  static const String serverHostKey = 'lr_server_host';
  static const String tokenKey = 'lr_auth_token';
  static const String userKey = 'lr_user_data';
  static const String localeKey = 'lr_locale_pref';
  static const String emergencyContactsKey = 'lr_emergency_contacts';
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

  // Unset Default Coordinates (No fake GPS anchor; requires live GPS fix)
  static const double defaultLat = 0.0;
  static const double defaultLng = 0.0;
  static const String defaultLocationName = 'Locating Current GPS Position...';
}
