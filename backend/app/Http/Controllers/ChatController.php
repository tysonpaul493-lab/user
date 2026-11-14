<?php

namespace App\Http\Controllers;

use App\Models\BookingChatMessage;
use App\Services\WebSocketBroadcaster;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ChatController extends Controller
{
    public function index(string $id): JsonResponse
    {
        $booking = BookingController::findBookingByKey($id);
        $msgs = BookingChatMessage::query()
            ->where(function ($q) use ($id, $booking) {
                if (ctype_digit($id)) {
                    $q->where('booking_id', (int) $id);
                } else {
                    $q->where('booking_reference', $id);
                }
                if ($booking) {
                    $q->orWhere('booking_id', $booking->id);
                }
            })
            ->orderBy('id')
            ->get()
            ->map(static fn (BookingChatMessage $m) => $m->toApiArray())
            ->values();

        return response()->json([
            'status' => 'success',
            'messages' => $msgs,
        ]);
    }

    public function store(Request $request, string $id): JsonResponse
    {
        $message = trim((string) $request->input('message', ''));
        $sender = trim((string) ($request->input('sender') ?: 'user'));

        if ($message === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Message text required.',
            ], 400);
        }

        $booking = BookingController::findBookingByKey($id);
        $bookingId = $booking?->id ?? (ctype_digit($id) ? (int) $id : 0);
        $bookingRef = $booking?->booking_reference ?? (str_starts_with($id, 'BK-') ? $id : 'BK-'.$id);

        $chat = BookingChatMessage::create([
            'booking_id' => $bookingId,
            'booking_reference' => $bookingRef,
            'sender' => $sender,
            'message' => $message,
        ]);

        $entry = $chat->toApiArray();
        $channels = [
            'private-bookings.'.$id,
            'private-booking.'.$id,
        ];
        if ($booking) {
            $channels[] = 'private-bookings.'.$booking->booking_reference;
            $channels[] = 'private-booking.'.$booking->booking_reference;
            if ($booking->driver_id) {
                $channels[] = 'private-driver.'.$booking->driver_id;
            }
        }

        WebSocketBroadcaster::broadcast(array_values(array_unique($channels)), 'TripChatMessage', $entry);

        return response()->json([
            'status' => 'success',
            'entry' => $entry,
        ]);
    }
}
