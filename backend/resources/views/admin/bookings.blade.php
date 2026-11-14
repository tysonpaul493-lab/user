@extends('layouts.admin')

@section('title', 'Emergency Trips & Dispatch Logs')

@section('content')
<div class="space-y-6">

    <!-- Header & Filters -->
    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900">Emergency Trips &amp; Incident Records</h1>
            <p class="text-xs text-slate-500 mt-0.5">Comprehensive audit trail of all citizen bookings, paramedic dispatches, and hospital handovers.</p>
        </div>

        <!-- Filter Pills -->
        <div class="flex items-center space-x-1.5 bg-white border border-slate-200 p-1 rounded-xl shadow-xs">
            <a href="{{ route('admin.bookings', ['status' => 'all']) }}" class="px-3 py-1.5 rounded-lg text-xs font-bold transition {{ $statusFilter === 'all' ? 'bg-teal-600 text-white' : 'text-slate-600 hover:text-slate-900' }}">
                All Trips
            </a>
            <a href="{{ route('admin.bookings', ['status' => 'active']) }}" class="px-3 py-1.5 rounded-lg text-xs font-bold transition {{ $statusFilter === 'active' ? 'bg-teal-600 text-white' : 'text-slate-600 hover:text-slate-900' }}">
                Active
            </a>
            <a href="{{ route('admin.bookings', ['status' => 'completed']) }}" class="px-3 py-1.5 rounded-lg text-xs font-bold transition {{ $statusFilter === 'completed' ? 'bg-teal-600 text-white' : 'text-slate-600 hover:text-slate-900' }}">
                Completed
            </a>
            <a href="{{ route('admin.bookings', ['status' => 'cancelled']) }}" class="px-3 py-1.5 rounded-lg text-xs font-bold transition {{ $statusFilter === 'cancelled' ? 'bg-teal-600 text-white' : 'text-slate-600 hover:text-slate-900' }}">
                Cancelled
            </a>
        </div>
    </div>

    <!-- Table of Bookings (Full Width) -->
    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
            <table class="w-full text-left text-xs border-collapse">
                <thead>
                    <tr class="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase tracking-wider">
                        <th class="py-3 px-4">Trip Reference</th>
                        <th class="py-3 px-4">Patient / Citizen</th>
                        <th class="py-3 px-4">Severity</th>
                        <th class="py-3 px-4">Pickup Address</th>
                        <th class="py-3 px-4">Trauma Hospital</th>
                        <th class="py-3 px-4">Assigned Paramedic</th>
                        <th class="py-3 px-4">Status</th>
                        <th class="py-3 px-4">Chronometry (Timeline)</th>
                        <th class="py-3 px-4 text-right">Command Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 text-slate-700">
                    @forelse($bookings as $b)
                        <tr class="hover:bg-slate-50/80 transition">
                            <!-- Ref -->
                            <td class="py-3 px-4 font-mono font-bold text-slate-900 whitespace-nowrap">
                                {{ $b->booking_reference ?: '#BK-' . $b->id }}
                            </td>

                            <!-- Patient -->
                            <td class="py-3 px-4 whitespace-nowrap">
                                <div class="font-bold text-slate-900">{{ $b->patient_name ?: 'Emergency Patient' }}</div>
                                <div class="text-[11px] text-slate-500 font-mono">{{ $b->callback_phone ?: 'SIM Identified' }}</div>
                            </td>

                            <!-- Severity -->
                            <td class="py-3 px-4 whitespace-nowrap">
                                <span class="px-2 py-0.5 rounded text-[11px] font-bold uppercase bg-slate-100 text-slate-800 border border-slate-200">
                                    {{ $b->emergency_category ?: 'CRITICAL' }}
                                </span>
                            </td>

                            <!-- Pickup -->
                            <td class="py-3 px-4 max-w-xs truncate" title="{{ $b->pickup_address }}">
                                📍 {{ $b->pickup_address }}
                            </td>

                            <!-- Hospital -->
                            <td class="py-3 px-4 max-w-xs truncate font-medium text-teal-800" title="{{ is_array($b->destination_hospital) ? ($b->destination_hospital['name'] ?? 'Hospital') : $b->destination_hospital }}">
                                🏥 {{ is_array($b->destination_hospital) ? ($b->destination_hospital['name'] ?? 'Nearest Hospital') : ($b->destination_hospital ?: 'Nearest Trauma Center') }}
                            </td>

                            <!-- Paramedic -->
                            <td class="py-3 px-4 whitespace-nowrap">
                                @if($b->driver)
                                    <div class="font-bold text-slate-900">{{ $b->driver->name }}</div>
                                    <div class="text-[11px] text-teal-700 font-mono">{{ $b->driver->vehicle_plate ?: 'TN-38-EMG' }}</div>
                                @else
                                    <span class="text-amber-600 font-medium italic">Unassigned</span>
                                    <button onclick="openAssignModal('{{ $b->id }}', '{{ $b->booking_reference }}')" class="block text-[11px] font-bold text-teal-700 hover:underline mt-0.5">
                                        + Manual Dispatch
                                    </button>
                                @endif
                            </td>

                            <!-- Status -->
                            <td class="py-3 px-4 whitespace-nowrap">
                                @php
                                    $st = strtolower($b->status);
                                    $pill = match($st) {
                                        'trip_completed', 'completed' => 'bg-emerald-50 text-emerald-700 border-emerald-200',
                                        'cancelled' => 'bg-slate-100 text-slate-600 border-slate-200',
                                        'accepted', 'driver_assigned', 'en_route_pickup' => 'bg-blue-50 text-blue-700 border-blue-200',
                                        'arrived_pickup', 'patient_picked_up', 'in_transit_hospital' => 'bg-amber-50 text-amber-700 border-amber-200',
                                        default => 'bg-red-50 text-red-700 border-red-200',
                                    };
                                @endphp
                                <span class="px-2.5 py-1 rounded-full text-[11px] font-bold uppercase border {{ $pill }}">
                                    {{ str_replace('_', ' ', $st) }}
                                </span>
                            </td>

                            <!-- Timeline Chronometry -->
                            <td class="py-3 px-4 whitespace-nowrap text-[11px] text-slate-500 font-mono">
                                <div>Log: {{ $b->created_at ? $b->created_at->format('H:i:s') : '--' }}</div>
                                @if($b->accepted_at)
                                    <div class="text-teal-700">Acc: {{ \Carbon\Carbon::parse($b->accepted_at)->format('H:i:s') }}</div>
                                @endif
                                @if($b->completed_at)
                                    <div class="text-emerald-700">End: {{ \Carbon\Carbon::parse($b->completed_at)->format('H:i:s') }}</div>
                                @endif
                                @if($b->cancel_reason)
                                    <div class="text-red-600 max-w-[140px] truncate" title="{{ $b->cancel_reason }}">Reason: {{ $b->cancel_reason }}</div>
                                @endif
                            </td>

                            <!-- Actions -->
                            <td class="py-3 px-4 whitespace-nowrap text-right space-x-2">
                                @if(!in_array($b->status, ['trip_completed', 'completed', 'cancelled']))
                                    <button onclick="openCancelModal('{{ $b->id }}', '{{ $b->booking_reference }}')" class="px-2.5 py-1 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 border border-red-200 font-bold transition">
                                        Cancel Trip
                                    </button>
                                @else
                                    <span class="text-slate-400 font-mono text-[11px]">Archived</span>
                                @endif
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="py-12 text-center text-slate-400">
                                No emergency bookings found under this filter.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if($bookings->hasPages())
            <div class="p-4 border-t border-slate-200">
                {{ $bookings->links() }}
            </div>
        @endif
    </div>

