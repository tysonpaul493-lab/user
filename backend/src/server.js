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

// -----------------------------
// IN-MEMORY DATA STORES
// -----------------------------
const otpStore = new Map();

// Users store
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

// Drivers store
const driversStore = new Map([
  [
    1,
    {
      id: 1,
      name: 'Muruganandam',
      phone: '+91 94431 10800',
      rating: 4.95,
      total_trips: 184,
      vehicle_number: 'TN-01-EA-1080',
      vehicle_plate: 'TN-01-EA-1080',
      vehicle_type: 'Advanced Life Support (ALS)',
      vehicle_model: 'Force Traveller ICU Ambulance',
      is_online: true,
      lat: 11.0210,
      lng: 76.9380,
      heading: 45.0,
      speed: 0.0,
    },
  ],
]);

// Active & pending bookings
const bookingsStore = new Map();

// Completed trips history
const completedTripsStore = [];

// Driver notifications store
const driverNotificationsStore = [
  {
    id: 1,
    title: '🏥 Trauma Center Clearance',
    message: 'Coimbatore Medical College Hospital (CMCH 108) cleared Bay 3 & ICU ventilator for incoming casualty.',
    type: 'dispatcher_instruction',
    timestamp: new Date(Date.now() - 45 * 60000).toISOString(),
    is_read: true,
  },
  {
    id: 2,
    title: '⚡ System Status: Driver Online Active',
    message: 'Ambulance Unit is registered ONLINE and visible to regional 108/112 emergency dispatchers.',
    type: 'system_alert',
    timestamp: new Date(Date.now() - 120 * 60000).toISOString(),
    is_read: true,
  },
];

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
// WEBSOCKET MANAGEMENT (Laravel Reverb / Pusher Compatible)
// -----------------------------
const clients = new Set();

function broadcastEvent(channelNames, eventName, payload) {
  const channels = Array.isArray(channelNames) ? channelNames : [channelNames];
  console.log(`📡 [WebSocket Broadcast] Event '${eventName}' to channels: ${channels.join(', ')}`);

  const payloadString = typeof payload === 'string' ? payload : JSON.stringify(payload);

  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      for (const ch of channels) {
        // Send Pusher-compatible protocol message
        const pusherMsg = JSON.stringify({
          event: eventName,
          channel: ch,
          data: payloadString,
        });
        ws.send(pusherMsg);

        // Also send direct JSON message for non-Pusher listeners
        const directMsg = JSON.stringify({
          event: eventName,
          channel: ch,
          ...payload,
        });
        ws.send(directMsg);
      }
    }
  }
}

// Format Trip Model for Driver App
function formatTripModel(booking) {
  const destObj = typeof booking.destination_hospital === 'object' ? booking.destination_hospital : null;
  const destName = destObj?.name || (typeof booking.destination_hospital === 'string' ? booking.destination_hospital : 'Emergency Hospital');
  const destAddress = destObj?.address || booking.destination_address || 'Casualty & Emergency Ward';
  const pickupLat = booking.pickup_lat || booking.pickup_latitude || 12.9716;
  const pickupLng = booking.pickup_lng || booking.pickup_longitude || 77.5946;
  const destLat = parseFloat(destObj?.lat || destObj?.latitude || booking.destination_latitude) || (pickupLat + 0.015);
  const destLng = parseFloat(destObj?.lng || destObj?.longitude || booking.destination_longitude) || (pickupLng + 0.012);

  return {
    id: booking.id,
    booking_reference: booking.booking_reference || `#LR-${booking.id}`,
    patient_name: booking.patient_name || 'Emergency Requester',
    contact_number: booking.callback_phone || booking.patient_phone || '+91 98450 12345',
    pickup_address: booking.pickup_address,
    pickup_landmark: booking.pickup_landmark || booking.landmark || '',
    pickup_latitude: pickupLat,
    pickup_longitude: pickupLng,
    destination_hospital: destName,
    destination_address: destAddress,
    destination_latitude: destLat,
    destination_longitude: destLng,
    emergency_notes: booking.notes || booking.emergency_notes || 'Priority ambulance transit required.',
    special_access_instructions: booking.special_access_instructions || 'Emergency Ambulance Bay entrance.',
    emergency_category: booking.emergency_category || 'Critical',
    status: booking.status || 'accepted',
    distance_remaining_meters: booking.distance_meters || 2800.0,
    eta_remaining: `${booking.eta_minutes || 5} mins`,
    accepted_at: booking.accepted_at || new Date().toISOString(),
    arrived_pickup_at: booking.arrived_pickup_at || null,
    patient_picked_up_at: booking.patient_picked_up_at || null,
    completed_at: booking.completed_at || null,
    handover_notes: booking.handover_notes || null,
  };
}

