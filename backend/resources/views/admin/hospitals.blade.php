@extends('layouts.admin')

@section('title', 'Emergency Hospitals Network')

@section('content')
<div class="space-y-6">

    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">Hospital &amp; Trauma Center Grid</h1>
            <p class="text-xs text-slate-500 mt-0.5">Designated tertiary emergency care facilities, trauma ICUs, and government 108 network hubs.</p>
        </div>
        <div class="text-xs font-semibold px-3 py-1.5 rounded-xl bg-teal-50 text-teal-800 border border-teal-200">
            Network Facilities: {{ count($hospitals) }}
        </div>
    </div>

    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Hospital / Trauma Center</th>
                        <th class="py-3 px-4">Emergency Category</th>
                        <th class="py-3 px-4">Address &amp; Location</th>
                        <th class="py-3 px-4">Emergency Hotline</th>
                        <th class="py-3 px-4">GPS Coordinates</th>
                        <th class="py-3 px-4">Trauma Status</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($hospitals as $h)
                        <tr class="hover:bg-slate-50/80 transition">
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-bold text-slate-900 text-sm">🏥 {{ $h['name'] }}</div>
                                <div class="text-[11px] text-teal-700 font-medium">Distance: ~{{ number_format($h['distance_km'] ?? 3.5, 1) }} km</div>
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold uppercase bg-slate-100 text-slate-800 border border-slate-200">
                                    {{ $h['type'] ?? 'Government & Tertiary Trauma' }}
                                </span>
                            </td>
                            <td class="py-3 px-4 max-w-sm truncate text-slate-600" title="{{ $h['address'] }}">
                                📍 {{ $h['address'] }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono font-bold text-teal-800">
                                📞 {{ $h['emergency_phone'] ?? '108' }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono text-[11px] text-slate-500">
                                {{ number_format($h['lat'], 4) }}° N, {{ number_format($h['lng'], 4) }}° E
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2.5 py-1 rounded-full text-[11px] font-bold uppercase bg-emerald-50 text-emerald-700 border border-emerald-200">
                                    ICU Active
                                </span>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="py-8 text-center text-slate-400">
                                No trauma centers registered in network.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

</div>
@endsection

