<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    use HasFactory, Notifiable;

    protected $fillable = [
        'public_id',
        'name',
        'phone',
        'blood_group',
        'emergency_notes',
        'email',
        'password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->public_id ?: (string) $this->id,
            'name' => $this->name ?? '',
            'phone' => $this->phone ?? '',
            'blood_group' => $this->blood_group ?? 'O+',
            'emergency_notes' => $this->emergency_notes ?? '',
        ];
    }
}
