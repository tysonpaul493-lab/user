# LifeRoute — Emergency Ambulance Booking System

This repository is organized into dedicated **Frontend** and **Backend** directories:

```
liferoute emergency user/
├── frontend/    # Cross-platform Flutter mobile application
└── backend/     # Laravel 12 (PHP 8.2) REST API, Ratchet WebSocket Server & MySQL persistence
```

---

## 📱 Frontend (Flutter Mobile App)

Built with Flutter 3.x / Dart, Riverpod, CartoDB/OSM maps, real-time GPS tracking, and multi-language support (English & Tamil).

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🚑 Backend (Laravel PHP + MySQL + WebSockets)

Built with Laravel 12 (PHP 8.2), MySQL (`liferoute`), and Ratchet RFC6455 WebSockets (`php artisan websocket:serve`) for live emergency dispatch and driver coordinates.

```bash
cd backend
php artisan migrate --seed
php artisan websocket:serve --host=0.0.0.0 --port=8080
php artisan serve --host=0.0.0.0 --port=8000
```
