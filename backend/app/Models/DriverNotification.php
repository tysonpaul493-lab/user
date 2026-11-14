<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverNotification extends Model
{
    protected $fillable = [
        'booking_id',
        'booking_reference',
        'title',
        'message',
        'type',
        'request_payload',
        'is_read',
    ];

    protected function casts(): array
    {
        return [
            'request_payload' => 'array',
            'is_read' => 'boolean',
        ];
    }

    public function toApiArray(): array
    {
        $item = [
            'id' => (int) $this->id,
            'title' => $this->title,
            'message' => $this->message,
            'type' => $this->type,
            'timestamp' => ($this->created_at ?? now())->toIso8601String(),
            'is_read' => (bool) $this->is_read,
        ];
        if ($this->booking_id !== null) {
            $item['booking_id'] = (int) $this->booking_id;
        }
        if ($this->booking_reference !== null) {
            $item['booking_reference'] = $this->booking_reference;
        }
        if ($this->request_payload !== null) {
            $item['request'] = $this->request_payload;
        }

        return $item;
    }
}
