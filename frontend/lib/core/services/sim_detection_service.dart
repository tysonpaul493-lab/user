import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

class SimInfoResult {
  final bool hasSim;
  final bool hasPermission;
  final bool hasNumbersPermission;
  final String? simNumber;
  final List<String> simNumbers;
  final String? carrier;
  final List<String> carriers;
  final int simCount;

  const SimInfoResult({
    required this.hasSim,
    this.hasPermission = false,
    this.hasNumbersPermission = false,
    this.simNumber,
    this.simNumbers = const [],
    this.carrier,
    this.carriers = const [],
    this.simCount = 0,
  });

  bool get isIdentified =>
      (simNumber != null && simNumber!.trim().isNotEmpty) ||
      simNumbers.isNotEmpty;

  /// Check whether the entered 10-digit number matches any detected hardware SIM on the phone
  bool matchesEnteredNumber(String enteredDigits) {
    final clean = enteredDigits.replaceAll(RegExp(r'\D'), '');
    final tenDigit = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;
    if (tenDigit.length != 10) return false;

    // Check primary SIM number
    if (simNumber != null && simNumber!.isNotEmpty) {
      final s = simNumber!.replaceAll(RegExp(r'\D'), '');
      if (s.endsWith(tenDigit)) return true;
    }

    // Check all detected SIM numbers (dual SIM)
    for (final num in simNumbers) {
      final s = num.replaceAll(RegExp(r'\D'), '');
      if (s.endsWith(tenDigit)) return true;
    }

    return false;
  }
}

class SimVerificationResult {
  final bool isValid;
  final bool isNoSim;
  final bool isMismatch;
  final bool isPermissionDenied;
  final String? errorMessage;
  final String? carrier;
  final String? detectedSimNumber;
  final List<String> detectedSimNumbers;
  final bool hasSim;
  final bool hasPermission;

  const SimVerificationResult({
    required this.isValid,
    this.isNoSim = false,
    this.isMismatch = false,
    this.isPermissionDenied = false,
    this.errorMessage,
    this.carrier,
    this.detectedSimNumber,
    this.detectedSimNumbers = const [],
    this.hasSim = false,
    this.hasPermission = false,
  });
}

class SimDetectionService {
  static const MethodChannel _channel =
      MethodChannel('com.liferoute.emergency/sim_info');

