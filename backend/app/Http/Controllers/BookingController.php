<?php

namespace App\Http\Controllers;

use App\Models\Booking;
use App\Models\Driver;
use App\Models\DriverNotification;
use App\Services\PhoneHelper;
use App\Services\WebSocketBroadcaster;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BookingController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $data = $request->all();

        do {
            $numericId = random_int(10000, 99999);
        } while (Booking::where('id', $numericId)->exists());

        $bookingId = 'BK-'.$numericId;
        $referenceNumber = '#LR-'.$numericId;

        $pickupLat = (float) ($data['pickup_lat'] ?? $data['pickup_latitude'] ?? 12.9716) ?: 12.9716;
        $pickupLng = (float) ($data['pickup_lng'] ?? $data['pickup_longitude'] ?? 77.5946) ?: 77.5946;

        $destInput = $data['destination_hospital'] ?? null;
        $isDestObj = is_array($destInput);

        $destHospitalName = $isDestObj
            ? (string) ($destInput['name'] ?? 'Emergency Trauma Center')
            : (string) ($destInput ?: 'Emergency Trauma Center');
        $destAddress = $isDestObj
            ? (string) ($destInput['address'] ?? 'Casualty & Emergency Bay')
            : 'Casualty & Emergency Bay';

        $destLat = $isDestObj
            ? ((float) ($destInput['lat'] ?? $destInput['latitude'] ?? 0) ?: ($pickupLat + 0.015))
            : ((float) ($data['destination_latitude'] ?? $data['destination_lat'] ?? 0) ?: ($pickupLat + 0.015));
        $destLng = $isDestObj
            ? ((float) ($destInput['lng'] ?? $destInput['longitude'] ?? 0) ?: ($pickupLng + 0.012))
            : ((float) ($data['destination_longitude'] ?? $data['destination_lng'] ?? 0) ?: ($pickupLng + 0.012));

        $patientPhone = trim((string) ($data['callback_phone'] ?? $data['patient_phone'] ?? ''));
        $patientName = trim((string) ($data['patient_name'] ?? ''));
        $emergencyCategory = (string) ($data['emergency_category'] ?? $data['emergency_type'] ?? 'General Emergency');
        $notes = (string) ($data['notes'] ?? $data['medical_notes'] ?? '');
        $landmark = (string) ($data['landmark'] ?? $data['pickup_landmark'] ?? '');

        $hospitalDistanceKm = PhoneHelper::calculateDrivingDistanceKm($pickupLat, $pickupLng, $destLat, $destLng);
        $hospitalEtaMin = PhoneHelper::estimateEtaMinutes($hospitalDistanceKm);

        $hospitalObj = $isDestObj ? [
            'id' => $destInput['id'] ?? 'hosp-selected',
            'name' => $destHospitalName,
            'address' => $destAddress,
            'lat' => $destLat,
            'lng' => $destLng,
            'distance_km' => round($hospitalDistanceKm, 1),
            'estimated_drive_time' => $hospitalEtaMin.' min',
        ] : [
            'id' => 'hosp-default',
            'name' => $destHospitalName,
            'address' => $destAddress,
            'lat' => $destLat,
            'lng' => $destLng,
            'distance_km' => round($hospitalDistanceKm, 1),
            'estimated_drive_time' => $hospitalEtaMin.' min',
        ];

        $onlineDrivers = Driver::where('is_online', true)
            ->where('lat', '!=', 0)
            ->where('lng', '!=', 0)
            ->get();
        $nearbyChannels = [];
        $initialKm = $hospitalDistanceKm;

        if ($onlineDrivers->isNotEmpty()) {
            $sorted = $onlineDrivers->sortBy(static fn (Driver $d) => PhoneHelper::calculateDrivingDistanceKm(
                $pickupLat,
                $pickupLng,
                (float) $d->lat,
                (float) $d->lng
            ))->values();

            /** @var Driver $nearest */
            $nearest = $sorted->first();
            $initialKm = PhoneHelper::calculateDrivingDistanceKm(
                $pickupLat,
                $pickupLng,
                (float) $nearest->lat,
                (float) $nearest->lng
            );

            $nearbyChannels = $sorted->filter(static fn (Driver $d) => PhoneHelper::calculateDrivingDistanceKm(
                $pickupLat,
                $pickupLng,
                (float) $d->lat,
                (float) $d->lng
            ) <= 30.0)->map(static fn (Driver $d) => 'private-driver.'.$d->id)->values()->all();

            if (empty($nearbyChannels)) {
                $nearbyChannels = ['private-driver.'.$nearest->id];
            }
        }

        $initialMeters = round($initialKm * 1000.0, 1);
        $initialEta = PhoneHelper::estimateEtaMinutes($initialKm);

        $booking = Booking::create([
            'id' => $numericId,
            'booking_reference' => $bookingId,
            'reference_number' => $referenceNumber,
            'status' => 'finding_ambulance',
            'pickup_lat' => $pickupLat,
            'pickup_lng' => $pickupLng,
            'pickup_address' => (string) ($data['pickup_address'] ?? 'Current GPS Position'),
            'pickup_landmark' => $landmark,
            'callback_phone' => $patientPhone,
            'patient_name' => $patientName,
            'emergency_category' => $emergencyCategory,
            'notes' => $notes,
            'essential_instructions' => $notes !== '' ? $notes : "Emergency {$emergencyCategory}. Priority ambulance needed immediately.",
            'destination_hospital' => $hospitalObj,
            'destination_address' => $destAddress,
            'destination_latitude' => $destLat,
            'destination_longitude' => $destLng,
            'eta_minutes' => $initialEta,
            'distance_km' => round($initialKm, 2),
            'distance_meters' => $initialMeters,
        ]);

        $requestPayload = $booking->toBookingRequestJson();

        $contactLabel = $patientName !== '' ? $patientName : ($patientPhone !== '' ? $patientPhone : $bookingId);
        DriverNotification::create([
            'booking_id' => $numericId,
            'booking_reference' => $bookingId,
            'title' => "🚨 Emergency Dispatch: {$contactLabel} ({$bookingId})",
            'message' => "Emergency {$emergencyCategory} at {$booking->pickup_address}. Phone: {$patientPhone}. Destination: {$destHospitalName}. Notes: ".($notes !== '' ? $notes : 'Immediate assistance requested.'),
            'type' => 'new_booking',
            'request_payload' => $requestPayload,
            'is_read' => false,
        ]);

        $broadcastChannels = array_values(array_unique(array_merge($nearbyChannels, ['emergency-broadcasts'])));
        WebSocketBroadcaster::broadcast($broadcastChannels, 'BookingRequested', $requestPayload);
        WebSocketBroadcaster::broadcast($broadcastChannels, 'new-booking-request', $requestPayload);

        return response()->json([
            'status' => 'success',
            'booking' => $booking->toUserBookingJson(),
        ], 201);
    }

    public function history(): JsonResponse
    {
        $bookings = Booking::with('driver')
            ->orderByDesc('created_at')
            ->get()
            ->map(static fn (Booking $b) => $b->toUserBookingJson())
            ->values();

        return response()->json([
            'status' => 'success',
            'bookings' => $bookings,
        ]);
    }

    public function show(string $id): JsonResponse
    {
        $booking = $this->findBookingByKey($id);

        if (!$booking) {
            return response()->json([
                'status' => 'error',
                'message' => 'Booking not found.',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'booking' => $booking->toUserBookingJson(),
        ]);
    }

    public function cancel(Request $request, string $id): JsonResponse
    {
        $reason = (string) ($request->input('reason') ?: 'Cancelled by user');
        $booking = $this->findBookingByKey($id);

        if ($booking) {
            $driverId = $booking->driver_id;

            $booking->update([
                'status' => 'cancelled',
                'cancel_reason' => $reason,
            ]);

            if ($driverId) {
                Driver::where('id', $driverId)->update([
                    'is_online' => true,
                ]);
            }

            $cancelPayload = [
                'booking_id' => $booking->id,
                'booking_reference' => $booking->booking_reference,
                'status' => 'cancelled',
                'reason' => $reason,
                'driver_id' => $driverId,
                'message' => 'Emergency trip ' . $booking->booking_reference . ' was cancelled by requester: ' . $reason,
                'timestamp' => now()->toIso8601String(),
            ];

            $channels = [
                'private-booking.'.$booking->id,
                'private-booking.'.$booking->booking_reference,
                'private-bookings.'.$booking->id,
                'private-bookings.'.$booking->booking_reference,
                'emergency-broadcasts',
            ];

            if ($driverId) {
                $channels[] = 'private-driver.'.$driverId;
            }

            WebSocketBroadcaster::broadcast($channels, 'BookingCancelled', $cancelPayload);
            WebSocketBroadcaster::broadcast($channels, 'TripCancelled', $cancelPayload);
            WebSocketBroadcaster::broadcast($channels, 'TripStatusUpdated', $cancelPayload);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Booking cancelled successfully.',
        ]);
    }

    public static function findBookingByKey(string $key): ?Booking
    {
        $query = Booking::with('driver');
        if (ctype_digit($key)) {
            return $query->where('id', (int) $key)->first();
        }

        return $query->where('booking_reference', $key)
            ->orWhere('reference_number', $key)
            ->orWhere('reference_number', '#LR-'.$key)
            ->first();
    }
}
