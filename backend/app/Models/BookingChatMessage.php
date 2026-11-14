<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BookingChatMessage extends Model
{
    protected $fillable = [
        'booking_id',
        'booking_reference',
        'sender',
        'message',
    ];

    public function toApiArray(): array
    {
        return [
            'id' => (int) $this->id,
            'sender' => $this->sender,
            'message' => $this->message,
            'timestamp' => ($this->created_at ?? now())->toIso8601String(),
        ];
    }
}
