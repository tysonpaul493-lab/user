<!DOCTYPE html>
<html lang="en" class="h-full bg-slate-50">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Central Command') | LifeRoute Emergency Medical Dispatch</title>

    <!-- Tailwind CSS CDN -->
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        clinical: {
                            50: '#f8fafc',
                            100: '#f1f5f9',
                            200: '#e2e8f0',
                            500: '#0f766e',
                            600: '#0d9488',
                            700: '#047857'
                        }
                    }
                }
            }
        }
    </script>

    <!-- Leaflet CSS & JS for Live Maps -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap');
        body { font-family: 'Inter', system-ui, -apple-system, sans-serif; }
        .custom-scrollbar::-webkit-scrollbar { width: 6px; height: 6px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: #f1f5f9; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
    </style>
</head>
<body class="h-full bg-slate-50 text-slate-800 flex flex-col antialiased">

    <!-- Top Clinical Navigation Header (Full Width) -->
    <header class="bg-white border-b border-slate-200 sticky top-0 z-50 shadow-sm w-full">
        <div class="w-full px-4 sm:px-6 lg:px-8">
            <div class="flex items-center justify-between h-16">
                <!-- Brand & Status -->
                <div class="flex items-center space-x-6">
                    <a href="{{ route('admin.dashboard') }}" class="flex items-center space-x-3 group">
                        <div class="w-10 h-10 rounded-xl bg-teal-600 flex items-center justify-center text-white shadow-md shadow-teal-600/20 group-hover:bg-teal-700 transition">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4" />
                            </svg>
                        </div>
                        <div>
                            <span class="text-lg font-bold tracking-tight text-slate-900 flex items-center gap-2">
                                LifeRoute
                                <span class="text-xs px-2 py-0.5 font-semibold bg-teal-50 text-teal-700 border border-teal-200 rounded-md uppercase tracking-wider">Command</span>
                            </span>
                            <span class="text-xs text-slate-500 block">Emergency Medical Dispatch</span>
                        </div>
                    </a>

                    <!-- Navigation Links -->
                    <nav class="hidden md:flex items-center space-x-1 pl-4 border-l border-slate-200">
                        <a href="{{ route('admin.dashboard') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.dashboard') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Dashboard
                        </a>
                        <a href="{{ route('admin.live-map') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.live-map') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Live Map
                        </a>
                        <a href="{{ route('admin.bookings') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.bookings') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Emergency Trips
                        </a>
                        <a href="{{ route('admin.drivers') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.drivers') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Paramedics
                        </a>
                        <a href="{{ route('admin.ambulances') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.ambulances') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Ambulance Fleet
                        </a>
                        <a href="{{ route('admin.hospitals') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.hospitals') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Hospitals
                        </a>
                        <a href="{{ route('admin.users') }}" class="px-3 py-2 rounded-lg text-sm font-medium transition {{ request()->routeIs('admin.users') ? 'bg-teal-50 text-teal-700 border border-teal-200/60 shadow-xs' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100' }}">
                            Citizens
                        </a>
                    </nav>
                </div>

                <!-- Right Profile & Logout -->
                <div class="flex items-center space-x-4">
                    <!-- Staff User Info & Logout -->
                    <div class="flex items-center space-x-3">
                        <div class="hidden sm:block text-right">
                            <div class="text-sm font-semibold text-slate-800 leading-tight">
                                {{ session('admin_user.name', 'Central Commander') }}
                            </div>
                            <div class="text-xs text-slate-500">
                                {{ session('admin_user.role_name', 'Super Administrator') }}
                            </div>
                        </div>
                        <form action="{{ route('admin.logout') }}" method="POST" class="inline">
                            @csrf
                            <button type="submit" title="Terminate Session" class="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition border border-transparent hover:border-red-100">
                                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                                </svg>
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
    </header>

    <!-- Global Toast Alert Container -->
    <div id="toast-container" class="fixed top-20 right-6 z-50 flex flex-col space-y-2 pointer-events-none"></div>

    <!-- Flash Messages from Laravel Session -->
    <div class="w-full px-4 sm:px-6 lg:px-8 mt-4">
        @if(session('success'))
            <div class="p-4 mb-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm flex items-center justify-between shadow-xs">
                <div class="flex items-center space-x-3">
                    <svg class="w-5 h-5 text-emerald-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span class="font-medium">{{ session('success') }}</span>
                </div>
                <button onclick="this.parentElement.remove()" class="text-emerald-500 hover:text-emerald-700">&times;</button>
            </div>
        @endif

        @if(session('warning'))
            <div class="p-4 mb-3 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-sm flex items-center justify-between shadow-xs">
                <div class="flex items-center space-x-3">
                    <svg class="w-5 h-5 text-amber-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    <span class="font-medium">{{ session('warning') }}</span>
                </div>
                <button onclick="this.parentElement.remove()" class="text-amber-500 hover:text-amber-700">&times;</button>
            </div>
        @endif

        @if(session('error'))
            <div class="p-4 mb-3 rounded-xl bg-red-50 border border-red-200 text-red-800 text-sm flex items-center justify-between shadow-xs">
                <div class="flex items-center space-x-3">
                    <svg class="w-5 h-5 text-red-600 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span class="font-medium">{{ session('error') }}</span>
                </div>
                <button onclick="this.parentElement.remove()" class="text-red-500 hover:text-red-700">&times;</button>
            </div>
        @endif
    </div>

    <!-- Main Edge-to-Edge Clinical Body -->
    <main class="flex-1 w-full px-4 sm:px-6 lg:px-8 py-6">
        @yield('content')
    </main>

    <!-- Footer -->
    <footer class="bg-white border-t border-slate-200 py-4 w-full text-xs text-slate-500">
        <div class="w-full px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-2">
            <div>
                &copy; {{ date('Y') }} LifeRoute Central Command &bull; Powered by Laravel {{ app()->version() }} &bull; PHP {{ phpversion() }} &bull; MySQL
            </div>
            <div class="flex items-center space-x-4">
                <span>Disaster Management Network</span>
                <span>Hospital 108 Emergency Grid</span>
            </div>
        </div>
    </footer>

    <!-- Real-Time WebSocket Listener Script -->
    <script>
        function showNotification(title, message, type = 'info') {
            const container = document.getElementById('toast-container');
            if (!container) return;

            const toast = document.createElement('div');
            toast.className = `pointer-events-auto p-4 rounded-xl shadow-lg border text-sm flex items-start space-x-3 transition-all duration-300 transform translate-x-5 opacity-0 ${
                type === 'emergency' ? 'bg-red-50 border-red-200 text-red-900' :
                type === 'success' ? 'bg-emerald-50 border-emerald-200 text-emerald-900' :
                'bg-blue-50 border-blue-200 text-blue-900'
            }`;

            toast.innerHTML = `
                <div class="shrink-0 mt-0.5">
                    ${type === 'emergency' ? '<span class="relative flex h-3 w-3"><span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span><span class="relative inline-flex rounded-full h-3 w-3 bg-red-600"></span></span>' : 'ℹ️'}
                </div>
                <div class="flex-1">
                    <div class="font-bold">${title}</div>
                    <div class="text-xs mt-0.5 text-slate-600">${message}</div>
                </div>
            `;

            container.appendChild(toast);
            setTimeout(() => {
                toast.classList.remove('translate-x-5', 'opacity-0');
            }, 50);

            setTimeout(() => {
                toast.classList.add('opacity-0', 'translate-x-5');
                setTimeout(() => toast.remove(), 300);
            }, 6000);
        }

        // Connect to Laravel WebSocket Daemon
        (function initWebSocket() {
            const wsBadge = document.getElementById('ws-status-badge');
            const wsText = document.getElementById('ws-status-text');
            const host = window.location.hostname || 'localhost';
            const wsUrl = 'ws://' + host + ':8080';

            try {
                const socket = new WebSocket(wsUrl);

                socket.onopen = () => {
                    console.log('Central Command connected to Laravel WebSocket server:', wsUrl);
                    if (wsBadge) {
                        wsBadge.className = 'hidden sm:flex items-center space-x-2 px-3 py-1.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200';
                        if (wsText) wsText.innerText = 'WS LIVE (8080)';
                    }
                };

                socket.onmessage = (event) => {
                    try {
                        const data = JSON.parse(event.data);
                        const eventName = data.event || '';
                        const payload = data.data ? (typeof data.data === 'string' ? JSON.parse(data.data) : data.data) : {};

                        if (eventName.includes('NewEmergency') || eventName.includes('BookingCreated')) {
                            showNotification('CRITICAL EMERGENCY DISPATCH', `Booking ${payload.booking_reference || ''} initiated for ${payload.patient_name || 'Emergency Patient'}`, 'emergency');
                        } else if (eventName.includes('TripCancelled') || eventName.includes('BookingCancelled')) {
                            showNotification('TRIP CANCELLED', `Trip ${payload.booking_reference || ''} was cancelled.`, 'emergency');
                        } else if (eventName.includes('BookingAccepted')) {
                            showNotification('AMBULANCE DISPATCHED', `Ambulance assigned to ${payload.booking_reference || ''}`, 'success');
                        }
                    } catch (e) {
                        console.debug('Raw WS ping:', event.data);
                    }
                };

                socket.onerror = () => {
                    if (wsBadge) {
                        wsBadge.className = 'hidden sm:flex items-center space-x-2 px-3 py-1.5 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200';
                        if (wsText) wsText.innerText = 'POLLING ACTIVE';
                    }
                };

                socket.onclose = () => {
                    setTimeout(initWebSocket, 5000);
                };
            } catch (err) {
                console.warn('WebSocket init error:', err);
            }
        })();
    </script>

    @stack('scripts')
</body>
</html>

