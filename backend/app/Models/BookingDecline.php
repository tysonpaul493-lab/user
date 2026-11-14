<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BookingDecline extends Model
{
    protected $fillable = [
        'booking_id',
        'driver_id',
    ];
}
