<?php

use App\Http\Controllers\AdminWebController;
use Illuminate\Support\Facades\Route;

// Root displays Admin Command Portal / Login (HTTP 200)
Route::get('/', [AdminWebController::class, 'showLogin'])->name('home');

// Admin Command Center Web Routes (Laravel + PHP + MySQL)
Route::prefix('admin')->name('admin.')->group(function () {
    // Authentication
    Route::get('/login', [AdminWebController::class, 'showLogin'])->name('login');
    Route::post('/login', [AdminWebController::class, 'login'])->name('login.submit');
    Route::post('/logout', [AdminWebController::class, 'logout'])->name('logout');

    // Central Command Pages
    Route::get('/', [AdminWebController::class, 'dashboard'])->name('dashboard');
    Route::get('/dashboard', [AdminWebController::class, 'dashboard']);
    Route::get('/live-map', [AdminWebController::class, 'liveMap'])->name('live-map');
    Route::get('/bookings', [AdminWebController::class, 'bookings'])->name('bookings');
    Route::post('/bookings/{id}/assign', [AdminWebController::class, 'assignDriver'])->name('bookings.assign');
    Route::post('/bookings/{id}/cancel', [AdminWebController::class, 'cancelBooking'])->name('bookings.cancel');
    Route::get('/drivers', [AdminWebController::class, 'drivers'])->name('drivers');
    Route::post('/drivers/{id}/verify', [AdminWebController::class, 'verifyDriver'])->name('drivers.verify');
    Route::post('/drivers/{id}/toggle-suspension', [AdminWebController::class, 'toggleSuspension'])->name('drivers.toggle-suspension');
    Route::get('/ambulances', [AdminWebController::class, 'ambulances'])->name('ambulances');
    Route::get('/hospitals', [AdminWebController::class, 'hospitals'])->name('hospitals');
    Route::get('/users', [AdminWebController::class, 'users'])->name('users');
});
