<?php

namespace Tests\Feature;

use App\Models\Booking;
use App\Models\Driver;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminWebTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    protected function authenticateAdmin(): array
    {
        return [
            'name' => 'Commander Sarah Jenkins',
            'email' => 'admin@ambulance.gov',
            'role' => 'super_admin',
            'role_name' => 'Super Administrator',
            'department' => 'Emergency Central Command',
            'login_time' => now()->format('d M Y, H:i:s'),
        ];
    }

    public function test_admin_login_screen_renders_successfully(): void
    {
        $response = $this->get('/admin/login');
        $response->assertStatus(200);
        $response->assertSee('LifeRoute Command Center');
        $response->assertSee('Command Identifier / Email');
    }

    public function test_admin_authentication_succeeds_with_valid_credentials(): void
    {
        $response = $this->post('/admin/login', [
            'email' => 'admin@ambulance.gov',
            'password' => 'AdminSecure2026!',
        ]);

        $response->assertRedirect(route('admin.dashboard'));
        $this->assertTrue(session()->has('admin_user'));
        $this->assertEquals('Commander Sarah Jenkins', session('admin_user.name'));
    }

    public function test_admin_authentication_fails_with_invalid_credentials(): void
    {
        $response = $this->post('/admin/login', [
            'email' => 'admin@ambulance.gov',
            'password' => 'WrongPassword123!',
        ]);

        $response->assertRedirect();
        $this->assertFalse(session()->has('admin_user'));
    }

    public function test_admin_dashboard_renders_with_real_mysql_metrics(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/dashboard');

        $response->assertStatus(200);
        $response->assertSee('Emergency Command Operations');
        $response->assertSee('Active Incidents');
        $response->assertSee('Available Responders');
        $response->assertSee('Verified Paramedics');
        $response->assertSee('Registered Citizens');
    }

    public function test_admin_live_map_renders_successfully(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/live-map');

        $response->assertStatus(200);
        $response->assertSee('Live Regional Fleet');
        $response->assertSee('live-command-map');
    }

    public function test_admin_bookings_page_renders_and_filters(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/bookings');

        $response->assertStatus(200);
        $response->assertSee('Emergency Trips');
        $response->assertSee('All Trips');
    }

    public function test_admin_can_cancel_booking(): void
    {
        $booking = Booking::create([
            'id' => 99991,
            'booking_reference' => '#BK-99991',
            'reference_number' => 'REF-99991',
            'status' => 'pending_driver_acceptance',
            'pickup_lat' => 11.0318,
            'pickup_lng' => 76.9437,
            'pickup_address' => 'Emergency Center',
        ]);

        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->post("/admin/bookings/{$booking->id}/cancel", [
                'reason' => 'Test administrative cancellation',
            ]);

        $response->assertRedirect();
        $booking->refresh();
        $this->assertEquals('cancelled', $booking->status);
    }

    public function test_admin_drivers_registry_and_toggle_suspension(): void
    {
        $driver = Driver::first();
        if (!$driver) {
            $driver = Driver::create([
                'name' => 'Paramedic John Doe',
                'phone' => '+919999999999',
                'phone_key' => '919999999999',
                'is_online' => true,
                'verification_status' => 'approved',
            ]);
        }

        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->post("/admin/drivers/{$driver->id}/toggle-suspension");

        $response->assertRedirect();
        $driver->refresh();
        $this->assertEquals('suspended', $driver->verification_status);
    }

    public function test_admin_ambulances_page_renders(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/ambulances');

        $response->assertStatus(200);
        $response->assertSee('Municipal Ambulance Fleet Registry');
    }

    public function test_admin_hospitals_page_renders(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/hospitals');

        $response->assertStatus(200);
        $response->assertSee('Hospital');
    }

    public function test_admin_users_page_renders(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->get('/admin/users');

        $response->assertStatus(200);
        $response->assertSee('Registered Citizens');
    }

    public function test_admin_logout_terminates_session(): void
    {
        $response = $this->withSession(['admin_user' => $this->authenticateAdmin()])
            ->post('/admin/logout');

        $response->assertRedirect('/admin/login');
        $this->assertFalse(session()->has('admin_user'));
    }
}
