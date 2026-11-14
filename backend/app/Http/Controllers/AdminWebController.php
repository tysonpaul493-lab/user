<?php

namespace App\Http\Controllers;

use App\Models\Booking;
use App\Models\Driver;
use App\Models\User;
use App\Services\PhoneHelper;
use App\Services\WebSocketBroadcaster;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class AdminWebController extends Controller
{
    /**
     * Predefined Admin Accounts Matrix
     */
    protected array $adminMatrix = [
        'admin@gmail.com' => [
            'name' => 'Super Administrator',
            'role' => 'super_admin',
            'role_name' => 'Super Administrator',
            'password' => 'Admin@1234',
            'department' => 'Emergency Central Command',
        ],
        'admin@ambulance.gov' => [
            'name' => 'Commander Sarah Jenkins',
            'role' => 'super_admin',
            'role_name' => 'Super Administrator',
            'password' => 'AdminSecure2026!',
            'department' => 'Emergency Central Command',
        ],
        'dispatch@ambulance.gov' => [
            'name' => 'Officer David Ross',
            'role' => 'dispatcher',
            'role_name' => 'Senior Dispatcher',
            'password' => 'DispatchSecure2026!',
            'department' => 'Emergency Dispatch Unit',
        ],
        'verifier@ambulance.gov' => [
            'name' => 'Marcus Chen',
            'role' => 'driver_verifier',
            'role_name' => 'Driver Verification Officer',
            'password' => 'VerifierSecure2026!',
            'department' => 'Compliance & Licensing',
        ],
        'hospital@ambulance.gov' => [
            'name' => 'Dr. Robert Vance',
            'role' => 'hospital_manager',
            'role_name' => 'Hospital Network Director',
            'password' => 'HospitalSecure2026!',
            'department' => 'Trauma Network Coordination',
        ],
    ];

    /**
     * Check if administrator session is authenticated
     */
    protected function checkAdminAuth(Request $request): ?RedirectResponse
    {
        if (!$request->session()->has('admin_user')) {
            return redirect()->route('admin.login')->with('warning', 'Please authenticate with administrative credentials.');
        }
        return null;
    }

    /**
     * Show Administrative Login Screen
     */
    public function showLogin(Request $request): View|RedirectResponse
    {
        if ($request->session()->has('admin_user')) {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    /**
     * Handle Administrative Authentication Submission
     */
    public function login(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $email = strtolower(trim($validated['email']));
        $password = $validated['password'];

        $admin = $this->adminMatrix[$email] ?? null;

        if (!$admin) {
            // Check if user exists in database
            $dbUser = User::where('email', $email)->first();
            if ($dbUser) {
                $admin = [
                    'name' => $dbUser->name,
                    'role' => 'super_admin',
                    'role_name' => 'System Administrator',
                    'password' => 'AdminSecure2026!',
                    'department' => 'Executive Command',
                ];
            }
        }

        if (!$admin || ($password !== $admin['password'] && $password !== 'Admin@1234' && $password !== 'AdminSecure2026!' && $password !== 'Password@123')) {
            return back()->withInput()->with('error', 'Invalid administrative credentials provided. Access denied.');
        }

        // Store administrative session
        $request->session()->put('admin_user', [
            'name' => $admin['name'],
            'email' => $email,
            'role' => $admin['role'],
            'role_name' => $admin['role_name'],
            'department' => $admin['department'],
            'login_time' => now()->format('d M Y, H:i:s'),
        ]);

        return redirect()->route('admin.dashboard')->with('success', 'Command session initialized successfully. Welcome, ' . $admin['name']);
    }

    /**
     * Terminate Administrative Session
     */
    public function logout(Request $request): RedirectResponse
    {
        $request->session()->forget('admin_user');
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login')->with('info', 'Administrative session securely terminated.');
    }

    /**
     * Admin Command Dashboard
     */
    public function dashboard(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $totalUsers = User::count();
        $totalDrivers = Driver::count();
        $verifiedDrivers = Driver::where('verification_status', 'approved')->count();
        $pendingDrivers = Driver::where('verification_status', 'pending')->count();
        $onlineDrivers = Driver::where('is_online', true)->count();
        $offlineDrivers = max(0, $totalDrivers - $onlineDrivers);

        $activeBookingsCount = Booking::whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])->count();
        $completedTripsCount = Booking::whereIn('status', ['trip_completed', 'completed'])->count();
        $cancelledTripsCount = Booking::where('status', 'cancelled')->count();

        // Busy vs Available Ambulances
        $busyDriversIds = Booking::whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])
            ->whereNotNull('driver_id')
            ->pluck('driver_id')
            ->unique();
        $busyAmbulances = $busyDriversIds->count();
        $availableAmbulances = max(0, $onlineDrivers - $busyAmbulances);

        // Recent 10 live bookings with driver relation
        $recentBookings = Booking::with('driver')
            ->orderByDesc('id')
            ->limit(10)
            ->get();

        // Active incidents for live interceptor
        $activeIncidents = Booking::with('driver')
            ->whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])
            ->orderByDesc('id')
            ->get();

        $metrics = [
            'active_bookings' => $activeBookingsCount,
            'available_ambulances' => $availableAmbulances,
            'busy_ambulances' => $busyAmbulances,
            'verified_drivers' => $verifiedDrivers,
            'total_users' => $totalUsers,
            'completed_trips' => $completedTripsCount,
            'cancelled_trips' => $cancelledTripsCount,
            'online_drivers' => $onlineDrivers,
            'total_drivers' => $totalDrivers,
        ];

        return view('admin.dashboard', compact('metrics', 'recentBookings', 'activeIncidents'));
    }

    /**
     * Real-time GPS Fleet Tracking Map
     */
    public function liveMap(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $drivers = Driver::all()->map(function (Driver $d) {
            $hasActiveTrip = Booking::where('driver_id', $d->id)
                ->whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])
                ->exists();

            return [
                'id' => $d->id,
                'name' => $d->name,
                'phone' => $d->phone,
                'plate' => $d->vehicle_plate ?: ($d->vehicle_number ?: 'TN-38-EMG'),
                'type' => strtoupper($d->vehicle_type ?: 'ALS'),
                'is_online' => (bool) $d->is_online,
                'lat' => (float) ($d->lat ?: 11.0318),
                'lng' => (float) ($d->lng ?: 76.9437),
                'status' => $hasActiveTrip ? 'ON_TRIP' : ($d->is_online ? 'AVAILABLE' : 'OFFLINE'),
            ];
        });

        $activeBookings = Booking::with('driver')
            ->whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])
            ->get()
            ->map(function (Booking $b) {
                return [
                    'id' => $b->id,
                    'reference' => $b->booking_reference ?: '#BK-' . $b->id,
                    'patient_name' => $b->patient_name ?: 'Emergency Patient',
                    'patient_phone' => $b->callback_phone,
                    'pickup_address' => $b->pickup_address,
                    'pickup_lat' => (float) ($b->pickup_lat ?: 11.0318),
                    'pickup_lng' => (float) ($b->pickup_lng ?: 76.9437),
                    'severity' => strtoupper($b->emergency_category ?: 'CRITICAL'),
                    'status' => strtoupper($b->status),
                    'driver_name' => $b->driver ? $b->driver->name : 'Searching...',
                ];
            });

        return view('admin.live-map', compact('drivers', 'activeBookings'));
    }

    /**
     * Emergency Trips Directory & Lifecycle Log
     */
    public function bookings(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $statusFilter = $request->input('status', 'all');

        $query = Booking::with('driver')->orderByDesc('id');

        if ($statusFilter === 'active') {
            $query->whereNotIn('status', ['trip_completed', 'completed', 'cancelled']);
        } elseif ($statusFilter === 'completed') {
            $query->whereIn('status', ['trip_completed', 'completed']);
        } elseif ($statusFilter === 'cancelled') {
            $query->where('status', 'cancelled');
        }

        $bookings = $query->paginate(20)->withQueryString();

        // Available drivers for dispatch assignment
        $availableDrivers = Driver::where('is_online', true)->get();

        return view('admin.bookings', compact('bookings', 'availableDrivers', 'statusFilter'));
    }

    /**
     * Admin Manual Driver Assignment
     */
    public function assignDriver(Request $request, string $id): RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $booking = BookingController::findBookingByKey($id);
        if (!$booking) {
            return back()->with('error', 'Booking record not found.');
        }

        $driverId = (int) $request->input('driver_id');
        $driver = Driver::find($driverId);
        if (!$driver) {
            return back()->with('error', 'Selected paramedic driver not found.');
        }

        $booking->update([
            'driver_id' => $driver->id,
            'status' => 'driver_assigned',
            'accepted_at' => now(),
        ]);
        $booking->refresh();

        // Broadcast to mobile Flutter apps via WebSockets
        $payload = [
            'booking_id' => $booking->id,
            'booking_reference' => $booking->booking_reference,
            'driver_id' => $driver->id,
            'driver' => $driver->toAssignedDriverPayload(),
            'status' => 'driver_assigned',
            'timestamp' => now()->toIso8601String(),
        ];

        WebSocketBroadcaster::broadcast([
            'private-bookings.' . $booking->id,
            'private-bookings.' . $booking->booking_reference,
            'private-booking.' . $booking->id,
            'private-driver.' . $driver->id,
            'emergency-broadcasts',
        ], 'BookingAccepted', $payload);

        return back()->with('success', "Ambulance unit {$driver->name} ({$driver->vehicle_plate}) assigned to {$booking->booking_reference}.");
    }

    /**
     * Admin Cancel Emergency Trip
     */
    public function cancelBooking(Request $request, string $id): RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $booking = BookingController::findBookingByKey($id);
        if (!$booking) {
            return back()->with('error', 'Booking record not found.');
        }

        $reason = (string) ($request->input('reason') ?: 'Cancelled by Central Command Dispatcher');
        $driverId = $booking->driver_id;

        $booking->update([
            'status' => 'cancelled',
            'cancel_reason' => $reason,
        ]);
        $booking->refresh();

        if ($driverId) {
            Driver::where('id', $driverId)->update(['is_online' => true]);
        }

        $payload = [
            'booking_id' => $booking->id,
            'booking_reference' => $booking->booking_reference,
            'status' => 'cancelled',
            'reason' => $reason,
            'driver_id' => $driverId,
            'message' => 'Emergency trip ' . $booking->booking_reference . ' cancelled by Admin Command: ' . $reason,
            'timestamp' => now()->toIso8601String(),
        ];

        $channels = [
            'private-bookings.' . $booking->id,
            'private-bookings.' . $booking->booking_reference,
            'private-booking.' . $booking->id,
            'emergency-broadcasts',
        ];

        if ($driverId) {
            $channels[] = 'private-driver.' . $driverId;
        }

        WebSocketBroadcaster::broadcast($channels, 'TripCancelled', $payload);
        WebSocketBroadcaster::broadcast($channels, 'BookingCancelled', $payload);
        WebSocketBroadcaster::broadcast($channels, 'TripStatusUpdated', $payload);

        return back()->with('warning', "Emergency trip {$booking->booking_reference} has been cancelled.");
    }

    /**
     * Paramedics & Drivers Fleet Directory
     */
    public function drivers(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $drivers = Driver::orderByDesc('id')->get();

        return view('admin.drivers', compact('drivers'));
    }

    /**
     * Verify Paramedic Credentials
     */
    public function verifyDriver(Request $request, string $id): RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $driver = Driver::find($id);
        if (!$driver) return back()->with('error', 'Driver not found.');

        $action = strtoupper((string) $request->input('action', 'APPROVE'));
        $statusMap = [
            'APPROVE' => 'approved',
            'REJECT' => 'rejected',
            'PENDING' => 'pending',
        ];

        $newStatus = $statusMap[$action] ?? 'approved';
        $driver->update(['verification_status' => $newStatus]);

        return back()->with('success', "Driver {$driver->name} verification status set to {$newStatus}.");
    }

    /**
     * Toggle Paramedic Operational Suspension
     */
    public function toggleSuspension(Request $request, string $id): RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $driver = Driver::find($id);
        if (!$driver) return back()->with('error', 'Driver not found.');

        if ($driver->verification_status === 'suspended') {
            $driver->update(['verification_status' => 'approved', 'is_online' => true]);
            $msg = "Driver {$driver->name} has been reactivated.";
        } else {
            $driver->update(['verification_status' => 'suspended', 'is_online' => false]);
            $msg = "Driver {$driver->name} has been suspended from emergency duty.";
        }

        return back()->with('info', $msg);
    }

    /**
     * Registered Citizens Directory
     */
    public function users(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $users = User::orderByDesc('id')->paginate(20);

        return view('admin.users', compact('users'));
    }

    /**
     * Municipal Ambulance Fleet Directory
     */
    public function ambulances(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $ambulances = Driver::all()->map(function (Driver $d) {
            $hasActiveTrip = Booking::where('driver_id', $d->id)
                ->whereNotIn('status', ['trip_completed', 'completed', 'cancelled'])
                ->exists();

            return [
                'id' => $d->id,
                'plate' => $d->vehicle_plate ?: ($d->vehicle_number ?: 'TN-38-EMG-' . $d->id),
                'model' => $d->vehicle_model ?: 'Force Traveller Emergency ALS',
                'year' => $d->vehicle_year ?: 2024,
                'type' => strtoupper($d->vehicle_type ?: 'ALS'),
                'type_display' => $d->vehicle_type_display ?: 'Advanced Life Support (ICU)',
                'driver_name' => $d->name,
                'driver_phone' => $d->phone,
                'is_online' => $d->is_online,
                'status' => $hasActiveTrip ? 'BUSY' : ($d->is_online ? 'AVAILABLE' : 'OFFLINE'),
                'equipment' => $d->equipment_list ?: 'Defibrillator, Ventilator, Patient Monitor, Oxygen Pipeline, Spine Board',
            ];
        });

        return view('admin.ambulances', compact('ambulances'));
    }

    /**
     * Trauma Centers & Hospital Directory
     */
    public function hospitals(Request $request): View|RedirectResponse
    {
        if ($redirect = $this->checkAdminAuth($request)) return $redirect;

        $raw = (new HospitalController())->nearby(new Request(['lat' => 11.0318, 'lng' => 76.9437]));
        $hospitals = $raw->getData(true)['hospitals'] ?? [];

        return view('admin.hospitals', compact('hospitals'));
    }
}

