<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverDocument extends Model
{
    protected $fillable = [
        'driver_id',
        'document_type',
        'original_filename',
        'mime_type',
        'file_path',
    ];
}
