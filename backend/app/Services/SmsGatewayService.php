<?php

namespace App\Services;

use Composer\CaBundle\CaBundle;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SmsGatewayService
{
    private static function httpClient(): PendingRequest
    {
        return Http::timeout(10)->withOptions([
            'verify' => CaBundle::getSystemCaRootBundlePath(),
        ]);
    }
    public static function hasConfiguredGateway(): bool
    {
        return trim((string) config('liferoute.textbee_api_key')) !== ''
            || trim((string) config('liferoute.fast2sms_api_key')) !== ''
            || trim((string) config('liferoute.two_factor_api_key')) !== '';
    }

    public static function sanitizeError(?string $rawMessage): string
    {
        $cleaned = trim((string) preg_replace(
            '/textbee|fast2sms|2factor|firebase/i',
            'SMS gateway',
            (string) $rawMessage
        ));

        return $cleaned !== ''
            ? $cleaned
            : 'Unable to send SMS from the gateway phone. Ensure the SIM gateway device is online with active mobile signal.';
    }

    /**
     * @return array{sent: bool, configured: bool, error?: string}
     */
    public static function dispatchOtp(string $phone, string $otp): array
    {
        $e164Phone = PhoneHelper::normalizePhoneE164($phone);
        $clean10 = PhoneHelper::normalizePhone10($phone);

        if ($e164Phone === '' || strlen($clean10) < 7) {
            return [
                'sent' => false,
                'configured' => self::hasConfiguredGateway(),
                'error' => 'Please enter a valid mobile number with country code.',
            ];
        }

        // 1. TextBee Android SIM Gateway
        $textbeeKey = trim((string) config('liferoute.textbee_api_key'));
        $textbeeDeviceId = trim((string) config('liferoute.textbee_device_id'));
        if ($textbeeKey !== '') {
            try {
                $payload = [
                    'recipients' => [$e164Phone],
                    'message' => "Your LifeRoute Driver verification code is {$otp}. Valid for 5 minutes.",
                ];
                if ($textbeeDeviceId !== '') {
                    $payload['deviceId'] = $textbeeDeviceId;
                }
                $simSubId = trim((string) config('liferoute.textbee_sim_subscription_id'));
                if ($simSubId !== '' && ctype_digit($simSubId)) {
                    $payload['simSubscriptionId'] = (int) $simSubId;
                }

                $resp = self::httpClient()
                    ->withHeaders(['x-api-key' => $textbeeKey])
                    ->post('https://api.textbee.dev/api/v1/gateway/send-sms', $payload);

                $json = $resp->json() ?? [];
                $accepted = $resp->successful() && (
                    ($json['data']['success'] ?? false) === true
                    || ($json['success'] ?? false) === true
                    || !empty($json['data']['smsBatchId'])
                    || !empty($json['smsBatchId'])
                );

                if ($accepted) {
                    return ['sent' => true, 'configured' => true];
                }

                $rawErr = $json['message'] ?? $json['error'] ?? ($json['data']['message'] ?? ('HTTP '.$resp->status()));
                Log::warning("[Driver Auth] SIM gateway rejected SMS (status={$resp->status()}): {$rawErr}");

                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => self::sanitizeError((string) $rawErr),
                ];
            } catch (\Throwable $e) {
                Log::warning('[Driver Auth] SIM gateway network error: '.$e->getMessage());

                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => 'Cannot reach SMS gateway service right now. Check server internet connection.',
                ];
            }
        }

        // 2. Optional Fast2SMS fallback
        $fast2SmsKey = trim((string) config('liferoute.fast2sms_api_key'));
        if ($fast2SmsKey !== '' && strlen($clean10) === 10) {
            try {
                $resp = self::httpClient()
                    ->withHeaders(['authorization' => $fast2SmsKey])
                    ->post('https://www.fast2sms.com/dev/bulkV2', [
                        'route' => 'otp',
                        'variables_values' => $otp,
                        'numbers' => $clean10,
                    ]);
                $json = $resp->json() ?? [];
                if ($resp->successful() && (($json['return'] ?? false) === true || ($json['status_code'] ?? 0) === 200)) {
                    return ['sent' => true, 'configured' => true];
                }

                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => self::sanitizeError((string) ($json['message'] ?? '')),
                ];
            } catch (\Throwable $e) {
                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => 'Unable to reach SMS gateway right now.',
                ];
            }
        }

        // 3. Optional 2Factor fallback
        $twoFactorKey = trim((string) config('liferoute.two_factor_api_key'));
        if ($twoFactorKey !== '' && strlen($clean10) === 10) {
            try {
                $resp = self::httpClient()
                    ->get("https://2factor.in/API/V1/{$twoFactorKey}/SMS/{$clean10}/{$otp}/LIFEROUTE_OTP");
                $json = $resp->json() ?? [];
                if ($resp->successful() && strtolower((string) ($json['Status'] ?? '')) === 'success') {
                    return ['sent' => true, 'configured' => true];
                }

                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => self::sanitizeError((string) ($json['Details'] ?? '')),
                ];
            } catch (\Throwable $e) {
                return [
                    'sent' => false,
                    'configured' => true,
                    'error' => 'Unable to reach SMS gateway right now.',
                ];
            }
        }

        return ['sent' => false, 'configured' => false];
    }
}
