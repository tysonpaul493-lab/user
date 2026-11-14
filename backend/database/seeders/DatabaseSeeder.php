<?php

namespace Database\Seeders;

use App\Models\DriverNotification;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Keep database free of hardcoded default personal user/driver names.
        if (DriverNotification::count() === 0) {
            DriverNotification::create([
                'title' => '🏥 Dispatch System Online',
                'message' => 'Emergency dispatch server and real-time GPS tracking channels are active.',
                'type' => 'system',
            ]);
        }
    }
}
