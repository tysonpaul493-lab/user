@extends('layouts.admin')

@section('title', 'Registered Citizens')

@section('content')
<div class="space-y-6">

    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">Registered Citizens &amp; User Accounts</h1>
            <p class="text-xs text-slate-500 mt-0.5">Municipal citizen profiles stored in MySQL database for rapid 1-Tap emergency response.</p>
        </div>
        <div class="text-xs font-semibold px-3 py-1.5 rounded-xl bg-blue-50 text-blue-800 border border-blue-200">
            Total Citizens: {{ $users->total() }}
        </div>
    </div>

    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Citizen Name</th>
                        <th class="py-3 px-4">Phone (SIM Verified)</th>
                        <th class="py-3 px-4">Email Address</th>
                        <th class="py-3 px-4">Blood Group</th>
                        <th class="py-3 px-4">Emergency Medical Notes</th>
                        <th class="py-3 px-4">Registration Date</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($users as $u)
                        <tr class="hover:bg-slate-50/80 transition">
                            <td class="py-3 px-4 font-bold text-slate-900 whitespace-nowrap">
                                👤 {{ $u->name }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono text-teal-700 font-semibold">
                                {{ $u->phone }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap text-slate-600">
                                {{ $u->email ?: 'citizen@liferoute.in' }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2 py-0.5 rounded font-bold text-xs bg-red-50 text-red-700 border border-red-200">
                                    {{ $u->blood_group ?: 'O+' }}
                                </span>
                            </td>
                            <td class="py-3 px-4 max-w-sm truncate text-slate-500" title="{{ $u->emergency_notes }}">
                                {{ $u->emergency_notes ?: 'None specified' }}
                            </td>
                            <td class="py-3 px-4 whitespace-nowrap font-mono text-slate-500 text-[11px]">
                                {{ $u->created_at ? $u->created_at->format('d M Y, H:i') : 'Pre-registered' }}
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="py-8 text-center text-slate-400">
                                No registered citizens recorded in database.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if($users->hasPages())
            <div class="p-4 border-t border-slate-200">
                {{ $users->links() }}
            </div>
        @endif
    </div>

</div>
@endsection