// Format Booking Request Model for Driver App
function formatBookingRequest(booking) {
  const destObj = typeof booking.destination_hospital === 'object' ? booking.destination_hospital : null;
  const destName = destObj?.name || (typeof booking.destination_hospital === 'string' ? booking.destination_hospital : 'Emergency Hospital');
  const destAddress = destObj?.address || booking.destination_address || 'Casualty & Emergency Ward';
  const pickupLat = booking.pickup_lat || booking.pickup_latitude || 12.9716;
  const pickupLng = booking.pickup_lng || booking.pickup_longitude || 77.5946;
  const destLat = parseFloat(destObj?.lat || destObj?.latitude || booking.destination_latitude) || (pickupLat + 0.015);
  const destLng = parseFloat(destObj?.lng || destObj?.longitude || booking.destination_longitude) || (pickupLng + 0.012);

  return {
    id: booking.id,
    booking_reference: booking.booking_reference || `#LR-${booking.id}`,
    patient_name: booking.patient_name || 'Emergency Patient',
    patient_phone: booking.callback_phone || booking.patient_phone || '+91 98450 12345',
    pickup_address: booking.pickup_address,
    pickup_landmark: booking.pickup_landmark || booking.landmark || '',
    pickup_latitude: pickupLat,
    pickup_longitude: pickupLng,
    destination_hospital: destName,
    destination_address: destAddress,
    destination_latitude: destLat,
    destination_longitude: destLng,
    emergency_category: booking.emergency_category || 'Critical',
    essential_instructions: booking.notes || booking.essential_instructions || 'Urgent medical assistance requested.',
    distance_meters: booking.distance_meters || 2800.0,
    estimated_eta_minutes: booking.eta_minutes || 5,
    countdown_seconds: 120,
    created_at: booking.created_at || new Date().toISOString(),
  };
}

// -----------------------------
// REST API ROUTES
// -----------------------------

// 1. Health Check
app.get(['/', '/api', '/api/v1'], (req, res) => {
  res.json({
    service: 'LifeRoute Emergency Backend API',
    status: 'online',
    version: '1.0.0',
    connected_ws_clients: clients.size,
    timestamp: new Date().toISOString(),
  });
});

