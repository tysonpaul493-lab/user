<?php

use App\Http\Controllers\AdminApiController;
use App\Http\Controllers\BookingController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\DriverAuthController;
use App\Http\Controllers\DriverOperationsController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\HospitalController;
use App\Http\Controllers\UserAuthController;
use Illuminate\Support\Facades\Route;

// Health & Service Info
Route::get('/', [HealthController::class, 'index']);
Route::get('/api', [HealthController::class, 'index']);
Route::get('/api/v1', [HealthController::class, 'index']);

Route::get('/health', [HealthController::class, 'health']);
Route::get('/api/health', [HealthController::class, 'health']);
Route::get('/api/v1/health', [HealthController::class, 'health']);

// Broadcasting Auth
Route::post('/broadcasting/auth', [HealthController::class, 'broadcastingAuth']);
Route::post('/api/v1/broadcasting/auth', [HealthController::class, 'broadcastingAuth']);

// User App & Shared Routes (/api/*, /api/v1/*, and root /*)
foreach (['/api', '/api/v1', ''] as $prefix) {
    Route::prefix($prefix)->group(function () {
        Route::post('/auth/otp/send', [UserAuthController::class, 'sendOtp']);
        Route::post('/auth/otp/verify', [UserAuthController::class, 'verifyOtp']);
        Route::match(['GET', 'POST'], '/auth/lookup-user', [UserAuthController::class, 'lookupUser']);
        Route::get('/user/profile', [UserAuthController::class, 'getProfile']);
        Route::put('/user/profile', [UserAuthController::class, 'updateProfile']);

        Route::get('/hospitals/nearby', [HospitalController::class, 'nearby']);

        Route::post('/bookings', [BookingController::class, 'store']);
        Route::get('/bookings/history', [BookingController::class, 'history']);
        Route::get('/bookings/{id}', [BookingController::class, 'show']);
        Route::post('/bookings/{id}/cancel', [BookingController::class, 'cancel']);

        Route::get('/bookings/{id}/chat', [ChatController::class, 'index']);
        Route::post('/bookings/{id}/chat', [ChatController::class, 'store']);

        // Admin Command Center Routes
        Route::post('/auth/login', [AdminApiController::class, 'login']);
        Route::post('/auth/logout', [AdminApiController::class, 'logout']);
        Route::get('/dashboard/stats', [AdminApiController::class, 'dashboardStats']);
        Route::get('/tracking/live', [AdminApiController::class, 'liveTracking']);
        Route::get('/ambulances', [AdminApiController::class, 'ambulances']);
        Route::get('/drivers', [AdminApiController::class, 'drivers']);
        Route::post('/drivers/{id}/verify', [AdminApiController::class, 'verifyDriver']);
        Route::post('/drivers/{id}/toggle-suspension', [AdminApiController::class, 'toggleSuspension']);
        Route::get('/bookings', [AdminApiController::class, 'bookings']);
        Route::post('/bookings/{id}/assign-driver', [AdminApiController::class, 'assignDriver']);
        Route::post('/bookings/{id}/cancel-admin', [AdminApiController::class, 'cancelBooking']);
        Route::get('/hospitals', [AdminApiController::class, 'hospitals']);
        Route::get('/users', [AdminApiController::class, 'users']);
    });
}

// Driver App Routes (/api/v1/driver/* and /api/driver/*)
foreach (['/api/v1/driver', '/api/driver'] as $driverPrefix) {
    Route::prefix($driverPrefix)->group(function () {
        Route::post('/auth/check-phone', [DriverAuthController::class, 'checkPhone']);
        Route::get('/auth/sms-status', [DriverAuthController::class, 'smsStatus']);
        Route::post('/auth/send-otp', [DriverAuthController::class, 'sendOtp']);
        Route::post('/auth/verify-otp', [DriverAuthController::class, 'verifyOtp']);
        Route::post('/auth/login', [DriverAuthController::class, 'login']);
        Route::post('/auth/forgot-password', [DriverAuthController::class, 'forgotPassword']);
        Route::post('/auth/reset-password', [DriverAuthController::class, 'resetPassword']);
        Route::post('/auth/register', [DriverAuthController::class, 'register']);
        Route::post('/auth/logout', [DriverAuthController::class, 'logout']);

        Route::post('/documents/upload', [DriverAuthController::class, 'uploadDocument']);
        Route::get('/profile', [DriverAuthController::class, 'profile']);
        Route::put('/profile', [DriverAuthController::class, 'updateProfile']);
        Route::get('/verification-status', [DriverAuthController::class, 'verificationStatus']);

        Route::get('/dashboard/summary', [DriverOperationsController::class, 'dashboardSummary']);
        Route::post('/status/toggle', [DriverOperationsController::class, 'toggleStatus']);

        Route::get('/requests/pending', [DriverOperationsController::class, 'pendingRequests']);
        Route::post('/requests/{id}/accept', [DriverOperationsController::class, 'acceptBooking']);
        Route::post('/requests/{id}/decline', [DriverOperationsController::class, 'declineBooking']);

        Route::get('/support/info', [DriverOperationsController::class, 'supportInfo']);

        Route::get('/trips/active', [DriverOperationsController::class, 'activeTrip']);
        Route::get('/trips/history', [DriverOperationsController::class, 'tripHistory']);
        Route::get('/trips/{id}', [DriverOperationsController::class, 'showTrip']);
        Route::patch('/trips/{id}/status', [DriverOperationsController::class, 'updateTripStatus']);

        Route::post('/location/telemetry', [DriverOperationsController::class, 'telemetry']);

        Route::get('/notifications', [DriverOperationsController::class, 'notifications']);
        Route::post('/notifications/{id}/read', [DriverOperationsController::class, 'markNotificationRead']);
    });
}
