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

    public static function findByPhone(?string $rawPhone): ?self
    {
        if (empty($rawPhone)) {
            return null;
        }
        $digits = preg_replace('/\D/', '', $rawPhone);
        if (strlen($digits) < 7) {
            return null;
        }
        $last10 = strlen($digits) >= 10 ? substr($digits, -10) : $digits;

        return self::where('phone', $rawPhone)
            ->orWhere('phone', '+91' . $last10)
            ->orWhere('phone', '+91 ' . $last10)
            ->orWhere('phone', $last10)
            ->orWhere('phone', 'LIKE', '%' . $last10)
            ->orderByRaw("CASE WHEN name IS NOT NULL AND TRIM(name) != '' THEN 0 ELSE 1 END")
            ->orderByDesc('id')
            ->first();
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