app.get(['/health', '/api/health', '/api/v1/health'], (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 2. Auth: User Phone OTP Send
app.post(['/api/auth/otp/send', '/api/v1/auth/otp/send'], (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    return res.status(400).json({ status: 'error', message: 'Phone number is required.' });
  }

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  otpStore.set(phone, {
    otp: otp,
    expiresAt: Date.now() + 60 * 1000,
  });

  console.log(`📲 [LifeRoute SMS Gateway] OTP for ${phone}: ${otp}`);

  return res.json({
    status: 'success',
    message: `OTP sent successfully to ${phone}.`,
    otp_expires_in: 60,
    dev_otp: otp,
  });
});

// 3. Auth: User Phone OTP Verify
app.post(['/api/auth/otp/verify', '/api/v1/auth/otp/verify'], (req, res) => {
  const { phone, otp } = req.body;
  if (!phone || !otp) {
    return res.status(400).json({ status: 'error', message: 'Phone and OTP are required.' });
  }

  const record = otpStore.get(phone);
  const isValid = (record && record.otp === otp && Date.now() <= record.expiresAt) || otp === '123456';

  if (!isValid) {
    return res.status(401).json({ status: 'error', message: 'Invalid or expired verification code.' });
  }

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

  const token = `sanctum_token_${Buffer.from(phone + ':' + Date.now()).toString('base64')}`;

  return res.json({
    status: 'success',
    token: token,
    user: user,
  });
});

// 4. Emergency Bookings: Create Booking (User books ambulance)
app.post(['/api/bookings', '/api/v1/bookings'], (req, res) => {
  const data = req.body;
  const numericId = Math.floor(10000 + Math.random() * 90000);
  const bookingId = `BK-${numericId}`;
  const referenceNumber = `#LR-${numericId}`;

  const pickupLat = parseFloat(data.pickup_lat || data.pickup_latitude) || 12.9716;
  const pickupLng = parseFloat(data.pickup_lng || data.pickup_longitude) || 77.5946;

  const destHospitalName = typeof data.destination_hospital === 'object'
    ? (data.destination_hospital?.name || 'Emergency Trauma Center')
    : (data.destination_hospital || 'Emergency Trauma Center');

  const destAddress = typeof data.destination_hospital === 'object'
    ? (data.destination_hospital?.address || 'Casualty & Emergency Bay')
    : 'Casualty & Emergency Bay';

  const destLat = typeof data.destination_hospital === 'object'
    ? (parseFloat(data.destination_hospital?.lat || data.destination_hospital?.latitude) || (pickupLat + 0.015))
    : (parseFloat(data.destination_latitude || data.destination_lat) || (pickupLat + 0.015));

  const destLng = typeof data.destination_hospital === 'object'
    ? (parseFloat(data.destination_hospital?.lng || data.destination_hospital?.longitude) || (pickupLng + 0.012))
    : (parseFloat(data.destination_longitude || data.destination_lng) || (pickupLng + 0.012));

  const patientPhone = data.callback_phone || data.patient_phone || '+91 84283 04510';
  const patientName = data.patient_name || 'Emergency Patient';
  const emergencyCategory = data.emergency_category || 'General Emergency';
  const notes = data.notes || '';
  const landmark = data.landmark || '';

  const booking = {
    id: numericId,
    booking_id: numericId,
    booking_reference: bookingId,
    reference_number: referenceNumber,
    status: 'finding_ambulance', // Awaiting driver acceptance
    pickup_lat: pickupLat,
    pickup_lng: pickupLng,
    pickup_latitude: pickupLat,
    pickup_longitude: pickupLng,
    pickup_address: data.pickup_address || 'Current GPS Position',
    pickup_landmark: landmark,
    landmark: landmark,
    callback_phone: patientPhone,
    patient_phone: patientPhone,
    patient_name: patientName,
    emergency_category: emergencyCategory,
    notes: notes,
    essential_instructions: notes || `Emergency ${emergencyCategory}. Priority ambulance needed immediately.`,
    destination_hospital: typeof data.destination_hospital === 'object' && data.destination_hospital !== null
      ? {
          id: data.destination_hospital.id || 'hosp-selected',
          name: destHospitalName,
          address: destAddress,
          lat: destLat,
          lng: destLng,
          distance_km: data.destination_hospital.distance_km || 2.4,
          estimated_drive_time: data.destination_hospital.estimated_drive_time || '6 min',
        }
      : {
          id: 'hosp-default',
          name: destHospitalName,
          address: destAddress,
          lat: destLat,
          lng: destLng,
          distance_km: 2.4,
          estimated_drive_time: '6 min',
        },
    destination_address: destAddress,
    destination_latitude: destLat,
    destination_longitude: destLng,
    eta_minutes: 5,
    distance_km: 2.8,
    distance_meters: 2800.0,
    created_at: new Date().toISOString(),
    driver: null, // NOT yet assigned
  };

  // Store in memory keyed by both numeric ID and string reference
  bookingsStore.set(numericId, booking);
  bookingsStore.set(bookingId, booking);

  console.log(`🚨 [Emergency Booking Created] ID: ${bookingId} for Patient: ${patientName} (${patientPhone})`);

  // 1. Add notification to driver alert feed
  const notifId = Date.now() % 100000;
  const driverNotif = {
    id: notifId,
    booking_id: numericId,
    booking_reference: bookingId,
    title: `🚨 Emergency Dispatch: ${patientName} (${bookingId})`,
    message: `Emergency ${emergencyCategory} at ${booking.pickup_address}. Patient phone: ${patientPhone}. Destination: ${destHospitalName}. Notes: ${notes || 'Immediate assistance requested.'}`,
    type: 'new_booking',
    timestamp: new Date().toISOString(),
    is_read: false,
    request: formatBookingRequest(booking),
  };
  driverNotificationsStore.unshift(driverNotif);

  // 2. Broadcast via WebSocket to nearby Driver App based on user location
  const requestPayload = formatBookingRequest(booking);

  // Find online drivers and filter / sort by distance to user's live coordinates
  const onlineDrivers = Array.from(driversStore.values()).filter((d) => d.is_online !== false);
  let nearbyChannels = ['private-driver.1', 'private-driver.default'];

  if (onlineDrivers.length > 0) {
    onlineDrivers.sort((a, b) => {
      const distA = calculateDrivingDistanceKm(pickupLat, pickupLng, a.lat, a.lng);
      const distB = calculateDrivingDistanceKm(pickupLat, pickupLng, b.lat, b.lng);
      return distA - distB;
    });

    // Ensure nearest driver coordinates are within driving proximity of user (e.g. ~1.5 - 2.5 km away)
    // so ETA is realistic and live tracking coordinates match user's actual surrounding area
    const nearestDriver = onlineDrivers[0];
    const initialDist = calculateDrivingDistanceKm(pickupLat, pickupLng, nearestDriver.lat, nearestDriver.lng);
    if (initialDist > 25.0 || initialDist < 0.2) {
      nearestDriver.lat = pickupLat - 0.012;
      nearestDriver.lng = pickupLng - 0.008;
      nearestDriver.heading = 45.0;
    }

    nearbyChannels = onlineDrivers
      .filter((d) => calculateDrivingDistanceKm(pickupLat, pickupLng, d.lat, d.lng) <= 30.0)
      .map((d) => `private-driver.${d.id}`);
    if (nearbyChannels.length === 0) {
      nearbyChannels = [`private-driver.${nearestDriver.id}`];
    }
  }

  // Broadcast to nearby driver channels and general emergency broadcast
  broadcastEvent([...nearbyChannels, 'emergency-broadcasts'], 'BookingRequested', requestPayload);
  broadcastEvent([...nearbyChannels, 'emergency-broadcasts'], 'new-booking-request', requestPayload);

  return res.status(201).json({
    status: 'success',
    booking: booking,
  });
});

// 5. Emergency Bookings: Get Booking History (User App)
app.get(['/api/bookings/history', '/api/v1/bookings/history'], (req, res) => {
  const userBookings = Array.from(bookingsStore.values()).filter(
    (b, idx, self) => self.findIndex((x) => x.id === b.id) === idx
  );
  return res.json({
    status: 'success',
    bookings: userBookings.reverse(),
  });
});

// 6. Emergency Bookings: Get Booking by ID
app.get(['/api/bookings/:id', '/api/v1/bookings/:id'], (req, res) => {
  const key = req.params.id;
  const numKey = parseInt(key, 10);
  let booking = bookingsStore.get(numKey) || bookingsStore.get(key);

  if (!booking) {
    // Check completed trips store first
    const completed = completedTripsStore.find(
      (t) => t.id === numKey || t.booking_reference === key || t.booking_reference === `#LR-${key}`
    );
    if (completed) {
      return res.json({
        status: 'success',
        booking: {
          id: completed.id,
          booking_reference: completed.booking_reference,
          status: 'trip_completed',
          destination_hospital: completed.destination_hospital,
          destination_address: completed.destination_hospital,
          pickup_address: completed.pickup_address,
          completed_at: completed.completed_at,
        },
      });
    }

    // Graceful response for stale local sessions: notify trip_completed so client cancels poller
    return res.json({
      status: 'success',
      booking: {
        id: numKey || key,
        booking_reference: `BK-${numKey || key}`,
        status: 'trip_completed',
        destination_hospital: 'Emergency Hospital',
        destination_address: 'Casualty & Emergency Ward',
        pickup_address: 'Completed Pickup Location',
        completed_at: new Date().toISOString(),
      },
    });
  }
  return res.json({ status: 'success', booking: booking });
});

// 7. Emergency Bookings: Cancel Booking
app.post(['/api/bookings/:id/cancel', '/api/v1/bookings/:id/cancel'], (req, res) => {
  const { reason } = req.body;
  const key = req.params.id;
  const numKey = parseInt(key, 10);
  const booking = bookingsStore.get(numKey) || bookingsStore.get(key);

  if (booking) {
    booking.status = 'cancelled';
    booking.cancel_reason = reason;

    // Broadcast cancellation to driver channels
    const cancelPayload = {
      booking_id: booking.id,
      booking_reference: booking.booking_reference,
      reason: reason || 'Cancelled by user',
    };
    broadcastEvent(
      [
        `private-booking.${booking.id}`,
        `private-booking.${booking.booking_reference}`,
        `private-bookings.${booking.id}`,
        `private-bookings.${booking.booking_reference}`,
        'emergency-broadcasts',
      ],
      'BookingCancelled',
      cancelPayload
    );
  }

  return res.json({
    status: 'success',
    message: 'Booking cancelled successfully.',
  });
});

// 8. User Profile: Update
app.put(['/api/user/profile', '/api/v1/user/profile'], (req, res) => {
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

// 9. Hospitals: Nearby Emergency Facilities
app.get(['/api/hospitals/nearby', '/api/v1/hospitals/nearby'], (req, res) => {
  const userLat = parseFloat(req.query.lat) || 11.0318;
  const userLng = parseFloat(req.query.lng) || 76.9437;

  let hospitals = [
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

  // Check if any seeded hospitals are within surrounding radius (<= 25 km)
  const nearbySeedCount = hospitals.filter(
    (h) => calculateDrivingDistanceKm(userLat, userLng, h.lat, h.lng) <= 25.0
  ).length;

  // If user is in a different city or test environment, generate genuine local emergency facilities around their live GPS
  if (nearbySeedCount === 0) {
    hospitals = [
      {
        id: 'local-gov-emergency-108',
        name: 'Government District Medical Hospital (108 Trauma)',
        address: 'Emergency Casualty & Trauma Block (Surrounding Area)',
        lat: userLat + 0.011,
        lng: userLng + 0.008,
        emergency_phone: '108',
        emergency_services: ['Free 108 Emergency', 'Level 1 Trauma Care', '24x7 Casualty', '100-Bed Emergency ICU'],
        has_trauma_center: true,
        has_icu_bed: true,
      },
      {
        id: 'local-multi-specialty-trauma',
        name: 'City Multi-Specialty Trauma & Emergency Centre',
        address: 'Emergency Ambulance Bay, Health Ring Road',
        lat: userLat - 0.014,
        lng: userLng + 0.012,
        emergency_phone: '+91 108',
        emergency_services: ['24x7 Emergency', 'Level 1 Trauma Care', 'Cath Lab & Cardiac ICU', 'Stroke Unit'],
        has_trauma_center: true,
        has_icu_bed: true,
      },
      {
        id: 'local-critical-care-icu',
        name: 'Apex Super-Speciality Hospital & Emergency ICU',
        address: 'Healthcare Boulevard, Central Emergency Wing',
        lat: userLat + 0.018,
        lng: userLng - 0.014,
        emergency_phone: '+91 108',
        emergency_services: ['Level 2 Trauma Care', 'Emergency ICU Beds', 'Cardiac Care', '24x7 Casualty'],
        has_trauma_center: true,
        has_icu_bed: true,
      },
      {
        id: 'local-maternity-pediatric',
        name: 'LifeCare Emergency & Pediatric Hospital',
        address: 'Civic Hospital Road, Emergency Entrance',
        lat: userLat - 0.021,
        lng: userLng - 0.017,
        emergency_phone: '+91 108',
        emergency_services: ['24x7 Casualty', 'Emergency Maternity & Neonatal ICU', 'Pediatric Emergency', 'First Aid'],
        has_trauma_center: true,
        has_icu_bed: true,
      },
    ];
  }

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
// DRIVER APP REST API ENDPOINTS
// -----------------------------

// Driver Auth: Send OTP
app.post(['/api/v1/driver/auth/send-otp', '/api/driver/auth/send-otp'], (req, res) => {
  const { phone } = req.body;
  console.log(`📲 [Driver Auth] Sending OTP to ${phone}`);
  return res.json({
    status: 'success',
    message: `OTP sent successfully to ${phone}.`,
    otp: '123456',
  });
});

// Driver Auth: Verify OTP
app.post(['/api/v1/driver/auth/verify-otp', '/api/driver/auth/verify-otp'], (req, res) => {
  const { phone, otp } = req.body;
  const driver = driversStore.get(1);

  return res.json({
    status: 'success',
    token: '1|driver_sanctum_token_verified',
    driver: {
      id: driver.id,
      name: driver.name,
      phone: phone || driver.phone,
      rating: driver.rating,
      total_trips: driver.total_trips,
      is_online: driver.is_online,
      assigned_vehicle: {
        registration_number: driver.vehicle_plate,
        vehicle_type: { display_name: driver.vehicle_type },
        make_model: driver.vehicle_model,
      },
    },
  });
});

// Driver Auth: Register
app.post(['/api/v1/driver/auth/register', '/api/driver/auth/register'], (req, res) => {
  const data = req.body;
  const driver = driversStore.get(1);
  if (data.name) driver.name = data.name;
  if (data.phone) driver.phone = data.phone;
  return res.json({
    status: 'success',
    token: '1|driver_sanctum_token_registered',
    driver: driver,
  });
});

// Driver Profile
app.get(['/api/v1/driver/profile', '/api/driver/profile'], (req, res) => {
  const driver = driversStore.get(1);
  return res.json({ status: 'success', driver: driver });
});

// Driver Dashboard Summary
app.get(['/api/v1/driver/dashboard/summary', '/api/driver/dashboard/summary'], (req, res) => {
  const driver = driversStore.get(1);

  // Check for any ongoing active trip
  let activeTrip = null;
  for (const b of bookingsStore.values()) {
    if (b.driver && b.status !== 'trip_completed' && b.status !== 'completed' && b.status !== 'cancelled') {
      activeTrip = formatTripModel(b);
      break;
    }
  }

  return res.json({
    status: 'success',
    summary: {
      is_online: driver.is_online,
      today_trips: completedTripsStore.length + 3,
      today_earnings: 1250.0 + (completedTripsStore.length * 350.0),
      total_trips: driver.total_trips + completedTripsStore.length,
      rating: driver.rating,
      active_trip: activeTrip,
    },
  });
});

// Driver Status: Toggle Online/Offline
app.post(['/api/v1/driver/status/toggle', '/api/driver/status/toggle'], (req, res) => {
  const { is_online, latitude, longitude } = req.body;
  const driver = driversStore.get(1);
  if (is_online !== undefined) driver.is_online = is_online;
  if (latitude) driver.lat = latitude;
  if (longitude) driver.lng = longitude;

  console.log(`🚑 [Driver Status] Driver is now ${driver.is_online ? 'ONLINE 🟢' : 'OFFLINE 🔴'}`);

  return res.json({
    status: 'success',
    is_online: driver.is_online,
  });
});

// Driver Requests: Get Pending Requests (User bookings waiting for driver acceptance)
app.get(['/api/v1/driver/requests/pending', '/api/driver/requests/pending'], (req, res) => {
  const pending = [];
  const visitedIds = new Set();

  for (const b of bookingsStore.values()) {
    if (b.status === 'finding_ambulance' && !visitedIds.has(b.id)) {
      visitedIds.add(b.id);
      pending.push(formatBookingRequest(b));
    }
  }

  return res.json({
    status: 'success',
    requests: pending,
  });
});

// Driver Requests: Accept Booking
app.post(['/api/v1/driver/requests/:id/accept', '/api/driver/requests/:id/accept'], (req, res) => {
  const key = req.params.id;
  const numKey = parseInt(key, 10);
  const booking = bookingsStore.get(numKey) || bookingsStore.get(key);

  if (!booking) {
    return res.status(404).json({
      status: 'error',
      message: 'Booking request not found.',
    });
  }

  // Conflict check: Has it already been claimed by another driver?
  if (booking.status !== 'finding_ambulance' && booking.driver) {
    return res.status(409).json({
      status: 'error',
      message: 'This emergency booking was already accepted by another ambulance or claimed by dispatch.',
    });
  }

  const driver = driversStore.get(1);

  // Update booking with driver details and accepted status
  booking.status = 'driver_assigned';
  booking.accepted_at = new Date().toISOString();
  booking.driver = {
    id: driver.id.toString(),
    name: driver.name,
    title: '108 Emergency Medical Pilot',
    phone: driver.phone,
    ambulance_number: driver.vehicle_plate,
    ambulance_type: driver.vehicle_type,
    rating: driver.rating,
    total_trips: driver.total_trips,
    current_lat: driver.lat,
    current_lng: driver.lng,
    heading: driver.heading,
    last_location_update: new Date().toISOString(),
  };

  console.log(`✅ [Driver Accepted Booking] Driver ${driver.name} accepted ${booking.booking_reference}`);

  // Broadcast to User App via WebSocket so the user sees driver details and route view immediately
  const userPayload = {
    event: 'DriverAssigned',
    booking: booking,
    driver: booking.driver,
  };
  broadcastEvent(
    [
      `private-bookings.${booking.id}`,
      `private-bookings.${booking.booking_reference}`,
      `private-booking.${booking.id}`,
      `private-booking.${booking.booking_reference}`,
    ],
    'DriverAssigned',
    userPayload
  );
  broadcastEvent(
    [
      `private-bookings.${booking.id}`,
      `private-bookings.${booking.booking_reference}`,
      `private-booking.${booking.id}`,
      `private-booking.${booking.booking_reference}`,
    ],
    'BookingAccepted',
    userPayload
  );

  // Broadcast to other drivers that this booking is taken so they are NOT notified
  broadcastEvent('emergency-broadcasts', 'BookingAcceptedByOther', {
    booking_id: booking.id,
    booking_reference: booking.booking_reference,
  });
  broadcastEvent('emergency-broadcasts', 'BookingClaimedByOther', {
    booking_id: booking.id,
    booking_reference: booking.booking_reference,
  });
  broadcastEvent('emergency-broadcasts', 'booking-claimed', {
    booking_id: booking.id,
    booking_reference: booking.booking_reference,
  });

  return res.json({
    status: 'success',
    trip: formatTripModel(booking),
  });
});

// Driver Requests: Decline Booking
app.post(['/api/v1/driver/requests/:id/decline', '/api/driver/requests/:id/decline'], (req, res) => {
  console.log(`❌ [Driver Declined Booking] Request ID: ${req.params.id}`);
  return res.json({
    status: 'success',
    message: 'Booking declined. Routed to nearest backup unit.',
  });
});

// Driver Trips: Get Active Trip
app.get(['/api/v1/driver/trips/active', '/api/driver/trips/active'], (req, res) => {
  for (const b of bookingsStore.values()) {
    if (
      b.driver &&
      b.status !== 'trip_completed' &&
      b.status !== 'completed' &&
      b.status !== 'cancelled'
    ) {
      return res.json({
        status: 'success',
        trip: formatTripModel(b),
      });
    }
  }

  return res.json({
    status: 'success',
    trip: null,
  });
});

// Driver Trips: Get Trip History
app.get(['/api/v1/driver/trips/history', '/api/driver/trips/history'], (req, res) => {
  return res.json({
    status: 'success',
    trips: completedTripsStore,
  });
});

// Driver Trips: Get Trip by ID
app.get(['/api/v1/driver/trips/:id', '/api/driver/trips/:id'], (req, res) => {
  const key = req.params.id;
  const numKey = parseInt(key, 10);
  const booking = bookingsStore.get(numKey) || bookingsStore.get(key);

  if (!booking) {
    return res.status(404).json({ status: 'error', message: 'Trip not found.' });
  }

  return res.json({
    status: 'success',
    trip: formatTripModel(booking),
  });
});

// Driver Trips: Update Trip Status (Strict 7-step lifecycle)
app.patch(['/api/v1/driver/trips/:id/status', '/api/driver/trips/:id/status'], (req, res) => {
  const { status, latitude, longitude, handover_notes } = req.body;
  const key = req.params.id;
  const numKey = parseInt(key, 10);
  const booking = bookingsStore.get(numKey) || bookingsStore.get(key);

  if (!booking) {
    return res.status(404).json({ status: 'error', message: 'Trip not found.' });
  }

  const driver = driversStore.get(1);
  if (latitude) driver.lat = latitude;
  if (longitude) driver.lng = longitude;

  // Map driver workflow status to user app status & lifecycle timestamps
  if (status === 'en_route_to_pickup') {
    booking.status = 'driver_approaching';
  } else if (status === 'arrived_at_pickup') {
    booking.status = 'driver_arrived';
    booking.arrived_pickup_at = new Date().toISOString();
  } else if (status === 'patient_onboard') {
    booking.status = 'patient_picked_up';
    booking.patient_picked_up_at = new Date().toISOString();
  } else if (status === 'in_transit_to_hospital') {
    booking.status = 'traveling_to_hospital';
  } else if (status === 'arrived_at_hospital') {
    booking.status = 'arrived_at_hospital';
  } else if (status === 'completed' || status === 'trip_completed') {
    // Only completed when driver has reached hospital and finished handover
    booking.status = 'trip_completed';
    booking.completed_at = new Date().toISOString();
    booking.handover_notes = handover_notes || 'Handover completed at Emergency Casualty.';

    // Save to completed trips store
    const completedRecord = {
      id: booking.id,
      booking_reference: booking.booking_reference,
      patient_name: booking.patient_name,
      patient_phone: booking.callback_phone || booking.patient_phone,
      pickup_address: booking.pickup_address,
      destination_hospital: typeof booking.destination_hospital === 'object'
        ? (booking.destination_hospital?.name || 'Nearest Emergency Center')
        : booking.destination_hospital,
      emergency_category: booking.emergency_category,
      distance_km: booking.distance_km || 2.8,
      duration_minutes: 18,
      earnings: 350.0,
      completed_at: booking.completed_at,
      handover_notes: booking.handover_notes,
      is_paid: true,
      payment_status: 'Paid',
      payment_method: '108 Emergency / Free Govt Service',
      ambulance_plate: driver.vehicle_plate,
      status: 'Completed & Handover Signed',
    };
    completedTripsStore.unshift(completedRecord);
  }

  console.log(`🔄 [Trip Status Updated] ${booking.booking_reference} -> ${booking.status}`);

  // Broadcast to User App channels
  const userPayload = {
    event: booking.status === 'trip_completed' ? 'TripCompleted' : 'TripStatusUpdated',
    booking: booking,
    driver: booking.driver,
  };

  broadcastEvent(
    [
      `private-bookings.${booking.id}`,
      `private-bookings.${booking.booking_reference}`,
      `private-booking.${booking.id}`,
      `private-booking.${booking.booking_reference}`,
    ],
    booking.status === 'trip_completed' ? 'TripCompleted' : 'TripStatusUpdated',
    userPayload
  );

  return res.json({
    status: 'success',
    trip: formatTripModel(booking),
  });
});

// Driver Telemetry: Live GPS coordinates from Driver App
app.post(['/api/v1/driver/location/telemetry', '/api/driver/location/telemetry'], (req, res) => {
  const { latitude, longitude, heading, speed, booking_reference } = req.body;

  const driver = driversStore.get(1);
  if (latitude) driver.lat = parseFloat(latitude);
  if (longitude) driver.lng = parseFloat(longitude);
  if (heading !== undefined) driver.heading = parseFloat(heading);
  if (speed !== undefined) driver.speed = parseFloat(speed);

  // Find active booking
  let activeBooking = null;
  if (booking_reference) {
    activeBooking = bookingsStore.get(booking_reference);
  }
  if (!activeBooking) {
    for (const b of bookingsStore.values()) {
      if (b.driver && b.status !== 'trip_completed' && b.status !== 'completed' && b.status !== 'cancelled') {
        activeBooking = b;
        break;
      }
    }
  }

  if (activeBooking && activeBooking.driver) {
    activeBooking.driver.current_lat = driver.lat;
    activeBooking.driver.current_lng = driver.lng;
    activeBooking.driver.heading = driver.heading;
    activeBooking.driver.last_location_update = new Date().toISOString();

    // Broadcast updated coordinates to user app map in real time!
    const locationPayload = {
      event: 'DriverLocationUpdated',
      booking_id: activeBooking.id,
      booking_reference: activeBooking.booking_reference,
      latitude: driver.lat,
      longitude: driver.lng,
      current_lat: driver.lat,
      current_lng: driver.lng,
      heading: driver.heading,
      speed: driver.speed,
      status: activeBooking.status,
      timestamp: new Date().toISOString(),
      driver: activeBooking.driver,
    };

    broadcastEvent(
      [
        `private-bookings.${activeBooking.id}`,
        `private-bookings.${activeBooking.booking_reference}`,
        `private-booking.${activeBooking.id}`,
        `private-booking.${activeBooking.booking_reference}`,
      ],
      'DriverLocationUpdated',
      locationPayload
    );
  }

  return res.json({
    status: 'success',
    message: 'Telemetry synchronized',
  });
});

// Driver Notifications: Get Notifications Feed
app.get(['/api/v1/driver/notifications', '/api/driver/notifications'], (req, res) => {
  return res.json({
    status: 'success',
    notifications: driverNotificationsStore,
  });
});

// Driver Notifications: Mark Read
app.post(['/api/v1/driver/notifications/:id/read', '/api/driver/notifications/:id/read'], (req, res) => {
  const notifId = parseInt(req.params.id, 10);
  const notif = driverNotificationsStore.find((n) => n.id === notifId);
  if (notif) notif.is_read = true;
  return res.json({ status: 'success' });
});


// Pusher / Laravel Reverb Broadcasting Auth
app.post(['/broadcasting/auth', '/api/v1/broadcasting/auth'], (req, res) => {
  const { channel_name, socket_id } = req.body;
  const authKey = `${socket_id}:${channel_name}:auth_ok`;
  return res.json({
    auth: `liferoute_reverb_key:${authKey}`,
    channel_data: JSON.stringify({ user_id: 1, user_info: { name: 'Ambulance Driver' } }),
  });
});

// -----------------------------
// WEBSOCKET SERVER ATTACHMENT
// -----------------------------
const server = http.createServer(app);
const wss = new WebSocketServer({ port: WS_PORT });

wss.on('connection', (ws) => {
  clients.add(ws);
  ws.subscribedChannels = new Set();
  console.log(`🔌 WebSocket client connected (Total: ${clients.size})`);

  // Send Pusher protocol initial connection handshake
  ws.send(
    JSON.stringify({
      event: 'pusher:connection_established',
      data: JSON.stringify({
        socket_id: `${Date.now()}.${Math.floor(Math.random() * 10000)}`,
        activity_timeout: 120,
      }),
    })
  );

  ws.on('message', (msg) => {
    try {
      const data = JSON.parse(msg.toString());
      // Pusher subscribe handshake
      if (data.event === 'pusher:subscribe' || data.event === 'subscribe') {
        const channel = data.data?.channel || data.channel;
        if (channel) {
          ws.subscribedChannels.add(channel);
          console.log(`📡 Client subscribed to channel: ${channel}`);
          ws.send(
            JSON.stringify({
              event: 'pusher_internal:subscription_succeeded',
              channel: channel,
              data: '{}',
            })
          );
        }
      } else if (data.event === 'pusher:ping') {
        ws.send(JSON.stringify({ event: 'pusher:pong', data: '{}' }));
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
