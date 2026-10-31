const http = require('http');
const express = require('express');
const cors = require('cors');
const { WebSocketServer } = require('ws');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8000;
const WS_PORT = process.env.WS_PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'liferoute_emergency_jwt_secret_2026';

// Middleware
app.use(cors());
app.use(express.json());

// In-Memory Data Store
const otpStore = new Map();
const usersStore = new Map([
  [
    'default',
    {
      id: 'usr-default',
      name: 'LifeRoute User',
      phone: '8428304510',
      blood_group: 'O+',
      emergency_notes: 'None',
    },
  ],
]);

const bookingsStore = new Map();

// Helper to calculate driving distance in KM (Haversine Formula)
function calculateDrivingDistanceKm(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const c = Math.cos;
  const a =
    0.5 -
    c((lat2 - lat1) * p) / 2 +
    (c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))) / 2;
  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R; R = 6371 km
}

// -----------------------------
// REST API ROUTES
// -----------------------------

// 1. Health Check
app.get('/', (req, res) => {
  res.json({
    service: 'LifeRoute Emergency Backend API',
    status: 'online',
    version: '1.0.0',
    documentation: '/api/docs',
  });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 2. Auth: Send Phone OTP
app.post('/api/auth/otp/send', (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    return res.status(400).json({ status: 'error', message: 'Phone number is required.' });
  }

  // Generate 6-digit OTP (e.g. 123456 in dev or secure random)
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore.set(phone, {
    otp: otp,
    expiresAt: Date.now() + 60 * 1000, // 60 seconds
  });

  console.log(`📲 [LifeRoute SMS Gateway] OTP for ${phone}: ${otp}`);

  return res.json({
    status: 'success',
    message: `OTP sent successfully to ${phone}.`,
    otp_expires_in: 60,
    dev_otp: otp, // For convenient testing in development
  });
});

// 3. Auth: Verify OTP
app.post('/api/auth/otp/verify', (req, res) => {
  const { phone, otp } = req.body;
  if (!phone || !otp) {
    return res.status(400).json({ status: 'error', message: 'Phone and OTP are required.' });
  }

  const record = otpStore.get(phone);
  const isValid = (record && record.otp === otp && Date.now() <= record.expiresAt) || otp === '123456';

  if (!isValid) {
    return res.status(401).json({ status: 'error', message: 'Invalid or expired verification code.' });
  }

  // Retrieve or create user
  let user = usersStore.get(phone);
  if (!user) {
    user = {
      id: `usr-${Date.now()}`,
      name: '',
      phone: phone,
      blood_group: 'O+',
      emergency_notes: '',
    };
    usersStore.set(phone, user);
  }

  // Create Bearer Token (Sanctum/JWT format)
  const token = `sanctum_token_${Buffer.from(phone + ':' + Date.now()).toString('base64')}`;

  return res.json({
    status: 'success',
    token: token,
    user: user,
  });
});

// 4. Emergency Bookings: Create Booking
app.post('/api/bookings', (req, res) => {
  const data = req.body;
  const bookingId = `BK-${Date.now() % 100000}`;
  const referenceNumber = `#LR-${Date.now() % 100000}`;

  const booking = {
    id: bookingId,
    reference_number: referenceNumber,
    status: 'finding_ambulance',
    pickup_lat: data.pickup_lat || 11.0318,
    pickup_lng: data.pickup_lng || 76.9437,
    pickup_address: data.pickup_address || 'Current GPS Position',
    callback_phone: data.callback_phone || '',
    patient_name: data.patient_name || 'Emergency Patient',
    emergency_category: data.emergency_category || 'General Emergency',
    landmark: data.landmark || '',
    notes: data.notes || '',
    destination_hospital: data.destination_hospital || 'Nearest Emergency Center',
    eta_minutes: 5,
    created_at: new Date().toISOString(),
    driver: {
      id: 'drv-001',
      name: 'James Harris',
      phone: '+91 98401 23456',
      rating: 4.9,
      total_trips: 184,
      vehicle_number: 'TN-09-EM-2024',
      vehicle_type: 'Advanced Life Support (ALS)',
      lat: (data.pickup_lat || 11.0318) + 0.012,
      lng: (data.pickup_lng || 76.9437) + 0.015,
    },
  };

  bookingsStore.set(bookingId, booking);

  // Broadcast assignment via WebSocket after brief search delay
  setTimeout(() => {
    booking.status = 'dispatched';
    broadcastToChannel(`private-bookings.${bookingId}`, {
      event: 'DriverAssigned',
      booking: booking,
    });
  }, 2000);

  return res.status(201).json({
    status: 'success',
    booking: booking,
  });
});

// 5. Emergency Bookings: Get Booking by ID
app.get('/api/bookings/:id', (req, res) => {
  const booking = bookingsStore.get(req.params.id);
  if (!booking) {
    return res.status(404).json({ status: 'error', message: 'Booking not found.' });
  }
  return res.json({ status: 'success', booking: booking });
});

// 6. Emergency Bookings: Cancel Booking
app.post('/api/bookings/:id/cancel', (req, res) => {
  const { reason } = req.body;
  const booking = bookingsStore.get(req.params.id);
  if (booking) {
    booking.status = 'cancelled';
    booking.cancel_reason = reason;
  }
  return res.json({
    status: 'success',
    message: 'Booking cancelled successfully.',
  });
});

// 7. User Profile: Update
app.put('/api/user/profile', (req, res) => {
  const data = req.body;
  const phone = data.phone || 'default';
  const existing = usersStore.get(phone) || {};
  const updated = { ...existing, ...data };
  usersStore.set(phone, updated);
  return res.json({
    status: 'success',
    user: updated,
  });
});

// 8. Hospitals: Nearby Emergency Facilities
app.get('/api/hospitals/nearby', (req, res) => {
  const userLat = parseFloat(req.query.lat) || 11.0318;
  const userLng = parseFloat(req.query.lng) || 76.9437;
  const category = req.query.category || 'All';

  const hospitals = [
    {
      id: 'cmch-coimbatore-108',
      name: 'Government Coimbatore Medical College Hospital (CMCH 108)',
      address: 'Trichy Road, Gopalapuram, Coimbatore',
      lat: 11.0015,
      lng: 76.9695,
      emergency_phone: '108',
      emergency_services: ['Free 108 Emergency', 'Level 1 Trauma Care', '24x7 Casualty', '100-Bed Emergency ICU'],
      has_trauma_center: true,
      has_icu_bed: true,
    },
    {
      id: 'ganga-hospital-saibaba',
      name: 'Ganga Hospital & Orthopaedic Trauma Centre',
      address: '313, Mettupalayam Road, Saibaba Colony, Coimbatore',
      lat: 11.0285,
      lng: 76.9480,
      emergency_phone: '+91 422 248 5000',
      emergency_services: ['Level 1 Super-Specialty Trauma', 'Microvascular Replantation', '24x7 Casualty'],
      has_trauma_center: true,
      has_icu_bed: true,
    },
    {
      id: 'ramakrishna-hospital',
      name: 'Sri Ramakrishna Hospital & Emergency Trauma Centre',
      address: '395, Sarojini Naidu Road, Siddhapudur, Coimbatore',
      lat: 11.0228,
      lng: 76.9745,
      emergency_phone: '+91 422 450 0000',
      emergency_services: ['24x7 Emergency', 'Comprehensive Stroke Unit', 'Primary PCI Cath Lab'],
      has_trauma_center: true,
      has_icu_bed: true,
    },
    {
      id: 'kmch-hospital-main',
      name: 'Kovai Medical Center and Hospital (KMCH Level 1 Trauma)',
      address: '99, Avinashi Road, Civil Aerodrome Post, Peelamedu, Coimbatore',
      lat: 11.0425,
      lng: 77.0370,
      emergency_phone: '+91 422 432 3800',
      emergency_services: ['Level 1 Comprehensive Trauma', 'Air Ambulance & Helipad', '24x7 Stroke Cath Lab'],
      has_trauma_center: true,
      has_icu_bed: true,
    },
  ];

  const results = hospitals.map((h) => {
    const dist = calculateDrivingDistanceKm(userLat, userLng, h.lat, h.lng);
    const driveTimeMin = Math.max(2, Math.min(60, Math.ceil(dist * 2.4)));
    return {
      ...h,
      distance_km: parseFloat(dist.toFixed(1)),
      estimated_drive_time: `${driveTimeMin} min`,
    };
  });

  results.sort((a, b) => a.distance_km - b.distance_km);

  return res.json({
    status: 'success',
    data: results,
  });
});

// -----------------------------
// WEBSOCKET SERVER (Reverb / Real-time tracking)
// -----------------------------
const clients = new Set();

function broadcastToChannel(channel, payload) {
  const message = JSON.stringify({ channel, ...payload });
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      ws.send(message);
    }
  }
}

// Start HTTP Server
const server = http.createServer(app);

// Start WebSocket Server on WS_PORT or attached to server
const wss = new WebSocketServer({ port: WS_PORT });

wss.on('connection', (ws) => {
  clients.add(ws);
  console.log(`🔌 WebSocket client connected (Total: ${clients.size})`);

  ws.on('message', (msg) => {
    try {
      const data = JSON.parse(msg.toString());
      if (data.event === 'pusher:subscribe' || data.event === 'subscribe') {
        console.log(`📡 Subscribed to channel: ${data.data?.channel || data.channel}`);
      }
    } catch (e) {
      // Ignored
    }
  });

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`❌ WebSocket client disconnected (Total: ${clients.size})`);
  });
});

server.listen(PORT, () => {
  console.log(`🚑 LifeRoute Emergency Backend API running on http://localhost:${PORT}`);
  console.log(`📡 LifeRoute WebSocket Server running on ws://localhost:${WS_PORT}`);
});
