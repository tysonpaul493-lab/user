<?php

namespace Tests\Feature;

use App\Models\Driver;
use App\Models\OtpCode;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class LifeRouteApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_health_and_unauthenticated_driver_endpoints(): void
    {
        $this->getJson('/health')->assertOk()->assertJson(['status' => 'ok']);
        $this->getJson('/api/v1/health')->assertOk()->assertJson(['status' => 'ok']);

        // Database seed should contain no hardcoded personal default names
        $this->assertDatabaseMissing('drivers', ['name' => 'Muruganandam']);
        $this->assertDatabaseMissing('users', ['name' => 'LifeRoute User']);

        // Protected driver profile requires a valid bearer token
        $this->getJson('/api/v1/driver/profile')->assertStatus(401);
    }

    public function test_driver_registration_and_strict_otp_verification(): void
    {
        $reg = $this->postJson('/api/v1/driver/auth/register', [
            'name' => 'Karthik Driver',
            'phone' => '9123456789',
            'email' => 'karthik@liferoute.in',
            'license_number' => 'TN-02-2025-108',
            'ambulance' => [
                'registration_number' => 'TN-37-AB-9108',
                'vehicle_type' => 'als',
                'make_model' => 'Tata Winger ALS',
                'year' => 2025,
            ],
        ])->assertOk();

        $reg->assertJsonPath('status', 'success');
        $reg->assertJsonPath('driver.name', 'Karthik Driver');
        $reg->assertJsonPath('driver.assigned_vehicle.registration_number', 'TN-37-AB-9108');
        $token = $reg->json('token');

        $this->withToken($token)
            ->getJson('/api/v1/driver/profile')
            ->assertOk()
            ->assertJsonPath('driver.name', 'Karthik Driver');

        $this->postJson('/api/v1/driver/auth/check-phone', ['phone' => '9123456789'])
            ->assertOk()
            ->assertJson(['registered' => true, 'driver_name' => 'Karthik Driver']);

        OtpCode::create([
            'scope' => 'driver',
            'phone_key' => '9123456789',
            'e164_phone' => '+919123456789',
            'otp_code' => '739201',
            'expires_at' => now()->addMinutes(5),
        ]);

        // Unregistered phone OTP cannot hijack any default driver
        OtpCode::create([
            'scope' => 'driver',
            'phone_key' => '9888877777',
            'e164_phone' => '+919888877777',
            'otp_code' => '654321',
            'expires_at' => now()->addMinutes(5),
        ]);
        $this->postJson('/api/v1/driver/auth/verify-otp', [
            'phone' => '+919888877777',
            'otp' => '654321',
        ])->assertStatus(404)->assertJsonPath('registration_required', true);

        // Static bypass must fail
        $this->postJson('/api/v1/driver/auth/verify-otp', [
            'phone' => '+919123456789',
            'otp' => '123456',
        ])->assertStatus(401);

        // Exact OTP succeeds
        $this->postJson('/api/v1/driver/auth/verify-otp', [
            'phone' => '+919123456789',
            'otp' => '739201',
        ])->assertOk()->assertJsonPath('status', 'success');
    }

    public function test_full_booking_driver_dispatch_chat_and_handover_lifecycle_with_dynamic_km(): void
    {
        $reg = $this->postJson('/api/v1/driver/auth/register', [
            'name' => 'Raghavender Rao',
            'phone' => '9000011111',
            'ambulance' => [
                'registration_number' => 'KA-01-EM-5001',
                'vehicle_type' => 'als',
            ],
        ])->assertOk();
        $driverToken = $reg->json('token');

        $userOtp = $this->postJson('/api/auth/otp/send', ['phone' => '8428304510'])->assertOk();
        $code = $userOtp->json('dev_otp');

        $this->postJson('/api/auth/otp/verify', ['phone' => '8428304510', 'otp' => $code])
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('user.name', '');

        $this->putJson('/api/user/profile', ['phone' => '8428304510', 'name' => 'Anil Kumar'])
            ->assertOk()
            ->assertJsonPath('user.name', 'Anil Kumar');

        $this->getJson('/api/hospitals/nearby?lat=12.9784&lng=77.6408')
            ->assertOk()
            ->assertJsonPath('status', 'success');

        $created = $this->postJson('/api/bookings', [
            'patient_name' => 'Anil Kumar',
            'patient_phone' => '+91 98765 12345',
            'pickup_address' => '100 Feet Rd, Indiranagar',
            'pickup_lat' => 12.9784,
            'pickup_lng' => 77.6408,
            'emergency_category' => 'Cardiac Arrest',
            'destination_hospital' => [
                'name' => 'Manipal Hospital ICU',
                'lat' => 12.9592,
                'lng' => 77.6534,
            ],
        ])->assertCreated();

        $bookingId = $created->json('booking.id');
        $this->assertNotNull($bookingId);
        $this->assertGreaterThan(0, (float) $created->json('booking.distance_km'));

        $this->withToken($driverToken)
            ->getJson('/api/v1/driver/requests/pending')
            ->assertOk()
            ->assertJsonCount(1, 'requests');

        $this->withToken($driverToken)
            ->postJson("/api/v1/driver/requests/{$bookingId}/accept")
            ->assertOk()
            ->assertJsonPath('trip.id', $bookingId);

        // Second claim returns 409 conflict
        $this->withToken($driverToken)
            ->postJson("/api/v1/driver/requests/{$bookingId}/accept")
            ->assertStatus(409);

        // Upload compliance document
        $this->withToken($driverToken)
            ->post('/api/v1/driver/documents/upload', [
                'document_type' => 'driving_license_front',
                'file' => UploadedFile::fake()->create('license.jpg', 50, 'image/jpeg'),
            ])->assertOk()->assertJsonPath('documents_uploaded.driving_license_front', true);

        // Telemetry updates dynamic KM & ETA along driver -> pickup
        $telPickup = $this->withToken($driverToken)
            ->postJson('/api/v1/driver/location/telemetry', [
                'booking_reference' => "BK-{$bookingId}",
                'latitude' => 12.9750,
                'longitude' => 77.6350,
                'heading' => 95.5,
                'speed' => 48.2,
            ])->assertOk();
        $this->assertGreaterThan(0, (float) $telPickup->json('distance_km'));

        foreach (['en_route_to_pickup', 'arrived_at_pickup', 'patient_onboard', 'in_transit_to_hospital', 'arrived_at_hospital'] as $step) {
            $res = $this->withToken($driverToken)
                ->patchJson("/api/v1/driver/trips/{$bookingId}/status", [
                    'status' => $step,
                    'latitude' => 12.96,
                    'longitude' => 77.65,
                ])->assertOk();
            if ($step === 'arrived_at_pickup' || $step === 'arrived_at_hospital') {
                $this->assertSame(0.0, (float) $res->json('trip.distance_remaining_meters'));
            }
        }

        $this->postJson("/api/bookings/{$bookingId}/chat", [
            'message' => 'Arriving at Gate 2 now',
            'sender' => 'driver',
        ])->assertOk();

        $this->getJson("/api/bookings/{$bookingId}/chat")
            ->assertOk()
            ->assertJsonCount(1, 'messages');

        $this->withToken($driverToken)
            ->patchJson("/api/v1/driver/trips/{$bookingId}/status", [
                'status' => 'completed',
                'handover_notes' => 'Transferred to ICU Bay #3',
            ])->assertOk();

        $this->getJson('/api/bookings/history')->assertOk()->assertJsonCount(1, 'bookings');
        $this->withToken($driverToken)->getJson('/api/v1/driver/trips/history')->assertOk()->assertJsonCount(1, 'trips');
        $this->assertDatabaseHas('bookings', ['id' => $bookingId, 'status' => 'trip_completed']);
    }
}
