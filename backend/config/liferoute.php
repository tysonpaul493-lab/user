<?php

return [
    'ws_host' => env('WS_HOST', '0.0.0.0'),
    'ws_port' => (int) env('WS_PORT', 8080),
    'ws_internal_port' => (int) env('WS_INTERNAL_PORT', 8081),
    'reverb_app_key' => env('REVERB_APP_KEY', 'liferoute_reverb_key'),
    'jwt_secret' => env('JWT_SECRET', 'liferoute_emergency_secure_jwt_token_key_2026'),
    'textbee_api_key' => env('TEXTBEE_API_KEY', ''),
    'textbee_device_id' => env('TEXTBEE_DEVICE_ID', ''),
    'textbee_sim_subscription_id' => env('TEXTBEE_SIM_SUBSCRIPTION_ID', ''),
    'fast2sms_api_key' => env('FAST2SMS_API_KEY', env('SMS_GATEWAY_KEY', '')),
    'two_factor_api_key' => env('TWO_FACTOR_API_KEY', ''),
];
