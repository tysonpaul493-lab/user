# LifeRoute — Emergency Ambulance Booking User Mobile App

A complete, production-grade Flutter emergency ambulance booking application built exclusively for users, patients, and family members who need rapid-response medical transportation.

The visual design and color palette are custom-tailored to the reference design, featuring:
- **Iconic Emergency Red Gradient Theme**: Deep crimson to vibrant coral red gradients (`#FF4B4B` to `#D91616`).
- **Concentric Animated Radar Pulse Rings**: Rippling outward around the large circular SOS button.
- **Top Navigation Pill**: Location pill (`📍 Lordship Ln, Wood Green`) paired with the `[ Schedule ]` button.
- **Floating Controls**: Flanking circular floating buttons (Settings ⚙️ and Help ❓) and bottom Priority banner.
- **Live Route View Tracking Screen**: Live map polyline, moving ambulance marker, animated "Arriving in 5 min" progress bar with moving ambulance icon, and **James Harris** paramedic profile with circular red gradient call & message buttons.
- **Emergency Call 108 in India & 112**: Integrated rapid hotline dialers.

---

## 📱 Visual Design & Features

### 1. Home Screen (Matches Right Phone in Reference Image)
- **Map Background**: Interactive light-themed map displaying local road networks, landmarks, and user location pin.
- **Header Location Pill**: `[ 📍 Lordship Ln, Wood Green ⌵ ]` in red gradient, allowing instant manual location adjustment.
- **Schedule Button**: `[ Schedule ]` pill for pre-booking non-emergency medical transfers (dialysis, clinic appointments).
- **Giant Circular SOS Button**:
  - Linear red gradient with deep glowing shadow (`AppColors.buttonGradient`).
  - Custom-drawn white ambulance icon with speed streaks and medical cross.
  - Bold white "SOS" typography.
  - 3-tier animated concentric pulse rings continuously rippling outward.
- **Flanking Quick Controls**:
  - Left: Circular white button with red settings gear ⚙️.
  - Right: Circular white button with red question mark ❓ for emergency aid & 108/112 dialing.
- **National Emergency Quick Dial**: Top-right floating red badge for instant dialing of **108 (Free Emergency Ambulance / India)** and **112 (Universal Emergency)**.
- **Bottom Priority Banner**: "Sign Up for LifeRoute Priority! £9.99 £4.99" matching the reference design.

### 2. Live Tracking Screen (Matches Left Phone in Reference Image)
- **Header**: `< Route View` with back navigation and live status badge (`DISPATCHED • LIVE GPS`).
- **Real-Time Interactive Map**:
  - Live red polyline (`AppColors.primaryRed`) connecting driver to user.
  - Moving ambulance marker with heading rotation.
  - User pickup pin with pulsing ring.
  - Stale GPS warning banner if signal updates drop below 15 seconds.
- **Floating Tracking Bottom Sheet**:
  - **"Arriving in 5 min"**: Red bold typography paired with animated progress track.
  - **Animated Ambulance Progress Track**: Active red progress bar with an ambulance icon gliding along the line in real time.
  - **Driver Profile Card**:
    - Circular avatar with online green indicator.
    - **James Harris** in prominent crimson red bold text.
    - Subtitle: `Ambulance Driver • Advanced Life Support (ALS) • TN-09-EM-2024`.
    - Rating: ⭐ 4.9 (184 trips).
    - **Circular Red Gradient Action Buttons**: Direct phone call and in-app chat modal.
  - **Expandable Details Drawer**: Booking reference, assistance notes, destination hospital, and cancellation with reason dialog.

### 3. Emergency Booking Flow
- Instant 1-tap dispatch or detailed assistance options.
- Emergency Category selector: Cardiac / Heart, Accident / Trauma, Breathing Difficulty, Pregnancy / Maternity, General Emergency.
- Patient name, landmark, and notes (stretcher, oxygen needed).
- Optional destination hospital selection.
- Animated radar searching screen (`#LR-XXXXX` reference code) transitioning automatically into live tracking upon driver assignment.

### 4. Hospital Finder
- Search by hospital name, neighborhood, or emergency specialty.
- Filter by **Level 1 Trauma Centers**, **ICU Bed Availability**, and **24x7 Resuscitation Units**.
- Real-time distance and estimated drive times.
- Direct 1-tap emergency hotline calling to A&E wards.
- Select hospital as destination for ambulance dispatch.

