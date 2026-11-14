<?php

namespace App\Http\Controllers;

use App\Services\DriverAuthResolver;
use App\Services\WebSocketBroadcaster;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HealthController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'service' => 'LifeRoute Emergency Backend API (Laravel PHP + MySQL)',
            'status' => 'online',
            'version' => '1.0.0',
            'database' => config('database.default'),
            'connected_ws_clients' => WebSocketBroadcaster::connectedClientsCount(),
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    public function health(): JsonResponse
    {
        return response()->json([
            'status' => 'ok',
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    public function broadcastingAuth(Request $request): JsonResponse
    {
        $channelName = (string) $request->input('channel_name', '');
        $socketId = (string) $request->input('socket_id', '');
        $authKey = "{$socketId}:{$channelName}:auth_ok";
        $driver = DriverAuthResolver::resolveDriver($request);

        return response()->json([
            'auth' => config('liferoute.reverb_app_key').':'.$authKey,
            'channel_data' => json_encode([
                'user_id' => $driver?->id ?? 0,
                'user_info' => ['name' => $driver?->name ?? ''],
            ]),
        ]);
    }
}
