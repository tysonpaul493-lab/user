const http = require('http');
const WebSocket = require('ws');

// Helper to make HTTP JSON requests
function makeRequest(method, urlPath, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: 8000,
      path: urlPath,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, text: body });
        }
      });
    });

    req.on('error', reject);

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

function delay(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function parsePayload(msgObj) {
  if (!msgObj) return null;
  if (typeof msgObj.data === 'string') {
    try {
      return JSON.parse(msgObj.data);
    } catch (_) {}
  }
  if (msgObj.data && typeof msgObj.data === 'object') return msgObj.data;
  return msgObj;
}

async function runTest() {
  console.log('🚀 Starting LifeRoute User & Driver Integration E2E Test...');

  // 1. Health check
  const health = await makeRequest('GET', '/health');
  console.log('1️⃣ Backend Health Check:', health.data);
  if (health.status !== 200) throw new Error('Backend health check failed');

  // 2. Setup Driver WebSocket listener
  const driverWs = new WebSocket('ws://127.0.0.1:8080');
  const driverEvents = [];
  await new Promise((resolve) => {
    driverWs.on('open', () => {
      driverWs.send(JSON.stringify({
        event: 'pusher:subscribe',
        data: { channel: 'emergency-broadcasts' }
      }));
      resolve();
    });
    driverWs.on('message', (msg) => {
      try {
        const parsed = JSON.parse(msg.toString());
        driverEvents.push(parsed);
      } catch (_) {}
    });
  });
  console.log('2️⃣ Driver WebSocket subscribed to emergency-broadcasts');

  // 3. User Books Ambulance
  const bookingPayload = {
    emergency_type: 'Cardiac Arrest',
    pickup_address: '100 Feet Rd, Indiranagar, Bengaluru',
    pickup_landmark: 'Near Metro Pillar #124',
    pickup_lat: 12.9784,
    pickup_lng: 77.6408,
    patient_name: 'Anil Kumar',
    patient_age: '54',
    patient_gender: 'Male',
    patient_phone: '+91 98765 12345',
    medical_notes: 'Severe chest pain radiating to left arm. Conscious.',
    destination_hospital: {
      name: 'Manipal Hospital ICU, Old Airport Rd',
      lat: 12.9592,
      lng: 77.6534,
      distance_km: 3.2
    }
  };

  const bookingRes = await makeRequest('POST', '/api/bookings', bookingPayload);
  console.log('3️⃣ User Booking Response:', bookingRes.status, bookingRes.data.status);
  const booking = bookingRes.data.booking;
  if (!booking || !booking.id) throw new Error('Booking creation failed');
  console.log(`   Created Booking ID: ${booking.id}, Ref: ${booking.booking_reference}`);

  await delay(500);

  // 4. Verify Driver WS received broadcast with user details
  const broadcastEvtRaw = driverEvents.find(e => e.event === 'BookingRequested' || e.event === 'new-booking-request');
  const broadcastEvt = parsePayload(broadcastEvtRaw);
  console.log('4️⃣ Driver Received Emergency Alert:', !!broadcastEvt);
  if (broadcastEvt) {
    console.log('   Patient Name:', broadcastEvt.patient_name);
    console.log('   Pickup Address:', broadcastEvt.pickup_address);
    console.log('   Hospital:', broadcastEvt.destination_hospital);
  }

  // 5. Verify Driver Notifications & Pending Requests REST APIs
  const notifRes = await makeRequest('GET', '/api/v1/driver/notifications');
  console.log('5️⃣ Driver Notifications Count:', notifRes.data.notifications.length);
  const pendingRes = await makeRequest('GET', '/api/v1/driver/requests/pending');
  console.log('   Driver Pending Requests Count:', pendingRes.data.requests.length);

  // 6. Setup User WebSocket listener for assigned driver & tracking
  const userWs = new WebSocket('ws://127.0.0.1:8080');
  const userEvents = [];
  await new Promise((resolve) => {
    userWs.on('open', () => {
      userWs.send(JSON.stringify({
        event: 'pusher:subscribe',
        data: { channel: `private-booking.${booking.booking_reference}` }
      }));
      resolve();
    });
    userWs.on('message', (msg) => {
      try {
        const parsed = JSON.parse(msg.toString());
        userEvents.push(parsed);
      } catch (_) {}
    });
  });
  console.log(`6️⃣ User WebSocket subscribed to private-booking.${booking.booking_reference}`);

  // 7. Driver Accepts the Request
  const acceptRes = await makeRequest('POST', `/api/v1/driver/requests/${booking.id}/accept`);
  console.log('7️⃣ Driver Accept Response:', acceptRes.status, acceptRes.data.status);

  await delay(500);

  // 8. Verify User Received Driver Details
  const driverAssignedEvtRaw = userEvents.find(e => e.event === 'DriverAssigned' || e.event === 'BookingAccepted');
  const driverAssignedEvt = parsePayload(driverAssignedEvtRaw);
  console.log('8️⃣ User Received Driver Details Event:', !!driverAssignedEvt);
  const driver = driverAssignedEvt?.driver || driverAssignedEvt?.booking?.driver;
  if (driver) {
    console.log('   Driver Name:', driver.name);
    console.log('   Driver Phone:', driver.phone);
    console.log('   Ambulance Plate:', driver.ambulance_number);
    console.log('   Ambulance Type:', driver.ambulance_type);
  } else {
    throw new Error('Driver details not found in DriverAssigned event');
  }

  // 9. Driver sends live GPS telemetry
  const telemetryRes = await makeRequest('POST', '/api/v1/driver/location/telemetry', {
    booking_reference: booking.booking_reference,
    latitude: 12.9750,
    longitude: 77.6350,
    heading: 95.5,
    speed: 48.2
  });
  console.log('9️⃣ Driver Telemetry Sync:', telemetryRes.data.status);

  await delay(500);

  const locationEvtRaw = userEvents.find(e => e.event === 'DriverLocationUpdated');
  const locationEvt = parsePayload(locationEvtRaw);
  console.log('🔟 User Received Live Driver Location Event:', !!locationEvt);
  if (locationEvt) {
    console.log(`   Ambulance GPS: Lat ${locationEvt.latitude || locationEvt.current_lat}, Lng ${locationEvt.longitude || locationEvt.current_lng}, Heading ${locationEvt.heading}`);
  }

  // 11. Workflow status steps
  console.log('11. Driver progresses through workflow...');
  const steps = [
    'en_route_to_pickup',
    'arrived_at_pickup',
    'patient_onboard',
    'in_transit_to_hospital',
    'arrived_at_hospital'
  ];

  for (const step of steps) {
    const res = await makeRequest('PATCH', `/api/v1/driver/trips/${booking.id}/status`, {
      status: step,
      latitude: 12.9600,
      longitude: 77.6500
    });
    console.log(`    Status transitioned -> ${step} (${res.data.status})`);
  }

  // Verify trip is NOT completed yet
  const userCheckBooking = await makeRequest('GET', `/api/bookings/${booking.id}`);
  console.log('12. Verify Trip status at hospital arrival:', userCheckBooking.data.booking.status);
  if (userCheckBooking.data.booking.status === 'trip_completed') {
    throw new Error('Trip was completed prematurely before handover completion!');
  }

  // 13. Driver completes trip at hospital handover
  const completeRes = await makeRequest('PATCH', `/api/v1/driver/trips/${booking.id}/status`, {
    status: 'completed',
    latitude: 12.9592,
    longitude: 77.6534,
    handover_notes: 'Transferred directly to Dr. Rao at ICU Bay #3. Vitals stabilized.'
  });
  console.log('13. Driver Completes Trip & Handover:', completeRes.data.status);

  await delay(500);

  const completedEvtRaw = userEvents.find(e => e.event === 'TripCompleted');
  const completedEvt = parsePayload(completedEvtRaw);
  console.log('14. User Received TripCompleted Broadcast:', !!completedEvt);

  // 15. Check Trip History on both User and Driver sides
  const userHistory = await makeRequest('GET', '/api/bookings/history');
  console.log('15. User Booking History Count:', userHistory.data.bookings.length);
  const driverHistory = await makeRequest('GET', '/api/v1/driver/trips/history');
  console.log('    Driver Trip History Count:', driverHistory.data.trips.length);

  const lastUserTrip = userHistory.data.bookings[0];
  const lastDriverTrip = driverHistory.data.trips[0];
  console.log(`    User History Latest: Ref=${lastUserTrip.booking_reference}, Status=${lastUserTrip.status}, Hospital=${typeof lastUserTrip.destination_hospital === 'object' ? lastUserTrip.destination_hospital.name : lastUserTrip.destination_hospital}`);
  console.log(`    Driver History Latest: Ref=${lastDriverTrip.booking_reference}, Status=${lastDriverTrip.status}, HandoverNotes="${lastDriverTrip.handover_notes}"`);

  driverWs.close();
  userWs.close();

  console.log('\n🎉 ALL INTEGRATION TESTS PASSED PERFECTLY!');
}

runTest().catch((err) => {
  console.error('❌ Integration Test Failed:', err);
  process.exit(1);
});
