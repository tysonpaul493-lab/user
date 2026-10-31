import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class SmsSendResult {
  final bool isRealSmsSent;
  final String message;
  final String? provider;

  const SmsSendResult({
    required this.isRealSmsSent,
    required this.message,
    this.provider,
  });
}

class SmsOtpService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Send a real SMS OTP directly to user's mobile number via Fast2SMS or 2Factor
  static Future<SmsSendResult> sendRealOtpSms({
    required String phone,
    required String otp,
    String? customApiKey,
  }) async {
    // Extract clean 10-digit Indian phone number
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final tenDigitPhone = cleanPhone.length >= 10
        ? cleanPhone.substring(cleanPhone.length - 10)
        : cleanPhone;

    if (tenDigitPhone.length != 10) {
      return const SmsSendResult(
        isRealSmsSent: false,
        message: 'Invalid 10-digit mobile number format.',
      );
    }

    final apiKey = (customApiKey != null && customApiKey.trim().isNotEmpty)
        ? customApiKey.trim()
        : AppConstants.fast2SmsApiKey.trim().isNotEmpty
            ? AppConstants.fast2SmsApiKey.trim()
            : AppConstants.twoFactorApiKey.trim();

    // 1. If an API key is provided, trigger real SMS delivery
    if (apiKey.isNotEmpty) {
      // Check if Fast2SMS or 2Factor
      if (apiKey.length > 20 && !apiKey.contains('-')) {
        // Typical Fast2SMS API Key (alphanumeric string)
        try {
          debugPrint('📡 [SMS Gateway] Dispatching real OTP SMS via Fast2SMS to $tenDigitPhone...');
          final response = await _dio.post(
            'https://www.fast2sms.com/dev/bulkV2',
            options: Options(
              headers: {
                'authorization': apiKey,
                'Content-Type': 'application/json',
              },
            ),
            data: {
              'route': 'otp',
              'variables_values': otp,
              'numbers': tenDigitPhone,
            },
          );

          if (response.statusCode == 200 &&
              (response.data['return'] == true ||
                  response.data['status_code'] == 200 ||
                  response.data['message']?.toString().toLowerCase().contains('success') == true)) {
            debugPrint('✅ [Fast2SMS] Real OTP SMS delivered successfully to $tenDigitPhone!');
            return SmsSendResult(
              isRealSmsSent: true,
              message: 'Real OTP SMS delivered to $tenDigitPhone via Fast2SMS.',
              provider: 'Fast2SMS',
            );
          } else {
            final errorMsg = response.data['message']?.toString() ?? 'Gateway error';
            debugPrint('⚠️ [Fast2SMS] Gateway response: $errorMsg');
          }
        } catch (e) {
          debugPrint('⚠️ [Fast2SMS] Failed to send real SMS: $e');
        }
      } else {
        // Typical 2Factor.in API Key
        try {
          debugPrint('📡 [SMS Gateway] Dispatching real OTP SMS via 2Factor to $tenDigitPhone...');
          final url = 'https://2factor.in/API/V1/$apiKey/SMS/$tenDigitPhone/$otp/EMERGENCY_OTP';
          final response = await _dio.get(url);

          if (response.statusCode == 200 &&
              response.data['Status']?.toString().toLowerCase() == 'success') {
            debugPrint('✅ [2Factor] Real OTP SMS delivered successfully to $tenDigitPhone!');
            return SmsSendResult(
              isRealSmsSent: true,
              message: 'Real OTP SMS delivered to $tenDigitPhone via 2Factor.',
              provider: '2Factor.in',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [2Factor] Failed to send real SMS: $e');
        }
      }
    }

    // 2. Fallback: Log helpful API key setup hint and return simulated success
    debugPrint(
      'ℹ️ [SMS Notice] Real SMS API Key not configured yet. '
      'To deliver real SMS to $tenDigitPhone, get a free API key from https://www.fast2sms.com '
      'and paste it into AppConstants.fast2SmsApiKey.',
    );

    return SmsSendResult(
      isRealSmsSent: false,
      message: 'Simulated dispatch to $tenDigitPhone. Code: $otp',
      provider: 'LifeRoute Local Simulator',
    );
  }
}
