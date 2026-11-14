@extends('layouts.admin')

@section('title', 'Command Dashboard')

@section('content')
<div class="space-y-6">

    <!-- Top Summary Banner -->
    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900 flex items-center gap-3">
                Emergency Command Operations
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse"></span>
                    Live Connected
                </span>
            </h1>
            <p class="text-sm text-slate-500 mt-0.5">Real-time dispatch, fleet telemetry, and hospital trauma coordination.</p>
        </div>

        <div class="flex items-center space-x-3">
            <a href="{{ route('admin.live-map') }}" class="inline-flex items-center space-x-2 px-4 py-2 bg-white border border-slate-300 rounded-xl text-sm font-semibold text-slate-700 hover:bg-slate-50 hover:text-slate-900 transition shadow-xs">
                <svg class="w-4 h-4 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                </svg>
                <span>Full Screen Live Map</span>
            </a>
            <a href="{{ route('admin.bookings') }}" class="inline-flex items-center space-x-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-sm font-semibold transition shadow-sm shadow-teal-600/20">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                <span>Dispatch Logs</span>
            </a>
        </div>
    </div>

    <!-- 6 Operational KPI Cards (Real Data from MySQL) -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-6 gap-4">
        <!-- Active Incidents -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-red-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">Active Incidents</span>
                <span class="p-2 rounded-xl bg-red-50 text-red-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['active_bookings'] }}</div>
            <div class="text-xs text-red-600 font-medium mt-1.5 flex items-center gap-1">
                <span class="w-2 h-2 rounded-full bg-red-500 animate-ping"></span>
                Ongoing Dispatches
            </div>
        </div>

        <!-- Available Responders -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-emerald-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">Available Responders</span>
                <span class="p-2 rounded-xl bg-emerald-50 text-emerald-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['available_ambulances'] }}</div>
            <div class="text-xs text-emerald-600 font-medium mt-1.5">Ready for Callout</div>
        </div>

        <!-- In-Transit Ambulances -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-amber-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">In-Transit Ambulances</span>
                <span class="p-2 rounded-xl bg-amber-50 text-amber-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['busy_ambulances'] }}</div>
            <div class="text-xs text-amber-600 font-medium mt-1.5">En Route / On Duty</div>
        </div>

        <!-- Verified Paramedics -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-teal-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">Verified Paramedics</span>
                <span class="p-2 rounded-xl bg-teal-50 text-teal-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['verified_drivers'] }}</div>
            <div class="text-xs text-teal-600 font-medium mt-1.5">{{ $metrics['online_drivers'] }} Currently Online</div>
        </div>

        <!-- Registered Citizens -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-blue-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">Registered Citizens</span>
                <span class="p-2 rounded-xl bg-blue-50 text-blue-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['total_users'] }}</div>
            <div class="text-xs text-blue-600 font-medium mt-1.5">App User Base</div>
        </div>

        <!-- Completed Handover -->
        <div class="bg-white border border-slate-200 rounded-2xl p-5 shadow-xs hover:border-indigo-300 transition group">
            <div class="flex items-center justify-between text-slate-500 mb-2">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-500">Completed Trips</span>
                <span class="p-2 rounded-xl bg-indigo-50 text-indigo-600 group-hover:scale-110 transition">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                </span>
            </div>
            <div class="text-3xl font-extrabold text-slate-900">{{ $metrics['completed_trips'] }}</div>
            <div class="text-xs text-indigo-600 font-medium mt-1.5">{{ $metrics['cancelled_trips'] }} Cancelled</div>
        </div>
    </div>

    <!-- Active Live Incident Interceptor Feed -->
    @if($activeIncidents->isNotEmpty())
        <div class="bg-red-50/60 border border-red-200 rounded-2xl p-5 shadow-xs">
            <div class="flex items-center justify-between mb-4">
                <div class="flex items-center space-x-2">
                    <span class="relative flex h-3 w-3">
                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                        <span class="relative inline-flex rounded-full h-3 w-3 bg-red-600"></span>
                    </span>
                    <h2 class="text-sm font-bold text-red-950 uppercase tracking-wider">Live Priority Incident Interceptor ({{ $activeIncidents->count() }} In-Flight)</h2>
                </div>
                <span class="text-xs text-red-700 font-medium">Automatic Real-Time Sync</span>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                @foreach($activeIncidents as $incident)
                    <div class="bg-white border border-red-200 rounded-xl p-4 shadow-xs flex flex-col justify-between">
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <span class="font-bold text-slate-900 text-sm">{{ $incident->booking_reference ?: '#BK-' . $incident->id }}</span>
                                <span class="px-2 py-0.5 rounded-full text-xs font-bold uppercase bg-red-100 text-red-700 border border-red-200">
                                    {{ strtoupper($incident->status) }}
                                </span>
                            </div>
                            <div class="text-xs font-medium text-slate-700">Patient: <span class="font-bold text-slate-900">{{ $incident->patient_name ?: 'Emergency Patient' }}</span></div>
                            <div class="text-xs text-slate-500 mt-1 line-clamp-1">📍 {{ $incident->pickup_address }}</div>
                            <div class="text-xs text-teal-700 font-semibold mt-1">🏥 {{ is_array($incident->destination_hospital) ? ($incident->destination_hospital['name'] ?? 'Hospital') : ($incident->destination_hospital ?: 'Trauma Center') }}</div>
                        </div>

                        <div class="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
                            <span class="text-xs text-slate-500">
                                🚑 {{ $incident->driver ? $incident->driver->name . ' (' . ($incident->driver->vehicle_plate ?: 'Ambulance') . ')' : 'Searching Unit...' }}
                            </span>
                            <form action="{{ route('admin.bookings.cancel', $incident->id) }}" method="POST" onsubmit="return confirm('Confirm cancellation of incident {{ $incident->booking_reference }}?');">
                                @csrf
                                <input type="hidden" name="reason" value="Cancelled via Command Interceptor Panel">
                                <button type="submit" class="text-xs font-semibold px-2 py-1 bg-red-50 text-red-700 hover:bg-red-100 rounded-lg transition border border-red-200">
                                    Cancel
                                </button>
                            </form>
                        </div>
                    </div>
                @endforeach
            </div>
        </div>
    @endif

    <!-- Recent Emergency Bookings Table (Direct from MySQL) -->
    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="p-5 border-b border-slate-200 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
                <h2 class="text-base font-bold text-slate-900">Recent Emergency Trips &amp; Dispatches</h2>
                <p class="text-xs text-slate-500 mt-0.5">Live emergency requests logged into MySQL database.</p>
            </div>
            <a href="{{ route('admin.bookings') }}" class="text-xs font-bold text-teal-700 hover:text-teal-900 flex items-center gap-1">
                View All Trips
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
            </a>
        </div>

        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Booking Ref</th>
                        <th class="py-3 px-4">Patient / Citizen</th>
                        <th class="py-3 px-4">Category</th>
                        <th class="py-3 px-4">Pickup Location</th>
                        <th class="py-3 px-4">Destination Hospital</th>
                        <th class="py-3 px-4">Assigned Unit</th>
                        <th class="py-3 px-4">Status</th>
                        <th class="py-3 px-4">Logged Time</th>
                        <th class="py-3 px-4 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($recentBookings as $b)
                        <tr class="hover:bg-slate-50/80 transition">
                            <td class="py-3 px-4 font-bold text-slate-900 whitespace-nowrap">
                                {{ $b->booking_reference ?: '#BK-' . $b->id }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-semibold text-slate-900">{{ $b->patient_name ?: 'Emergency Patient' }}</div>
                                <div class="text-[11px] text-slate-500">{{ $b->callback_phone ?: 'SIM Verified' }}</div>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2 py-0.5 rounded text-[11px] font-bold uppercase bg-slate-100 text-slate-800 border border-slate-200">
                                    {{ $b->emergency_category ?: 'EMERGENCY' }}
                                </span>
                            </td>
                            <td class="py-3 px-4 max-w-xs truncate" title="{{ $b->pickup_address }}">
                                {{ $b->pickup_address }}
                            </td>
                            <td class="py-3 px-4 max-w-xs truncate font-medium text-teal-800" title="{{ is_array($b->destination_hospital) ? ($b->destination_hospital['name'] ?? 'Hospital') : $b->destination_hospital }}">
                                {{ is_array($b->destination_hospital) ? ($b->destination_hospital['name'] ?? 'Nearest Trauma Center') : ($b->destination_hospital ?: 'Nearest Trauma Center') }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                @if($b->driver)
                                    <div class="font-semibold text-slate-900">{{ $b->driver->name }}</div>
                                    <div class="text-[11px] text-teal-700 font-mono">{{ $b->driver->vehicle_plate ?: 'TN-38-EMG' }}</div>
                                @else
                                    <span class="text-amber-600 font-medium italic">Unassigned</span>
                                @endif
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                @php
                                    $st = strtolower($b->status);
                                    $pillClasses = match($st) {
                                        'trip_completed', 'completed' => 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                        'cancelled' => 'bg-slate-100 text-slate-600 border-slate-200',
                                        'accepted', 'driver_assigned', 'en_route_pickup' => 'bg-blue-50 text-blue-700 border-blue-200',
                                        'arrived_pickup', 'patient_picked_up', 'in_transit_hospital' => 'bg-amber-50 text-amber-700 border-amber-200',
                                        default => 'bg-red-50 text-red-700 border-red-200',
                                    };
                                @endphp
                                <span class="px-2.5 py-1 rounded-full text-[11px] font-bold uppercase border {{ $pillClasses }}">
                                    {{ str_replace('_', ' ', $st) }}
                                </span>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap text-slate-500 font-mono text-[11px]">
                                {{ $b->created_at ? $b->created_at->format('d M H:i:s') : 'N/A' }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap text-right">
                                @if(!in_array($b->status, ['trip_completed', 'completed', 'cancelled']))
                                    <form action="{{ route('admin.bookings.cancel', $b->id) }}" method="POST" class="inline" onsubmit="return confirm('Cancel trip {{ $b->booking_reference }}?');">
                                        @csrf
                                        <input type="hidden" name="reason" value="Cancelled by Central Admin">
                                        <button type="submit" class="px-2.5 py-1 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 border border-red-200 font-bold transition">
                                            Cancel
                                        </button>
                                    </form>
                                @else
                                    <span class="text-slate-400 font-mono text-[11px]">Logged</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="py-8 text-center text-slate-400">
                                No emergency dispatches recorded in database.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

</div>
@endsection

