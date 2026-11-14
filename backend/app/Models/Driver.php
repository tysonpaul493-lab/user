<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Driver extends Model
{
    protected $fillable = [
        'name',
        'phone',
        'phone_key',
        'password',
        'email',
        'emergency_contact',
        'license_number',
        'license_expiry_date',
        'rating',
        'total_trips',
        'vehicle_number',
        'vehicle_plate',
        'vehicle_type',
        'vehicle_type_display',
        'vehicle_model',
        'vehicle_year',
        'equipment_list',
        'operator_affiliation',
        'permit_number',
        'permit_expiry_date',
        'insurance_policy_number',
        'insurance_expiry_date',
        'documents_uploaded',
        'verification_status',
        'is_online',
        'lat',
        'lng',
        'heading',
        'speed',
    ];

    protected $hidden = [
        'password',
    ];

    protected function casts(): array
    {
        return [
            'rating' => 'float',
            'total_trips' => 'integer',
            'vehicle_year' => 'integer',
            'equipment_list' => 'array',
            'documents_uploaded' => 'array',
            'is_online' => 'boolean',
            'lat' => 'float',
            'lng' => 'float',
            'heading' => 'float',
            'speed' => 'float',
        ];
    }

    public static function normalizeVehicleType(?string $type): string
    {
        $code = strtolower(trim((string) $type));
        if (in_array($code, ['bls', 'als', 'ptv', 'nicu'], true)) {
            return $code;
        }
        if (str_contains($code, 'basic')) {
            return 'bls';
        }
        if (str_contains($code, 'patient')) {
            return 'ptv';
        }
        if (str_contains($code, 'neonatal') || str_contains($code, 'nicu')) {
            return 'nicu';
        }
        return 'als';
    }

    public function toApiJson(): array
    {
        $normalizedType = self::normalizeVehicleType($this->vehicle_type);

        return [
            'id' => (int) $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email ?? '',
            'emergency_contact' => $this->emergency_contact ?? '',
            'license_number' => $this->license_number ?? '',
            'license_expiry_date' => $this->license_expiry_date ?? '',
            'rating' => (float) ($this->rating ?? 4.95),
            'total_trips' => (int) ($this->total_trips ?? 0),
            'completed_trips_count' => (int) ($this->total_trips ?? 0),
            'is_online' => (bool) $this->is_online,
            'verification_status' => $this->verification_status ?: 'approved',
            'documents_uploaded' => $this->documents_uploaded ?: [],
            'assigned_vehicle' => [
                'id' => (int) $this->id,
                'registration_number' => $this->vehicle_plate ?: ($this->vehicle_number ?: ''),
                'vehicle_type' => $normalizedType,
                'make_model' => $this->vehicle_model ?: '',
                'year' => (int) ($this->vehicle_year ?: 2024),
                'equipment_list' => is_array($this->equipment_list) ? $this->equipment_list : [],
                'operator_affiliation' => $this->operator_affiliation ?: '',
                'permit_number' => $this->permit_number ?: '',
                'permit_expiry_date' => $this->permit_expiry_date ?: '',
                'insurance_policy_number' => $this->insurance_policy_number ?: '',
                'insurance_expiry_date' => $this->insurance_expiry_date ?: '',
                'is_eligible' => true,
            ],
        ];
    }

    public function toAssignedDriverPayload(): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name ?? '',
            'title' => $this->vehicle_type_display ?: self::normalizeVehicleType($this->vehicle_type),
            'phone' => $this->phone ?? '',
            'ambulance_number' => $this->vehicle_plate ?: ($this->vehicle_number ?: ''),
            'ambulance_type' => self::normalizeVehicleType($this->vehicle_type),
            'rating' => (float) ($this->rating ?? 5.0),
            'total_trips' => (int) ($this->total_trips ?? 0),
            'current_lat' => (float) $this->lat,
            'current_lng' => (float) $this->lng,
            'heading' => (float) $this->heading,
            'last_location_update' => now()->toIso8601String(),
        ];
    }
}