### 5. Authentication & Profiles
- Phone OTP login (60s countdown, resend limits, Laravel Sanctum token storage).
- **Emergency Guest Bypass**: Allows instant ambulance dispatch without requiring login or filling long forms.
- Emergency Contacts manager: Family members and doctors who receive automated SMS notifications during dispatch.
- **English & Tamil Language Support**: Instant runtime language switching.

---

## 🛠️ Mandatory Tech Stack Architecture

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter 3.47.8 / Dart 3.13.7 | Cross-platform user app |
| **State Management** | Flutter Riverpod | Clean, reactive feature-based state |
| **API Client** | Dio 5.x | REST communication with Laravel Sanctum bearer tokens |
| **Real-Time WebSockets** | Laravel Reverb Service | Authenticated private channels (`private-bookings.{id}`) |
| **Map Engine** | `flutter_map` + CartoDB / OSM | Interactive map with polylines, pins, and markers |
| **GPS** | `geolocator` | Accurate user position and distance calculations |
| **Secure Storage** | `flutter_secure_storage` | Sensitive Sanctum auth tokens |
| **Preferences** | `shared_preferences` | User profiles, emergency contacts, language |
| **Push Notifications** | FCM hooks & Local Alerts | Push dispatch alerts and in-app banner toasts |

---

## 📂 Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart         # Laravel REST API route paths
│   │   ├── app_colors.dart            # Red gradients, shadows, neutral tokens
│   │   └── app_constants.dart         # Hotlines (108, 112), timeouts, coordinates
│   ├── i18n/
│   │   └── app_strings.dart           # English & Tamil translations
│   ├── network/
│   │   └── api_client.dart            # Dio client + Sanctum interceptor + mock engine
│   ├── services/
│   │   ├── location_service.dart      # GPS position & permissions
│   │   ├── notification_service.dart  # Push notifications & in-app alerts
│   │   ├── reverb_socket_service.dart # Laravel Reverb WebSocket private channel
│   │   └── storage_service.dart       # Secure token & preferences storage
│   └── theme/
│       └── app_theme.dart             # GoogleFonts Inter, red gradient tokens
├── models/
│   ├── booking_model.dart             # 10-state booking lifecycle & JSON
│   ├── driver_model.dart              # James Harris profile, vehicle, GPS
│   ├── emergency_contact_model.dart   # Contact model
│   ├── hospital_model.dart            # Emergency facilities & trauma ratings
│   └── user_model.dart                # User profile & guest mode
├── features/
│   ├── auth/                          # Login, OTP verification, guest bypass
│   ├── booking/                       # Emergency booking sheet & radar search
│   ├── history/                       # Past emergency ride logs
│   ├── home/                          # Screen 1: Pulsating SOS & map
│   ├── hospitals/                     # Emergency hospital finder & A&E direct call
│   ├── profile/                       # User profile, emergency contacts & language
│   └── tracking/                      # Screen 2: Route View, James Harris card, chat
└── shared/
    └── widgets/
        ├── custom_map_widget.dart     # Map, polyline, moving driver, user pin
        ├── driver_tracking_card.dart  # Red gradient call/chat buttons, driver info
        ├── emergency_floating_buttons.dart # Settings ⚙️ and Help ❓ buttons
        ├── header_location_pill.dart  # Red gradient location pill + Schedule button
        ├── promo_banner.dart          # Priority pass pill
        ├── route_progress_bar.dart    # Arriving in 5 min + moving ambulance track
        └── sos_pulse_button.dart      # Circular SOS button with animated radar rings
```

---

## 🚀 How to Run Locally

### 1. Run the App
```bash
cd frontend
flutter run
```
You can select Windows (`1`), Chrome (`2`), or an Android/iOS emulator.

### 2. Built-in Interactive Live Demo Mode
The app includes a fully functional simulation engine active by default:
1. Tap **Instant Guest SOS** on the login screen or enter OTP `123456`.
2. Tap the central **SOS button** on the home screen.
3. Review or tap **DISPATCH AMBULANCE NOW**.
4. The radar scanner activates, establishes a simulated private Reverb channel, assigns **James Harris** within 2 seconds, and transitions automatically to **`< Route View`**.
5. Watch the red ambulance icon move dynamically along the route towards your pickup point, updating the ETA down to 1 min!
6. Tap the red gradient **Call** or **Chat** buttons to interact with the driver.
7. Switch language to **தமிழ் (Tamil)** in Profile to see multi-language support.