</div>

<!-- Modal: Assign Driver -->
<div id="assign-modal" class="fixed inset-0 z-50 hidden bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4">
    <div class="bg-white border border-slate-200 rounded-2xl p-6 shadow-xl max-w-md w-full">
        <h3 class="text-base font-bold text-slate-900 mb-1">Manual Paramedic Dispatch</h3>
        <p class="text-xs text-slate-500 mb-4" id="assign-modal-ref"></p>

        <form id="assign-form" method="POST" action="">
            @csrf
            <div class="mb-4">
                <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Select Active Paramedic / Ambulance</label>
                <select name="driver_id" required class="w-full py-2.5 px-3 rounded-xl border border-slate-300 text-sm focus:ring-2 focus:ring-teal-500 focus:outline-none">
                    @foreach($availableDrivers as $dr)
                        <option value="{{ $dr->id }}">{{ $dr->name }} &bull; {{ $dr->vehicle_plate ?: 'TN-38-EMG' }} ({{ strtoupper($dr->vehicle_type ?: 'ALS') }})</option>
                    @endforeach
                </select>
            </div>

            <div class="flex items-center justify-end space-x-3 mt-6">
                <button type="button" onclick="closeAssignModal()" class="px-4 py-2 rounded-xl border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-50">Cancel</button>
                <button type="submit" class="px-4 py-2 rounded-xl bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold shadow-xs">Dispatch Paramedic</button>
            </div>
        </form>
    </div>
</div>

<!-- Modal: Cancel Trip -->
<div id="cancel-modal" class="fixed inset-0 z-50 hidden bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4">
    <div class="bg-white border border-slate-200 rounded-2xl p-6 shadow-xl max-w-md w-full">
        <h3 class="text-base font-bold text-red-950 mb-1">Cancel Emergency Incident</h3>
        <p class="text-xs text-slate-500 mb-4" id="cancel-modal-ref"></p>

        <form id="cancel-form" method="POST" action="">
            @csrf
            <div class="mb-4">
                <label class="block text-xs font-bold text-slate-700 uppercase mb-2">Reason for Cancellation</label>
                <textarea name="reason" required rows="3" placeholder="e.g. Patient transported via private vehicle / False alarm / Dispatch diverted"
                          class="w-full py-2 px-3 rounded-xl border border-slate-300 text-sm focus:ring-2 focus:ring-red-500 focus:outline-none"></textarea>
            </div>

            <div class="flex items-center justify-end space-x-3 mt-6">
                <button type="button" onclick="closeCancelModal()" class="px-4 py-2 rounded-xl border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-50">Close</button>
                <button type="submit" class="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-bold shadow-xs">Confirm Cancellation</button>
            </div>
        </form>
    </div>
</div>

@push('scripts')
<script>
    function openAssignModal(id, ref) {
        document.getElementById('assign-modal-ref').innerText = 'Assigning ambulance unit to incident ' + ref;
        document.getElementById('assign-form').action = '/admin/bookings/' + id + '/assign';
        document.getElementById('assign-modal').classList.remove('hidden');
    }
    function closeAssignModal() {
        document.getElementById('assign-modal').classList.add('hidden');
    }
    function openCancelModal(id, ref) {
        document.getElementById('cancel-modal-ref').innerText = 'Cancelling incident ' + ref;
        document.getElementById('cancel-form').action = '/admin/bookings/' + id + '/cancel';
        document.getElementById('cancel-modal').classList.remove('hidden');
    }
    function closeCancelModal() {
        document.getElementById('cancel-modal').classList.add('hidden');
    }
</script>
@endpush
@endsection

