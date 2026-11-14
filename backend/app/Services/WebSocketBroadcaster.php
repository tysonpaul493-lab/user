<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class WebSocketBroadcaster
{
    public static function broadcast(string|array $channels, string $eventName, array $payload): void
    {
        if (app()->runningUnitTests()) {
            return;
        }

        $channelList = is_array($channels) ? array_values($channels) : [$channels];
        $port = (int) config('liferoute.ws_internal_port', 8081);

        try {
            Http::timeout(1)
                ->connectTimeout(1)
                ->post("http://127.0.0.1:{$port}/broadcast", [
                    'channels' => $channelList,
                    'event' => $eventName,
                    'payload' => $payload,
                ]);
        } catch (\Throwable) {
            // Do not fail HTTP API writes if the WebSocket daemon is offline.
        }
    }

    public static function connectedClientsCount(): int
    {
        if (app()->runningUnitTests()) {
            return 0;
        }

        $port = (int) config('liferoute.ws_internal_port', 8081);

        try {
            $resp = Http::timeout(1)->connectTimeout(1)->get("http://127.0.0.1:{$port}/stats");
            if ($resp->successful()) {
                return (int) ($resp->json('connected_ws_clients') ?? 0);
            }
        } catch (\Throwable) {
            // Ignored
        }

        return 0;
    }
}
