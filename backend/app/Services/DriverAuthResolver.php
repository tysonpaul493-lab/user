<?php

namespace App\Services;

use App\Models\Driver;
use App\Models\DriverToken;
use Illuminate\Http\Request;

class DriverAuthResolver
{
    public static function extractBearerToken(Request $request): string
    {
        $auth = (string) $request->header('Authorization', '');
        if (str_starts_with($auth, 'Bearer ')) {
            return trim(substr($auth, 7));
        }

        return '';
    }

    public static function issueToken(Driver $driver, string $deviceName = 'Driver Mobile App'): string
    {
        $token = $driver->id.'|driver_sanctum_token_'.time().'_'.random_int(100, 999);
        DriverToken::create([
            'driver_id' => $driver->id,
            'token' => $token,
            'device_name' => $deviceName,
        ]);

        return $token;
    }

    public static function resolveDriver(Request $request, ?int $explicitDriverId = null): ?Driver
    {
        if ($explicitDriverId !== null) {
            $explicit = Driver::find($explicitDriverId);
            if ($explicit) {
                return $explicit;
            }
        }

        $token = self::extractBearerToken($request);
        if ($token !== '') {
            $record = DriverToken::where('token', $token)->first();
            if ($record) {
                $driver = Driver::find($record->driver_id);
                if ($driver) {
                    return $driver;
                }
            }

            $parts = explode('|', $token, 2);
            if (isset($parts[0]) && ctype_digit($parts[0])) {
                $driver = Driver::find((int) $parts[0]);
                if ($driver) {
                    return $driver;
                }
            }
        }

        return null;
    }
}
