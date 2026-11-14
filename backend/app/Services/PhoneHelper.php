<?php

namespace App\Services;

class PhoneHelper
{
    public static function normalizePhone10(?string $phone): string
    {
        $digits = preg_replace('/\D/', '', (string) $phone) ?? '';

        return strlen($digits) >= 10 ? substr($digits, -10) : $digits;
    }

    public static function normalizePhoneE164(?string $phone): string
    {
        $raw = trim((string) $phone);
        $digits = preg_replace('/\D/', '', $raw) ?? '';
        if ($digits === '') {
            return '';
        }

        if (!str_starts_with($raw, '+')) {
            if (str_starts_with($digits, '0') && strlen($digits) === 11) {
                $digits = substr($digits, 1);
            }
            if (strlen($digits) === 10) {
                return '+91'.$digits;
            }
        }

        return '+'.$digits;
    }

    public static function calculateHaversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        if ($lat1 === 0.0 || $lon1 === 0.0 || $lat2 === 0.0 || $lon2 === 0.0) {
            return 0.0;
        }

        $p = 0.017453292519943295; // deg2rad factor
        $a = 0.5
            - cos(($lat2 - $lat1) * $p) / 2
            + (cos($lat1 * $p) * cos($lat2 * $p) * (1 - cos(($lon2 - $lon1) * $p))) / 2;

        return 12742 * asin(sqrt(max(0.0, min(1.0, $a))));
    }

    public static function calculateDrivingDistanceKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $aerial = self::calculateHaversineKm($lat1, $lon1, $lat2, $lon2);
        if ($aerial <= 0.02) {
            return 0.0;
        }
        if ($aerial <= 0.05) {
            return 0.1;
        }

        return round(($aerial * 1.28) + 0.15, 2);
    }

    public static function calculateDrivingDistanceMeters(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        return round(self::calculateDrivingDistanceKm($lat1, $lon1, $lat2, $lon2) * 1000.0, 1);
    }

    public static function estimateEtaMinutes(float $distanceKm): int
    {
        if ($distanceKm <= 0.05) {
            return 0;
        }

        return max(1, min(120, (int) ceil(($distanceKm / 35.0) * 60)));
    }
}