  static SimInfoResult _parseResultMap(Map res) {
    final hasSim = res['hasSim'] == true;
    final hasPermission = res['hasPermission'] == true;
    final hasNumbersPermission = res['hasNumbersPermission'] == true;
    final rawNumber = res['simNumber']?.toString().trim();
    final carrier = res['carrier']?.toString().trim();
    final simCount = (res['simCount'] as num?)?.toInt() ?? (hasSim ? 1 : 0);

    final rawList = res['simNumbers'];
    final List<String> simNumbers = [];
    if (rawList is List) {
      for (final item in rawList) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty && !simNumbers.contains(s)) {
          simNumbers.add(s);
        }
      }
    }

    final rawCarriers = res['carriers'];
    final List<String> carriers = [];
    if (rawCarriers is List) {
      for (final item in rawCarriers) {
        final s = item?.toString().trim() ?? '';
        if (s.isNotEmpty && !carriers.contains(s)) {
          carriers.add(s);
        }
      }
    }

    String? cleanSimNumber;
    if (rawNumber != null && rawNumber.isNotEmpty) {
      final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final last10 = digits.substring(digits.length - 10);
        cleanSimNumber = '+91 $last10';
      } else if (digits.isNotEmpty) {
        cleanSimNumber = rawNumber;
      }
    }

    return SimInfoResult(
      hasSim: hasSim,
      hasPermission: hasPermission,
      hasNumbersPermission: hasNumbersPermission,
      simNumber: cleanSimNumber,
      simNumbers: simNumbers,
      carrier: (carrier != null && carrier.isNotEmpty) ? carrier : null,
      carriers: carriers,
      simCount: simCount,
    );
  }

  /// Register real-time native listener for hardware SIM insertion, swap, or removal
  static void setSimChangedListener(void Function(SimInfoResult)? onChanged) {
    if (onChanged == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSimChanged' && call.arguments is Map) {
        onChanged(_parseResultMap(call.arguments as Map));
      }
    });
  }

  /// Prompt Android runtime Phone/SIM permission so inserted SIM numbers can be verified
  static Future<bool> requestSimPermission() async {
    if (kIsWeb) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestSimPermission');
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  /// Detect physical SIM card status and phone number from the device hardware
  static Future<SimInfoResult> detectSimInfo() async {
    try {
      final res = await _channel.invokeMethod<Map>('getSimInfo');
      if (res == null) {
        return const SimInfoResult(hasSim: false);
      }
      return _parseResultMap(res);
    } catch (_) {
      return const SimInfoResult(hasSim: false);
    }
  }

  /// Strict physical SIM verification guard.
  /// Enforces that the exact phone number is physically inserted into this mobile device.
  static Future<SimVerificationResult> verifyDeviceSim({
    required String enteredPhone,
    bool isTamil = false,
    bool requestPermissionIfNeeded = true,
  }) async {
    final clean = enteredPhone.replaceAll(RegExp(r'\D'), '');
    final tenDigit = clean.length >= 10 ? clean.substring(clean.length - 10) : clean;

    if (tenDigit.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(tenDigit)) {
      return SimVerificationResult(
        isValid: false,
        errorMessage: isTamil
            ? 'செல்லுபடியாகும் 10-இலக்க இந்திய SIM மொபைல் எண்ணை உள்ளிடவும் (6, 7, 8 அல்லது 9 இல் தொடங்க வேண்டும்).'
            : 'Please enter a valid 10-digit Indian SIM mobile number starting with 6, 7, 8, or 9.',
      );
    }

    // Anti-fraud repeating/dummy numbers
    if (RegExp(r'^(\d)\1{9}$').hasMatch(tenDigit) ||
        ['1234567890', '9876543210', '9999910800', '0000000000'].contains(tenDigit)) {
      return SimVerificationResult(
        isValid: false,
        isMismatch: true,
        errorMessage: isTamil
            ? 'மோசடி எச்சரிக்கை: போலியான அல்லது மீண்டும் வரும் எண்களை பயன்படுத்த முடியாது. உங்கள் உண்மையான SIM எண்ணை பயன்படுத்தவும்.'
            : 'Fraud Alert: Suspicious repeating or dummy number cannot be used. Please use your genuine SIM.',
      );
    }

    var info = await detectSimInfo();

    // On mobile platforms with physical telephony
    if (!kIsWeb) {
      if (!info.hasPermission && requestPermissionIfNeeded) {
        await requestSimPermission();
        info = await detectSimInfo();
      }

      if (!info.hasPermission) {
        return SimVerificationResult(
          isValid: false,
          isPermissionDenied: true,
          hasSim: info.hasSim,
          hasPermission: false,
          errorMessage: isTamil
              ? 'இந்த மொபைலில் உள்ள SIM எண்ணைச் சரிபார்க்க தொலைபேசி/SIM அனுமதி அவசியம்.'
              : 'Phone / SIM permission is required to verify the SIM card in this mobile device.',
        );
      }

      if (!info.hasSim) {
        return SimVerificationResult(
          isValid: false,
          isNoSim: true,
          hasSim: false,
          hasPermission: info.hasPermission,
          errorMessage: isTamil
              ? 'பாதுகாப்பு எச்சரிக்கை: இந்த மொபைல் போனில் செயலில் உள்ள SIM அட்டை கண்டறியப்படவில்லை. தொடர உங்கள் உண்மையான SIM அட்டையை இந்த போனில் பொருத்தவும்.'
              : 'Security Alert: No active SIM card detected in this phone. You must insert your physical SIM card into this mobile phone to continue.',
        );
      }

      // Strictly enforce exact match against physical SIM number(s) on device
      if (info.isIdentified) {
        final matches = info.matchesEnteredNumber(tenDigit);
        if (!matches) {
          final hardwareNum = info.simNumber ??
              (info.simNumbers.isNotEmpty ? info.simNumbers.first : 'unknown');
          return SimVerificationResult(
            isValid: false,
            isMismatch: true,
            hasSim: true,
            hasPermission: true,
            detectedSimNumber: hardwareNum,
            detectedSimNumbers: info.simNumbers,
            carrier: info.carrier,
            errorMessage: isTamil
                ? 'பாதுகாப்பு எச்சரிக்கை: உள்ளிடப்பட்ட எண் (+91 $tenDigit) இந்த போனில் உள்ள SIM அட்டையுடன் பொருந்தவில்லை ($hardwareNum). இந்த போனில் உள்ள SIM அட்டையை மட்டுமே பயன்படுத்த முடியும்.'
                : 'Security Alert: SIM card mismatch. The entered mobile number (+91 $tenDigit) is NOT inserted in this phone (Detected: $hardwareNum). Only the active SIM card in this phone is permitted.',
          );
        }
      }
    }

    return SimVerificationResult(
      isValid: true,
      hasSim: info.hasSim,
      hasPermission: info.hasPermission,
      carrier: info.carrier,
      detectedSimNumber: info.simNumber,
      detectedSimNumbers: info.simNumbers,
    );
  }

  /// Resolve genuine SIM number from hardware or storage
  static Future<String?> resolveGenuineSimNumber({
    required StorageService storage,
    String? currentInput,
  }) async {
    if (currentInput != null && currentInput.trim().isNotEmpty) {
      final digits = currentInput.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        final phone = '+91 $digits';
        await storage.saveLastRegisteredPhone(phone);
        return phone;
      }
    }

    final hardwareInfo = await detectSimInfo();
    if (hardwareInfo.isIdentified && hardwareInfo.simNumber != null) {
      final phone = hardwareInfo.simNumber!;
      await storage.saveLastRegisteredPhone(phone);
      return phone;
    }

    final lastSaved = storage.getLastRegisteredPhone();
    if (lastSaved != null && lastSaved.trim().isNotEmpty) {
      final clean = lastSaved.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10 && !clean.contains('9999910800')) {
        return lastSaved.startsWith('+') ? lastSaved : '+91 $clean';
      }
    }

    final cachedUser = storage.getUser();
    if (cachedUser != null && cachedUser.phone.isNotEmpty) {
      final clean = cachedUser.phone.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10 && !clean.contains('9999910800')) {
        return cachedUser.phone;
      }
    }

    return null;
  }
}

