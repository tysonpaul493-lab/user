# LifeRoute — Emergency Ambulance Booking System (User App & Backend)

This repository contains the complete **User Frontend (Flutter Web & Mobile)** and the **Backend (Laravel API, MySQL & WebSockets)**.

```
ambulance-user/
├── frontend/    # Cross-platform Flutter application (Web & Android/iOS)
├── backend/     # Laravel 12 (PHP 8.2) REST API, Ratchet WebSocket Server & MySQL schemas
├── vercel.json  # Vercel deployment configuration for Flutter Web
└── package.json # Root build configuration for CI/CD deployment
```

---

## 🌐 Deploying to Vercel (Frontend)

Vercel is designed for **static frontends and serverless apps**. It hosts the Flutter Web user app smoothly.

### How it builds on Vercel:
When you connect this repository to Vercel, `vercel.json` automatically:
1. Clones Flutter SDK (`stable`).
2. Enables Flutter Web.
3. Compiles the Flutter web application: `cd frontend && flutter build web --release`.
4. Deploys the output directory: `frontend/build/web`.
5. Rewrites all routes to `index.html` for single-page routing.

### Vercel Project Settings:
- **Framework Preset**: `Other`
- **Root Directory**: `./` (leave default)
- **Build Command**: auto-configured by `vercel.json`
- **Output Directory**: `frontend/build/web`

---

## 🚑 Backend Architecture & Hosting

> **Important**: Vercel only hosts static frontends and serverless functions. Persistent long-running services (**MySQL 3306**, **Laravel HTTP 8000**, and **WebSocket daemon 8080**) must run on a standard server, VPS, or cloud platform (e.g. Railway, Render, Fly.io, DigitalOcean, AWS EC2, or your local machine with ngrok/Cloudflare Tunnel).

### Running Backend Locally:
```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed

# 1. Start WebSocket Daemon:
php artisan websocket:serve --host=0.0.0.0 --port=8080

# 2. Start HTTP API:
php artisan serve --host=0.0.0.0 --port=8000
```

---

## 📱 Running Frontend Locally

### Web:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

### Android:
```bash
cd frontend
flutter run -d <device_id> --dart-define=DEFAULT_LAN_HOST=<your_backend_ip>
```
