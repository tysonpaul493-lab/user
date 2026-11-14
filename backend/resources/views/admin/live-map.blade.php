@extends('layouts.admin')

@section('title', 'Live GPS Tracking Map')

@section('content')
<div class="space-y-4">

    <!-- Header bar -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pb-2 border-b border-slate-200">
        <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900 flex items-center gap-3">
                Live Regional Fleet &amp; Emergency Map
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse"></span>
                    {{ $drivers->where('is_online', true)->count() }} Online Ambulances
                </span>
            </h1>
            <p class="text-xs text-slate-500">Live GPS tracking of emergency responders, hospital trauma hubs, and emergency pickup points.</p>
        </div>

        <div class="flex items-center space-x-2">
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-xs font-semibold text-slate-700 shadow-xs">
                <span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span> Available
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-xs font-semibold text-slate-700 shadow-xs">
                <span class="w-2.5 h-2.5 rounded-full bg-amber-500"></span> On Duty / En Route
            </span>
            <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-xs font-semibold text-slate-700 shadow-xs">
                <span class="w-2.5 h-2.5 rounded-full bg-red-600"></span> Emergency Incident
            </span>
        </div>
    </div>

    <!-- Map Canvas Container (Full Width across screen) -->
    <div class="bg-white border border-slate-200 rounded-2xl shadow-xs overflow-hidden relative">
        <div id="live-command-map" class="w-full h-[76vh] z-10"></div>

        <!-- Float Info Overlay -->
        <div class="absolute bottom-6 left-6 z-20 bg-white/95 backdrop-blur-sm border border-slate-200 rounded-2xl p-4 shadow-lg max-w-sm">
            <div class="text-xs font-bold uppercase tracking-wider text-slate-500 mb-1">Active Command Center</div>
            <div class="text-sm font-extrabold text-slate-900">Coimbatore North Metropolitan Area</div>
            <div class="text-xs text-slate-500 mt-1">Coordinates: 11.0318° N, 76.9437° E &bull; Centered on Government Medical Grid</div>
        </div>
    </div>

</div>

@push('scripts')
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const defaultLat = 11.0318;
        const defaultLng = 76.9437;

        // Initialize Leaflet Map
        const map = L.map('live-command-map', {
            zoomControl: true,
            scrollWheelZoom: true
        }).setView([defaultLat, defaultLng], 13);

        // OpenStreetMap Light Tiles (Clinical Clean Look)
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; OpenStreetMap contributors | LifeRoute Command'
        }).addTo(map);

        const ambulanceData = @json($drivers);
        const bookingData = @json($activeBookings);

        const ambulanceMarkers = {};

        // Custom Ambulance Marker Icons
        function getAmbulanceIcon(status) {
            const isAvailable = status === 'AVAILABLE';
            const bgClass = isAvailable ? '#10b981' : '#f59e0b';
            return L.divIcon({
                className: 'custom-amb-pin',
                html: `<div style="background-color: ${bgClass}; color: white; width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 16px; border: 3px solid white; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.2);">🚑</div>`,
                iconSize: [34, 34],
                iconAnchor: [17, 17],
                popupAnchor: [0, -18]
            });
        }

        // Custom Emergency Incident Marker
        const incidentIcon = L.divIcon({
            className: 'custom-incident-pin',
            html: `<div style="background-color: #ef4444; color: white; width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 16px; border: 3px solid white; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3); animation: pulse 1.5s infinite;">⚠️</div>`,
            iconSize: [36, 36],
            iconAnchor: [18, 18],
            popupAnchor: [0, -18]
        });

        // Plot Ambulances
        ambulanceData.forEach(amb => {
            if (amb.lat && amb.lng) {
                const marker = L.marker([amb.lat, amb.lng], { icon: getAmbulanceIcon(amb.status) }).addTo(map);
                marker.bindPopup(`
                    <div style="font-family: inherit; font-size: 12px; color: #1e293b; min-width: 180px;">
                        <div style="font-weight: 800; font-size: 13px; color: #0f172a; margin-bottom: 2px;">${amb.name}</div>
                        <div style="font-family: monospace; font-size: 11px; color: #0f766e; font-weight: bold; margin-bottom: 4px;">${amb.plate} (${amb.type})</div>
                        <div style="color: #64748b; margin-bottom: 2px;">📞 ${amb.phone}</div>
                        <div style="margin-top: 6px;">
                            <span style="display: inline-block; padding: 2px 8px; border-radius: 9999px; font-weight: 700; font-size: 10px; text-transform: uppercase; ${amb.status === 'AVAILABLE' ? 'background: #dcfce7; color: #15803d;' : 'background: #fef3c7; color: #b45309;'}">${amb.status}</span>
                        </div>
                    </div>
                `);
                ambulanceMarkers[amb.id] = marker;
            }
        });

        // Plot Active Emergencies
        bookingData.forEach(inc => {
            if (inc.pickup_lat && inc.pickup_lng) {
                const marker = L.marker([inc.pickup_lat, inc.pickup_lng], { icon: incidentIcon }).addTo(map);
                marker.bindPopup(`
                    <div style="font-family: inherit; font-size: 12px; color: #1e293b; min-width: 200px;">
                        <div style="font-weight: 800; font-size: 13px; color: #b91c1c; margin-bottom: 2px;">EMERGENCY: ${inc.reference}</div>
                        <div style="font-weight: 600; color: #0f172a;">Patient: ${inc.patient_name}</div>
                        <div style="color: #64748b; font-size: 11px; margin-top: 2px;">📍 ${inc.pickup_address}</div>
                        <div style="margin-top: 6px; font-size: 11px; color: #047857; font-weight: 600;">Ambulance: ${inc.driver_name}</div>
                    </div>
                `);
            }
        });

        // WebSocket listener for real-time driver movement updates
        const host = window.location.hostname || 'localhost';
        try {
            const socket = new WebSocket('ws://' + host + ':8080');
            socket.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.event && data.event.includes('DriverLocationUpdated')) {
                        const payload = typeof data.data === 'string' ? JSON.parse(data.data) : data.data;
                        const dId = payload.driver_id;
                        if (ambulanceMarkers[dId] && payload.lat && payload.lng) {
                            ambulanceMarkers[dId].setLatLng([payload.lat, payload.lng]);
                        }
                    }
                } catch (e) {}
            };
        } catch (e) {}
    });
</script>
@endpush
@endsection

