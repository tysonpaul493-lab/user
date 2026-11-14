import 'package:flutter/services.dart';
import 'storage_service.dart';

class SimInfoResult {
  final bool hasSim;
  final String? simNumber;
  final String? carrier;
  final int simCount;

  const SimInfoResult({
    required this.hasSim,
    this.simNumber,
    this.carrier,
    this.simCount = 0,
  });

  bool get isIdentified => simNumber != null && simNumber!.trim().isNotEmpty;
}

class SimDetectionService {
  static const MethodChannel _channel =
      MethodChannel('com.liferoute.emergency/sim_info');

  /// Detect physical SIM card status and phone number from the device hardware
  static Future<SimInfoResult> detectSimInfo() async {
    try {
      final res = await _channel.invokeMethod<Map>('getSimInfo');
      if (res == null) {
        return const SimInfoResult(hasSim: false);
      }

      final hasSim = res['hasSim'] == true;
      final rawNumber = res['simNumber']?.toString().trim();
      final carrier = res['carrier']?.toString().trim();
      final simCount = (res['simCount'] as num?)?.toInt() ?? (hasSim ? 1 : 0);

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
        simNumber: cleanSimNumber,
        carrier: (carrier != null && carrier.isNotEmpty) ? carrier : null,
        simCount: simCount,
      );
    } catch (_) {
      return const SimInfoResult(hasSim: false);
    }
  }

  /// Resolve the genuine SIM mobile number using hardware detection, entered input, or device storage.
  /// Never returns a fake static fallback.
  static Future<String?> resolveGenuineSimNumber({
    required StorageService storage,
    String? currentInput,
  }) async {
    // 1. If user typed a 10-digit mobile number on the login field, use it
    if (currentInput != null && currentInput.trim().isNotEmpty) {
      final digits = currentInput.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        final phone = '+91 $digits';
        await storage.saveLastRegisteredPhone(phone);
        return phone;
      }
    }

    // 2. Query device hardware SIM card
    final hardwareInfo = await detectSimInfo();
    if (hardwareInfo.isIdentified && hardwareInfo.simNumber != null) {
      final phone = hardwareInfo.simNumber!;
      await storage.saveLastRegisteredPhone(phone);
      return phone;
    }

    // 3. Check previously confirmed SIM number from persistent device storage
    final lastSaved = storage.getLastRegisteredPhone();
    if (lastSaved != null && lastSaved.trim().isNotEmpty) {
      final clean = lastSaved.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 10 && !clean.contains('9999910800')) {
        return lastSaved.startsWith('+') ? lastSaved : '+91 $clean';
      }
    }

    // 4. Check cached user profile
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

