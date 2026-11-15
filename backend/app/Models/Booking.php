<?php

namespace App\Models;

use App\Services\PhoneHelper;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Booking extends Model
{
    public $incrementing = false;
    protected $keyType = 'int';

    protected $fillable = [
        'id',
        'booking_reference',
        'reference_number',
        'driver_id',
        'status',
        'pickup_lat',
        'pickup_lng',
        'pickup_address',
        'pickup_landmark',
        'callback_phone',
        'patient_name',
        'emergency_category',
        'notes',
        'essential_instructions',
        'destination_hospital',
        'destination_address',
        'destination_latitude',
        'destination_longitude',
        'eta_minutes',
        'distance_km',
        'distance_meters',
        'cancel_reason',
        'handover_notes',
        'duration_minutes',
        'earnings',
        'accepted_at',
        'arrived_pickup_at',
        'patient_picked_up_at',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'id' => 'integer',
            'driver_id' => 'integer',
            'pickup_lat' => 'float',
            'pickup_lng' => 'float',
            'destination_hospital' => 'array',
            'destination_latitude' => 'float',
            'destination_longitude' => 'float',
            'eta_minutes' => 'integer',
            'distance_km' => 'float',
            'distance_meters' => 'float',
            'duration_minutes' => 'integer',
            'earnings' => 'float',
            'accepted_at' => 'datetime',
            'arrived_pickup_at' => 'datetime',
            'patient_picked_up_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(Driver::class);
    }

    /**
     * Compute phase-aware live remaining distance & ETA based on driver GPS and active trip leg.
     *
     * @return array{distance_km: float, distance_meters: float, eta_minutes: int}
     */
    public function computePhaseMetrics(): array
    {
        $status = (string) ($this->status ?: 'finding_ambulance');
        if (in_array($status, ['driver_arrived', 'arrived_at_pickup', 'arrived_at_hospital', 'trip_completed', 'completed', 'cancelled'], true)) {
            return [
                'distance_km' => 0.0,
                'distance_meters' => 0.0,
                'eta_minutes' => 0,
            ];
        }

        $destObj = is_array($this->destination_hospital) ? $this->destination_hospital : [];
        $pickupLat = (float) ($this->pickup_lat ?: 0.0);
        $pickupLng = (float) ($this->pickup_lng ?: 0.0);
        $destLat = (float) ($destObj['lat'] ?? $destObj['latitude'] ?? $this->destination_latitude ?: 0.0);
        $destLng = (float) ($destObj['lng'] ?? $destObj['longitude'] ?? $this->destination_longitude ?: 0.0);

        $isHeadingToHospital = in_array($status, [
            'patient_picked_up',
            'patient_onboard',
            'traveling_to_hospital',
            'in_transit_to_hospital',
        ], true);

        $targetLat = $isHeadingToHospital && $destLat !== 0.0 ? $destLat : $pickupLat;
        $targetLng = $isHeadingToHospital && $destLng !== 0.0 ? $destLng : $pickupLng;

        $driver = $this->relationLoaded('driver') ? $this->driver : $this->driver()->first();
        if ($driver && (float) $driver->lat !== 0.0 && (float) $driver->lng !== 0.0 && $targetLat !== 0.0 && $targetLng !== 0.0) {
            $distKm = PhoneHelper::calculateDrivingDistanceKm((float) $driver->lat, (float) $driver->lng, $targetLat, $targetLng);
            return [
                'distance_km' => round($distKm, 2),
                'distance_meters' => round($distKm * 1000.0, 1),
                'eta_minutes' => PhoneHelper::estimateEtaMinutes($distKm),
            ];
        }

        $storedKm = (float) ($this->distance_km ?: 0.0);
        if ($storedKm <= 0.0 && $pickupLat !== 0.0 && $pickupLng !== 0.0 && $destLat !== 0.0 && $destLng !== 0.0) {
            $storedKm = PhoneHelper::calculateDrivingDistanceKm($pickupLat, $pickupLng, $destLat, $destLng);
        }

        return [
            'distance_km' => round($storedKm, 2),
            'distance_meters' => round(((float) ($this->distance_meters ?: ($storedKm * 1000.0))), 1),
            'eta_minutes' => (int) ($this->eta_minutes ?: PhoneHelper::estimateEtaMinutes($storedKm)),
        ];
    }

    public function toUserBookingJson(): array
    {
        $driverModel = $this->relationLoaded('driver') ? $this->driver : $this->driver()->first();
        $driverPayload = $driverModel ? $driverModel->toAssignedDriverPayload() : null;
        $metrics = $this->computePhaseMetrics();

        return [
            'id' => (int) $this->id,
            'booking_id' => (int) $this->id,
            'booking_reference' => $this->booking_reference,
            'reference_number' => $this->reference_number,
            'status' => $this->status,
            'pickup_lat' => (float) $this->pickup_lat,
            'pickup_lng' => (float) $this->pickup_lng,
            'pickup_latitude' => (float) $this->pickup_lat,
            'pickup_longitude' => (float) $this->pickup_lng,
            'pickup_address' => $this->pickup_address,
            'pickup_landmark' => $this->pickup_landmark ?? '',
            'landmark' => $this->pickup_landmark ?? '',
            'callback_phone' => $this->callback_phone,
            'patient_phone' => $this->callback_phone,
            'patient_name' => $this->patient_name ?? '',
            'emergency_category' => $this->emergency_category,
            'notes' => $this->notes ?? '',
            'essential_instructions' => $this->essential_instructions ?? '',
            'destination_hospital' => $this->destination_hospital,
            'destination_address' => $this->destination_address,
            'destination_latitude' => (float) $this->destination_latitude,
            'destination_longitude' => (float) $this->destination_longitude,
            'eta_minutes' => $metrics['eta_minutes'],
            'distance_km' => $metrics['distance_km'],
            'distance_meters' => $metrics['distance_meters'],
            'cancel_reason' => $this->cancel_reason,
            'handover_notes' => $this->handover_notes,
            'accepted_at' => $this->accepted_at?->toIso8601String(),
            'arrived_pickup_at' => $this->arrived_pickup_at?->toIso8601String(),
            'patient_picked_up_at' => $this->patient_picked_up_at?->toIso8601String(),
            'patient_onboard_at' => $this->patient_picked_up_at?->toIso8601String(),
            'completed_at' => $this->completed_at?->toIso8601String(),
            'created_at' => ($this->created_at ?? now())->toIso8601String(),
            'status_time' => ($this->completed_at ?: ($this->patient_picked_up_at ?: ($this->arrived_pickup_at ?: ($this->accepted_at ?: ($this->created_at ?? now())))))->toIso8601String(),
            'driver' => $driverPayload,
        ];
    }

    public function toTripModelJson(): array
    {
        $destObj = is_array($this->destination_hospital) ? $this->destination_hospital : [];
        $destName = $destObj['name'] ?? ($this->destination_address ?: 'Emergency Hospital');
        $destAddress = $destObj['address'] ?? ($this->destination_address ?: 'Casualty & Emergency Ward');
        $pickupLat = (float) ($this->pickup_lat ?: 0.0);
        $pickupLng = (float) ($this->pickup_lng ?: 0.0);
        $destLat = (float) ($destObj['lat'] ?? $destObj['latitude'] ?? $this->destination_latitude ?: $pickupLat);
        $destLng = (float) ($destObj['lng'] ?? $destObj['longitude'] ?? $this->destination_longitude ?: $pickupLng);
        $metrics = $this->computePhaseMetrics();
        $driverModel = $this->relationLoaded('driver') ? $this->driver : $this->driver()->first();

        return [
            'id' => (int) $this->id,
            'booking_reference' => $this->booking_reference ?: '#LR-'.$this->id,
            'patient_name' => $this->patient_name ?? '',
            'contact_number' => $this->callback_phone ?? '',
            'patient_phone' => $this->callback_phone ?? '',
            'driver_id' => $driverModel ? (int) $driverModel->id : null,
            'driver_name' => $driverModel ? ($driverModel->name ?? '') : '',
            'driver_phone' => $driverModel ? ($driverModel->phone ?? '') : '',
            'ambulance_plate' => $driverModel ? ($driverModel->vehicle_plate ?: ($driverModel->vehicle_number ?: '')) : '',
            'vehicle_model' => $driverModel ? ($driverModel->vehicle_model ?: '') : '',
            'vehicle_type' => $driverModel ? Driver::normalizeVehicleType($driverModel->vehicle_type) : '',
            'pickup_address' => $this->pickup_address,
            'pickup_landmark' => $this->pickup_landmark ?? '',
            'pickup_latitude' => $pickupLat,
            'pickup_longitude' => $pickupLng,
            'destination_hospital' => $destName,
            'destination_address' => $destAddress,
            'destination_latitude' => $destLat,
            'destination_longitude' => $destLng,
            'emergency_notes' => $this->notes ?: 'Priority ambulance transit required.',
            'special_access_instructions' => 'Emergency Ambulance Bay entrance.',
            'emergency_category' => $this->emergency_category ?: 'Critical',
            'status' => $this->status ?: 'accepted',
            'distance_remaining_meters' => $metrics['distance_meters'],
            'distance_km' => $metrics['distance_km'],
            'eta_remaining' => $metrics['eta_minutes'] <= 0 ? 'Arrived' : $metrics['eta_minutes'].' mins',
            'created_at' => ($this->created_at ?? now())->toIso8601String(),
            'accepted_at' => ($this->accepted_at ?? now())->toIso8601String(),
            'arrived_pickup_at' => $this->arrived_pickup_at?->toIso8601String(),
            'patient_picked_up_at' => $this->patient_picked_up_at?->toIso8601String(),
            'completed_at' => $this->completed_at?->toIso8601String(),
            'handover_notes' => $this->handover_notes,
        ];
    }

    public function toBookingRequestJson(): array
    {
        $destObj = is_array($this->destination_hospital) ? $this->destination_hospital : [];
        $destName = $destObj['name'] ?? 'Emergency Hospital';
        $destAddress = $destObj['address'] ?? ($this->destination_address ?: 'Casualty & Emergency Ward');
        $pickupLat = (float) ($this->pickup_lat ?: 0.0);
        $pickupLng = (float) ($this->pickup_lng ?: 0.0);
        $destLat = (float) ($destObj['lat'] ?? $destObj['latitude'] ?? $this->destination_latitude ?: $pickupLat);
        $destLng = (float) ($destObj['lng'] ?? $destObj['longitude'] ?? $this->destination_longitude ?: $pickupLng);
        $metrics = $this->computePhaseMetrics();

        return [
            'id' => (int) $this->id,
            'booking_reference' => $this->booking_reference ?: '#LR-'.$this->id,
            'patient_name' => $this->patient_name ?? '',
            'patient_phone' => $this->callback_phone ?? '',
            'pickup_address' => $this->pickup_address,
            'pickup_landmark' => $this->pickup_landmark ?? '',
            'pickup_latitude' => $pickupLat,
            'pickup_longitude' => $pickupLng,
            'destination_hospital' => $destName,
            'destination_address' => $destAddress,
            'destination_latitude' => $destLat,
            'destination_longitude' => $destLng,
            'emergency_category' => $this->emergency_category ?: 'Critical',
            'essential_instructions' => $this->notes ?: ($this->essential_instructions ?: 'Urgent medical assistance requested.'),
            'distance_meters' => $metrics['distance_meters'],
            'estimated_eta_minutes' => $metrics['eta_minutes'],
            'countdown_seconds' => 120,
            'created_at' => ($this->created_at ?? now())->toIso8601String(),
        ];
    }

    public function toCompletedHistoryJson(): array
    {
        $destObj = is_array($this->destination_hospital) ? $this->destination_hospital : [];
        $pickupLat = (float) ($this->pickup_lat ?: 0.0);
        $pickupLng = (float) ($this->pickup_lng ?: 0.0);
        $destLat = (float) ($destObj['lat'] ?? $destObj['latitude'] ?? $this->destination_latitude ?: 0.0);
        $destLng = (float) ($destObj['lng'] ?? $destObj['longitude'] ?? $this->destination_longitude ?: 0.0);
        $computedKm = ($pickupLat !== 0.0 && $pickupLng !== 0.0 && $destLat !== 0.0 && $destLng !== 0.0)
            ? PhoneHelper::calculateDrivingDistanceKm($pickupLat, $pickupLng, $destLat, $destLng)
            : 0.0;
        $tripKm = (float) ($this->distance_km ?: $computedKm);
        if ($tripKm <= 0.0) {
            $tripKm = 6.4;
        }

        $accepted = $this->accepted_at ? \Carbon\Carbon::parse($this->accepted_at) : ($this->created_at ? \Carbon\Carbon::parse($this->created_at) : null);
        $completed = $this->completed_at ? \Carbon\Carbon::parse($this->completed_at) : ($this->updated_at ? \Carbon\Carbon::parse($this->updated_at) : null);
        $diffMinutes = ($accepted && $completed) ? (int) $completed->diffInMinutes($accepted) : 0;
        $duration = ($diffMinutes >= 5 && $diffMinutes <= 120)
            ? $diffMinutes
            : max(10, (int) round($tripKm * 2.2));

        return [
            'id' => (int) $this->id,
            'booking_reference' => $this->booking_reference ?: ('BK-'.$this->id),
            'patient_name' => $this->patient_name ?? 'Emergency Requester',
            'patient_phone' => $this->callback_phone ?? '',
            'pickup_address' => $this->pickup_address ?: 'Pickup Location',
            'destination_hospital' => $destObj['name'] ?? ($this->destination_address ?: 'Regional Emergency & Trauma Hospital'),
            'emergency_category' => $this->emergency_category ?: 'Critical Emergency',
            'distance_km' => round($tripKm, 1),
            'duration_minutes' => $duration,
            'earnings' => (float) ($this->earnings ?: round(250 + ($tripKm * 28))),
            'started_at' => ($accepted ?? now()->subMinutes($duration))->toIso8601String(),
            'accepted_at' => ($accepted ?? now()->subMinutes($duration))->toIso8601String(),
            'created_at' => ($this->created_at ?? now()->subMinutes($duration))->toIso8601String(),
            'completed_at' => ($completed ?? now())->toIso8601String(),
            'handover_notes' => $this->handover_notes ?: 'Handover successfully signed & transferred to Casualty ER triage.',
            'is_paid' => true,
            'payment_status' => 'Paid',
            'payment_method' => '108 Emergency / Free Govt Service',
            'ambulance_plate' => $this->driver?->vehicle_plate ?: ($this->driver?->vehicle_number ?: 'TN38-EMG-108'),
            'status' => 'Completed & Handover Signed',
        ];
    }
}
