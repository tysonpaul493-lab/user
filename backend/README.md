# LifeRoute Emergency — Backend API & WebSocket Server

Backend service providing REST API and real-time WebSocket communication for the LifeRoute Emergency Ambulance Booking system.

## 🚀 Getting Started

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment (Optional)
The default configuration runs on port `8000` and WebSocket port `8080`. To customize, check `.env`.

### 3. Start the Server
```bash
# Production mode
npm start

# Development mode (with auto-reload)
npm run dev
```

Server endpoints:
- **REST API Base URL**: `http://localhost:8000/api`
- **WebSocket URL**: `ws://localhost:8080`

---

## 📡 Key API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health` | Health check endpoint |
| `POST` | `/api/auth/otp/send` | Request 6-digit SMS OTP |
| `POST` | `/api/auth/otp/verify` | Verify OTP & receive Sanctum bearer token |
| `POST` | `/api/bookings` | Create ambulance dispatch request |
| `GET` | `/api/bookings/:id` | Get live booking status & assigned driver |
| `POST` | `/api/bookings/:id/cancel` | Cancel an active ambulance booking |
| `PUT` | `/api/user/profile` | Update user emergency profile |
| `GET` | `/api/hospitals/nearby` | Query emergency hospitals by GPS coordinates |
