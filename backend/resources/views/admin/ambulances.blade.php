@extends('layouts.admin')

@section('title', 'Municipal Ambulance Fleet')

@section('content')
<div class="space-y-6">

    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">Municipal Ambulance Fleet Registry</h1>
            <p class="text-xs text-slate-500 mt-0.5">Emergency vehicle road readiness, ICU biomedical equipment, and paramedic duty allocations.</p>
        </div>
        <div class="text-xs font-semibold px-3 py-1.5 rounded-xl bg-teal-50 text-teal-800 border border-teal-200">
            Registered Vehicles: {{ count($ambulances) }}
        </div>
    </div>

    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Vehicle Plate</th>
                        <th class="py-3 px-4">Vehicle Model &amp; Year</th>
                        <th class="py-3 px-4">Classification</th>
                        <th class="py-3 px-4">Assigned Paramedic</th>
                        <th class="py-3 px-4">Biomedical Equipment</th>
                        <th class="py-3 px-4">Readiness Status</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($ambulances as $amb)
                        <tr class="hover:bg-slate-50/80 transition">
                            <td class="py-3 px-4 font-mono font-bold text-slate-900 whitespace-nowrap">
                                🚑 {{ $amb['plate'] }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-bold text-slate-900">{{ $amb['model'] }}</div>
                                <div class="text-[11px] text-slate-500 font-mono">Mfg Year: {{ $amb['year'] }}</div>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase bg-teal-50 text-teal-700 border border-teal-200">
                                    {{ $amb['type_display'] }}
                                </span>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-bold text-slate-900">{{ $amb['driver_name'] }}</div>
                                <div class="text-[11px] text-slate-500 font-mono">📞 {{ $amb['driver_phone'] }}</div>
                            </td>
                            <td class="py-3 px-4 max-w-sm truncate text-slate-600" title="{{ $amb['equipment'] }}">
                                {{ $amb['equipment'] }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                @php
                                    $st = $amb['status'];
                                    $pill = match($st) {
                                        'AVAILABLE' => 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                        'BUSY' => 'bg-amber-50 text-amber-700 border-amber-200',
                                        default => 'bg-slate-100 text-slate-600 border-slate-200',
                                    };
                                @endphp
                                <span class="px-2.5 py-1 rounded-full text-[11px] font-bold uppercase border {{ $pill }}">
                                    {{ $st }}
                                </span>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="py-8 text-center text-slate-400">
                                No fleet ambulances logged in municipal directory.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

</div>
@endsection

