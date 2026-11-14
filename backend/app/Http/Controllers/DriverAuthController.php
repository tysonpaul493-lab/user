<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\DriverDocument;
use App\Models\DriverPhoneAlias;
use App\Models\DriverToken;
use App\Models\OtpCode;
use App\Services\DriverAuthResolver;
use App\Services\PhoneHelper;
use App\Services\SmsGatewayService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;

class DriverAuthController extends Controller
{
    public function checkPhone(Request $request): JsonResponse
    {
        $phone = (string) $request->input('phone', '');
        $key = PhoneHelper::normalizePhone10($phone);
        $driver = $this->findDriverByPhoneKey($key);

        return response()->json([
            'status' => 'success',
            'registered' => $driver !== null,
            'driver_name' => $driver?->name,
        ]);
    }

    public function smsStatus(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'gateway_configured' => SmsGatewayService::hasConfiguredGateway(),
        ]);
    }

    public function sendOtp(Request $request): JsonResponse
    {
        $rawPhone = trim((string) $request->input('phone', ''));
        $e164Phone = PhoneHelper::normalizePhoneE164($rawPhone);
        $key = PhoneHelper::normalizePhone10($e164Phone) ?: $e164Phone;

        if ($rawPhone === '' || strlen($key) < 7) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please enter a valid mobile number.',
            ], 400);
        }

        // Invisible backend anti-hacking rate limit check
        $throttleKey = 'driver-send-otp:' . $request->ip() . ':' . $key;
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            Log::warning("Anti-hacking rate limit for IP {$request->ip()} on driver phone {$key}");
            return response()->json([
                'status' => 'error',
                'message' => "Security check: Too many requests. Please retry in {$seconds}s.",
            ], 429);
        }
        RateLimiter::hit($throttleKey, 300);

        $otp = (string) random_int(100000, 999999);
        OtpCode::updateOrCreate(
            ['scope' => 'driver', 'phone_key' => $key],
            [
                'e164_phone' => $e164Phone,
                'otp_code' => $otp,
                'expires_at' => now()->addMinutes(5),
            ]
        );

        $sms = SmsGatewayService::dispatchOtp($e164Phone ?: $rawPhone, $otp);

        if (!$sms['sent']) {
            return response()->json([
                'status' => 'error',
                'sms_dispatched' => false,
                'gateway_configured' => $sms['configured'],
                'message' => $sms['error'] ?? 'SMS OTP delivery is not active on this server. Configure the SMS gateway device to receive real 6-digit OTP messages.',
            ], $sms['configured'] ? 502 : 503);
        }

        return response()->json([
            'status' => 'success',
            'message' => '6-digit SMS OTP sent to '.($e164Phone ?: $rawPhone).'.',
            'sms_dispatched' => true,
            'otp_expires_in' => 300,
        ]);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $rawPhone = (string) $request->input('phone', '');
        $otp = trim((string) $request->input('otp', ''));
        $e164Phone = PhoneHelper::normalizePhoneE164($rawPhone) ?: trim($rawPhone);
        $key = PhoneHelper::normalizePhone10($e164Phone) ?: $e164Phone;

        // Anti-hacking brute-force defense
        $throttleKey = 'driver-verify-otp:' . $request->ip() . ':' . $key;
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            Log::warning("Anti-hacking OTP lockout for IP {$request->ip()} on driver phone {$key}");
            return response()->json([
                'status' => 'error',
                'message' => "Security lockout: Too many incorrect attempts. Retry in {$seconds}s.",
            ], 429);
        }

        $stored = OtpCode::where('scope', 'driver')
            ->where('phone_key', $key)
            ->first();

        if ($stored && now()->gt($stored->expires_at)) {
            $stored->delete();

            return response()->json([
                'status' => 'error',
                'message' => 'Verification code expired. Tap Resend SMS Code to receive a new OTP.',
            ], 401);
        }

        $isValid = $stored !== null
            && preg_match('/^\d{6}$/', $otp) === 1
            && $stored->otp_code === $otp;

        if (!$isValid) {
            RateLimiter::hit($throttleKey, 300);
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid SMS verification code. Please check your SMS inbox and try again.',
            ], 401);
        }

        RateLimiter::clear($throttleKey);
        $stored->delete();

        $driver = $this->findDriverByPhoneKey($key);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'registration_required' => true,
                'message' => 'No registered driver account found for this mobile number. Please register first.',
            ], 404);
        }

        if ($e164Phone !== '' && $driver->phone !== $e164Phone) {
            $driver->update(['phone' => $e164Phone]);
        }

        $token = DriverAuthResolver::issueToken(
            $driver,
            (string) $request->input('device_name', 'Driver Mobile App')
        );

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'token_type' => 'Bearer',
            'driver' => $driver->toApiJson(),
        ]);
    }

    public function login(Request $request): JsonResponse
    {
        $rawPhone = trim((string) $request->input('phone', ''));
        $password = (string) $request->input('password', '');
        $e164Phone = PhoneHelper::normalizePhoneE164($rawPhone) ?: $rawPhone;
        $key = PhoneHelper::normalizePhone10($e164Phone) ?: $e164Phone;

        if ($rawPhone === '' || strlen($key) < 7) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please enter a valid registered mobile number.',
            ], 400);
        }

        if ($password === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Please enter your password.',
            ], 400);
        }

        // Anti-hacking brute-force login protection
        $throttleKey = 'driver-login:' . $request->ip() . ':' . $key;
        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);
            Log::warning("Anti-hacking brute-force password attempt for IP {$request->ip()} on driver phone {$key}");
            return response()->json([
                'status' => 'error',
                'message' => "Security lockout: Too many failed login attempts. Please retry in {$seconds}s.",
            ], 429);
        }

        $driver = $this->findDriverByPhoneKey($key);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'registration_required' => true,
                'message' => 'No registered driver account found for this mobile number. Please register first.',
            ], 404);
        }

        if ($driver->password && !Hash::check($password, $driver->password)) {
            RateLimiter::hit($throttleKey, 300);
            return response()->json([
                'status' => 'error',
                'message' => 'Incorrect password. Tap Forgot Password to reset.',
            ], 401);
        }

        RateLimiter::clear($throttleKey);

        if (!$driver->password) {
            $driver->update(['password' => Hash::make($password)]);
        }

        if ($e164Phone !== '' && $driver->phone !== $e164Phone) {
            $driver->update(['phone' => $e164Phone]);
        }

        $token = DriverAuthResolver::issueToken(
            $driver,
            (string) $request->input('device_name', 'Driver Mobile App')
        );

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'token_type' => 'Bearer',
            'driver' => $driver->toApiJson(),
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        return $this->resetPassword($request);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $rawPhone = trim((string) $request->input('phone', ''));
        $newPassword = (string) ($request->input('password') ?? $request->input('new_password') ?? '');
        $confirmPassword = (string) ($request->input('password_confirmation') ?? $request->input('confirm_password') ?? $newPassword);
        $e164Phone = PhoneHelper::normalizePhoneE164($rawPhone) ?: $rawPhone;
        $key = PhoneHelper::normalizePhone10($e164Phone) ?: $e164Phone;

        if ($rawPhone === '' || strlen($key) < 7) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please enter a valid registered mobile number.',
            ], 400);
        }

        if (strlen($newPassword) < 6) {
            return response()->json([
                'status' => 'error',
                'message' => 'New password must be at least 6 characters.',
            ], 400);
        }

        if ($newPassword !== $confirmPassword) {
            return response()->json([
                'status' => 'error',
                'message' => 'New password and confirm password do not match.',
            ], 400);
        }

        $driver = $this->findDriverByPhoneKey($key);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'message' => 'No registered driver account found for this mobile number.',
            ], 404);
        }

        $driver->update([
            'password' => Hash::make($newPassword),
        ]);

        $token = DriverAuthResolver::issueToken($driver, 'Driver Mobile App');

        return response()->json([
            'status' => 'success',
            'message' => 'Password reset successfully. You are now logged in.',
            'token' => $token,
            'token_type' => 'Bearer',
            'driver' => $driver->toApiJson(),
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        $data = $request->all();
        $rawName = trim((string) ($data['name'] ?? ''));
        $rawPhone = trim((string) ($data['phone'] ?? ''));
        $rawPassword = trim((string) ($data['password'] ?? ''));
        $hashedPassword = $rawPassword !== '' ? Hash::make($rawPassword) : null;
        $key = PhoneHelper::normalizePhone10($rawPhone);
        $e164Phone = PhoneHelper::normalizePhoneE164($rawPhone) ?: $rawPhone;

        if ($rawName === '' || strlen($key) < 7) {
            return response()->json([
                'status' => 'error',
                'message' => 'Please provide a valid driver full name and mobile number.',
            ], 400);
        }

        $amb = (isset($data['ambulance']) && is_array($data['ambulance'])) ? $data['ambulance'] : $data;
        $rawPlate = strtoupper(trim((string) ($amb['registration_number'] ?? $data['registration_number'] ?? '')));
        $normalizedType = Driver::normalizeVehicleType($amb['vehicle_type'] ?? $data['vehicle_type'] ?? 'als');

        $driver = $this->findDriverByPhoneKey($key);

        if (!$driver) {
            $driver = Driver::create([
                'name' => $rawName,
                'phone' => $e164Phone,
                'phone_key' => $key,
                'password' => $hashedPassword,
                'email' => trim((string) ($data['email'] ?? '')),
                'emergency_contact' => trim((string) ($data['emergency_contact'] ?? '')),
                'license_number' => trim((string) ($data['license_number'] ?? '')),
                'license_expiry_date' => trim((string) ($data['license_expiry_date'] ?? '')),
                'rating' => 5.0,
                'total_trips' => 0,
                'vehicle_number' => $rawPlate,
                'vehicle_plate' => $rawPlate,
                'vehicle_type' => $normalizedType,
                'vehicle_model' => trim((string) ($amb['make_model'] ?? 'Standard Ambulance')),
                'vehicle_year' => (int) ($amb['year'] ?? 2024) ?: 2024,
                'equipment_list' => is_array($amb['equipment_list'] ?? null) ? $amb['equipment_list'] : [],
                'operator_affiliation' => trim((string) ($amb['operator_affiliation'] ?? 'Independent Emergency Fleet')),
                'permit_number' => trim((string) ($amb['permit_number'] ?? '')),
                'permit_expiry_date' => trim((string) ($amb['permit_expiry_date'] ?? '')),
                'insurance_policy_number' => trim((string) ($amb['insurance_policy_number'] ?? '')),
                'insurance_expiry_date' => trim((string) ($amb['insurance_expiry_date'] ?? '')),
                'documents_uploaded' => [
                    'driving_license_front' => false,
                    'driving_license_back' => false,
                    'vehicle_registration' => false,
                    'ambulance_permit' => false,
                    'commercial_driver_badge' => false,
                    'insurance_policy' => false,
                ],
                'verification_status' => 'approved',
                'is_online' => true,
                'lat' => 11.0210,
                'lng' => 76.9380,
                'heading' => 0.0,
                'speed' => 0.0,
            ]);
        } else {
            $updates = [
                'name' => $rawName,
                'phone' => $e164Phone,
                'vehicle_plate' => $rawPlate,
                'vehicle_number' => $rawPlate,
                'vehicle_type' => $normalizedType,
                'verification_status' => 'approved',
            ];
            if ($hashedPassword !== null) {
                $updates['password'] = $hashedPassword;
            }
            foreach (['email', 'emergency_contact', 'license_number', 'license_expiry_date'] as $field) {
                if (array_key_exists($field, $data)) {
                    $updates[$field] = trim((string) ($data[$field] ?? ''));
                }
            }
            if (!empty($amb['make_model'])) {
                $updates['vehicle_model'] = trim((string) $amb['make_model']);
            }
            if (!empty($amb['year'])) {
                $updates['vehicle_year'] = (int) $amb['year'] ?: $driver->vehicle_year;
            }
            if (is_array($amb['equipment_list'] ?? null)) {
                $updates['equipment_list'] = $amb['equipment_list'];
            }
            if (!empty($amb['operator_affiliation'])) {
                $updates['operator_affiliation'] = trim((string) $amb['operator_affiliation']);
            }
            if (!empty($amb['permit_number'])) {
                $updates['permit_number'] = trim((string) $amb['permit_number']);
            }
            if (!empty($amb['permit_expiry_date'])) {
                $updates['permit_expiry_date'] = trim((string) $amb['permit_expiry_date']);
            }
            if (!empty($amb['insurance_policy_number'])) {
                $updates['insurance_policy_number'] = trim((string) $amb['insurance_policy_number']);
            }
            if (!empty($amb['insurance_expiry_date'])) {
                $updates['insurance_expiry_date'] = trim((string) $amb['insurance_expiry_date']);
            }
            $driver->update($updates);
        }

        DriverPhoneAlias::updateOrCreate(['phone_key' => $key], ['driver_id' => $driver->id]);

        $token = DriverAuthResolver::issueToken($driver, 'Driver Mobile App');

        return response()->json([
            'status' => 'success',
            'token' => $token,
            'token_type' => 'Bearer',
            'driver' => $driver->toApiJson(),
        ]);
    }

    public function uploadDocument(Request $request): JsonResponse
    {
        $driver = DriverAuthResolver::resolveDriver($request);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthenticated driver session.',
            ], 401);
        }
        $docType = trim((string) ($request->input('document_type') ?? $request->query('document_type') ?? 'document'));

        $filePath = null;
        $originalName = null;
        $mimeType = null;
        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $originalName = $file->getClientOriginalName();
            $mimeType = $file->getClientMimeType();
            $filePath = $file->store('driver-documents/'.$driver->id, 'local');
        } elseif ($request->hasFile('document')) {
            $file = $request->file('document');
            $originalName = $file->getClientOriginalName();
            $mimeType = $file->getClientMimeType();
            $filePath = $file->store('driver-documents/'.$driver->id, 'local');
        }

        DriverDocument::create([
            'driver_id' => $driver->id,
            'document_type' => $docType,
            'original_filename' => $originalName,
            'mime_type' => $mimeType,
            'file_path' => $filePath,
        ]);

        $docs = is_array($driver->documents_uploaded) ? $driver->documents_uploaded : [];
        if ($docType !== '') {
            $docs[$docType] = true;
        }
        $driver->update(['documents_uploaded' => $docs]);

        return response()->json([
            'status' => 'success',
            'document_type' => $docType,
            'uploaded' => true,
            'documents_uploaded' => $docs,
            'verification_status' => $driver->verification_status ?: 'approved',
        ]);
    }

    public function profile(Request $request): JsonResponse
    {
        $driver = DriverAuthResolver::resolveDriver($request);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthenticated driver session.',
            ], 401);
        }

        return response()->json([
            'status' => 'success',
            'driver' => $driver->toApiJson(),
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $driver = DriverAuthResolver::resolveDriver($request);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthenticated driver session.',
            ], 401);
        }
        $data = $request->all();
        $updates = [];

        if (!empty($data['name'])) {
            $updates['name'] = trim((string) $data['name']);
        }
        foreach (['email', 'emergency_contact', 'license_number'] as $field) {
            if (array_key_exists($field, $data)) {
                $updates[$field] = trim((string) ($data[$field] ?? ''));
            }
        }

        $veh = $data['assigned_vehicle'] ?? $data['ambulance'] ?? $data;
        if (!empty($veh['registration_number'])) {
            $plate = strtoupper(trim((string) $veh['registration_number']));
            $updates['vehicle_plate'] = $plate;
            $updates['vehicle_number'] = $plate;
        }
        if (!empty($veh['vehicle_type'])) {
            $updates['vehicle_type'] = Driver::normalizeVehicleType((string) $veh['vehicle_type']);
        }
        if (!empty($veh['make_model'])) {
            $updates['vehicle_model'] = trim((string) $veh['make_model']);
        }
        if (!empty($veh['operator_affiliation'])) {
            $updates['operator_affiliation'] = trim((string) $veh['operator_affiliation']);
        }

        if (!empty($updates)) {
            $driver->update($updates);
        }

        return response()->json([
            'status' => 'success',
            'driver' => $driver->fresh()->toApiJson(),
        ]);
    }

    public function verificationStatus(Request $request): JsonResponse
    {
        $driver = DriverAuthResolver::resolveDriver($request);
        if (!$driver) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unauthenticated driver session.',
            ], 401);
        }
        $status = $driver->verification_status ?: 'approved';

        return response()->json([
            'status' => $status,
            'verification_status' => $status,
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $token = DriverAuthResolver::extractBearerToken($request);
        if ($token !== '') {
            DriverToken::where('token', $token)->delete();
        }

        return response()->json(['status' => 'success']);
    }

    private function findDriverByPhoneKey(string $phoneKey): ?Driver
    {
        if ($phoneKey === '') {
            return null;
        }

        $alias = DriverPhoneAlias::where('phone_key', $phoneKey)->first();
        if ($alias) {
            return Driver::find($alias->driver_id);
        }

        return Driver::where('phone_key', $phoneKey)->first();
    }
}
