@extends('layouts.admin')

@section('title', 'Paramedic Responders')

@section('content')
<div class="space-y-6">

    <!-- Header bar -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">Paramedic Responders &amp; Drivers</h1>
            <p class="text-xs text-slate-500 mt-0.5">Licensing compliance, verification auditing, and live responder availability.</p>
        </div>
        <div class="text-xs font-semibold px-3 py-1.5 rounded-xl bg-teal-50 text-teal-800 border border-teal-200">
            Total Responders: {{ $drivers->count() }} ({{ $drivers->where('is_online', true)->count() }} Online)
        </div>
    </div>

    <!-- Table (Full Width) -->
    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Paramedic Name</th>
                        <th class="py-3 px-4">Contact Phone</th>
                        <th class="py-3 px-4">Ambulance Unit</th>
                        <th class="py-3 px-4">License Number</th>
                        <th class="py-3 px-4">Verification</th>
                        <th class="py-3 px-4">Duty Status</th>
                        <th class="py-3 px-4">Completed Trips</th>
                        <th class="py-3 px-4">Rating</th>
                        <th class="py-3 px-4 text-right">Administrative Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($drivers as $dr)
                        <tr class="hover:bg-slate-50/80 transition">
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-bold text-slate-900 text-sm">{{ $dr->name }}</div>
                                <div class="text-[11px] text-slate-500">{{ $dr->email ?: 'paramedic@liferoute.org' }}</div>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono text-[11px]">
                                {{ $dr->phone }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-semibold text-slate-900">{{ $dr->vehicle_model ?: 'Force Traveller ALS' }}</div>
                                <div class="font-mono text-teal-700 text-[11px]">{{ $dr->vehicle_plate ?: ($dr->vehicle_number ?: 'TN-38-EMG') }}</div>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono text-slate-600">
                                {{ $dr->license_number ?: 'DL-' . $dr->id . '-2026' }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                @php
                                    $vStatus = strtolower($dr->verification_status ?: 'approved');
                                    $vPill = match($vStatus) {
                                        'approved' => 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                        'suspended' => 'bg-red-50 text-red-700 border-red-200',
                                        'rejected' => 'bg-slate-100 text-slate-600 border-slate-200',
                                        default => 'bg-amber-50 text-amber-700 border-amber-200',
                                    };
                                @endphp
                                <span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase border {{ $vPill }}">
                                    {{ $vStatus }}
                                </span>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                @if($dr->is_online)
                                    <span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
                                        <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                                        ONLINE
                                    </span>
                                @else
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-500 border border-slate-200">
                                        OFFLINE
                                    </span>
                                @endif
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-bold text-slate-900">
                                {{ $dr->total_trips ?: 0 }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-semibold text-amber-600">
                                ⭐ {{ number_format($dr->rating ?: 5.0, 1) }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap text-right space-x-2">
                                <!-- Verify / Approve Toggle -->
                                @if($dr->verification_status !== 'approved')
                                    <form action="{{ route('admin.drivers.verify', $dr->id) }}" method="POST" class="inline">
                                        @csrf
                                        <input type="hidden" name="action" value="APPROVE">
                                        <button type="submit" class="px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200 font-bold transition">
                                            Approve
                                        </button>
                                    </form>
                                @endif

                                <!-- Suspension Toggle -->
                                <form action="{{ route('admin.drivers.toggle-suspension', $dr->id) }}" method="POST" class="inline" onsubmit="return confirm('Change suspension state for {{ $dr->name }}?');">
                                    @csrf
                                    @if($dr->verification_status === 'suspended')
                                        <button type="submit" class="px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 border border-emerald-200 font-bold transition">
                                            Reactivate
                                        </button>
                                    @else
                                        <button type="submit" class="px-2.5 py-1 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 border border-red-200 font-bold transition">
                                            Suspend
                                        </button>
                                    @endif
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="py-8 text-center text-slate-400">
                                No paramedic profiles registered in database.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

</div>
@endsection

