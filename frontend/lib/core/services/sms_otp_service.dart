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
              message: 'SMS verification code delivered to $tenDigitPhone.',
              provider: 'A2I SMS Gateway',
            );
          } else {
            final errorMsg = response.data['message']?.toString() ?? 'Gateway error';
            debugPrint('⚠️ [SMS Gateway] Gateway response: $errorMsg');
          }
        } catch (e) {
          debugPrint('⚠️ [SMS Gateway] Failed to send real SMS: $e');
        }
      } else {
        // Secondary gateway dispatch
        try {
          debugPrint('📡 [SMS Gateway] Dispatching real OTP SMS to $tenDigitPhone...');
          final url = 'https://2factor.in/API/V1/$apiKey/SMS/$tenDigitPhone/$otp/EMERGENCY_OTP';
          final response = await _dio.get(url);

          if (response.statusCode == 200 &&
              response.data['Status']?.toString().toLowerCase() == 'success') {
            debugPrint('✅ [SMS Gateway] Real OTP SMS delivered successfully to $tenDigitPhone!');
            return SmsSendResult(
              isRealSmsSent: true,
              message: 'SMS verification code delivered to $tenDigitPhone.',
              provider: 'A2I SMS Gateway',
            );
          }
        } catch (e) {
          debugPrint('⚠️ [SMS Gateway] Failed to send real SMS: $e');
        }
      }
    }

    // 2. Fallback notice
    debugPrint(
      'ℹ️ [SMS Notice] Configure gateway API key in Dispatch Settings to send cellular SMS to $tenDigitPhone.',
    );

    return SmsSendResult(
      isRealSmsSent: false,
      message: 'Verification code ready for $tenDigitPhone.',
      provider: 'A2I Local Security',
    );
  }
}
