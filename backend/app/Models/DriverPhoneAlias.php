<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverPhoneAlias extends Model
{
    protected $fillable = [
        'phone_key',
        'driver_id',
    ];
}
