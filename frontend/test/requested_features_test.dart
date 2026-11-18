import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emergency_user/core/constants/app_constants.dart';
import 'package:emergency_user/models/booking_model.dart';
import 'package:emergency_user/models/driver_model.dart';
import 'package:emergency_user/models/user_model.dart';
import 'package:emergency_user/core/services/route_service.dart';
import 'package:emergency_user/core/services/storage_service.dart';
import 'package:emergency_user/core/network/api_client.dart';
import 'package:emergency_user/features/auth/providers/auth_provider.dart';
import 'package:emergency_user/features/booking/providers/booking_provider.dart';
import 'package:emergency_user/shared/widgets/header_location_pill.dart';
import 'package:emergency_user/shared/widgets/route_progress_bar.dart';
import 'package:emergency_user/features/auth/screens/login_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Request Requirements Verification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test(
      '1. Default mock placeholders removed across constants & booking state',
      () {
        expect(
          AppConstants.defaultLocationName,
          'Locating Current GPS Position...',
        );
        expect(AppConstants.defaultLocationName.contains('Kovilmedu'), isFalse);

        final bookingState = BookingState();
        expect(
          bookingState.currentFullAddress,
          'Acquiring live GPS address...',
        );
        expect(bookingState.currentFullAddress.contains('Kovilmedu'), isFalse);
        expect(bookingState.chatMessages, isEmpty);
      },
    );

    test('2. Profile name persists across logout and restore on login with same phone', () async {
      final storage = await StorageService.init();
      expect(storage.isDemoMode(), isFalse);
      await storage.setDemoMode(true);
      final apiClient = ApiClient(storage);
      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(apiClient),
        ],
      );

      final authNotifier = container.read(authProvider.notifier);

      // Send OTP then verify OTP initially for 8428304510
      await authNotifier.sendOtp('8428304510');
      final initialOtp =
          container.read(authProvider).lastGeneratedOtp ?? '123456';
      await authNotifier.verifyOtp(initialOtp);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // User updates profile name and emergency details
      await authNotifier.updateProfile(
        name: 'Aravind Swaminathan',
        phone: '8428304510',
        bloodGroup: 'O+',
        emergencyNotes: 'Diabetic Patient',
      );

      expect(container.read(authProvider).user?.name, 'Aravind Swaminathan');
      expect(container.read(authProvider).user?.phone, '8428304510');

      // User logs out
      await authNotifier.logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).user, isNull);

      // User logs in again with the same mobile number
      await authNotifier.sendOtp('8428304510');
      final secondOtp =
          container.read(authProvider).lastGeneratedOtp ?? '654321';
      await authNotifier.verifyOtp(secondOtp);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Verify that the updated profile name and phone automatically appear!
      final restoredUser = container.read(authProvider).user;
      expect(restoredUser?.name, 'Aravind Swaminathan');
      expect(restoredUser?.phone, '8428304510');
      expect(restoredUser?.bloodGroup, 'O+');
      expect(restoredUser?.emergencyNotes, 'Diabetic Patient');
    });

    testWidgets(
      '3. HeaderLocationPill prominently renders user name on the red bar',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HeaderLocationPill(
                userName: 'Aravind Swaminathan',
                userPhone: '8428304510',
                liveLocationAddress:
                    'Door No. 40, Amphitheatre Parkway, Santa Clara District',
                onLocationTap: () {},
                onSettingsTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Aravind Swaminathan'), findsOneWidget);
        expect(find.text('A'), findsOneWidget); // Initial avatar
        expect(find.textContaining('8428304510'), findsOneWidget);
        expect(
          find.textContaining('Door No. 40, Amphitheatre Parkway'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. Login screen: Unwanted/OTP bars removed, empty SIM field, and phone validation',
      (WidgetTester tester) async {
        final storage = await StorageService.init();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(storage)],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 4a. Verify unwanted & removed OTP bars are NOT present
        expect(find.textContaining('Free SMS API Key'), findsNothing);
        expect(find.textContaining('Fast2SMS'), findsNothing);
        expect(find.textContaining('Legal Consent'), findsNothing);
        expect(
          find.textContaining('Terms of Service & Indian IT Rules'),
          findsNothing,
        );
        expect(find.text('Get Verification Code'), findsNothing);

        // 4b. Verify both Name and SIM mobile fields start empty (no hardcoded defaults)
        final nameField = find.byType(TextField).first;
        final phoneField = find.byType(TextField).last;
        expect(tester.widget<TextField>(nameField).controller?.text, isEmpty);
        expect(tester.widget<TextField>(phoneField).controller?.text, isEmpty);
        final loginBtn = find.text('Verify & Sign In');
        expect(loginBtn, findsOneWidget);

        // 4c. Validate short phone number rejection
        await tester.enterText(phoneField, '123');
        await tester.ensureVisible(loginBtn);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Please enter a valid 10-digit mobile number'),
          findsOneWidget,
        );

        // 4d. Validate non-Indian SIM prefix rejection
        await tester.enterText(phoneField, '1234567890');
        await tester.ensureVisible(loginBtn);
        await tester.tap(loginBtn);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Invalid mobile number. Indian mobile numbers must start with 6, 7, 8, or 9.',
          ),
          findsOneWidget,
        );
      },
    );

    test('5. BookingModel parses arrived_at_hospital status and AppConstants normalizes server host', () {
      final booking = BookingModel.fromJson({
        'id': 42,
        'booking_reference': '#LR-42',
        'status': 'arrived_at_hospital',
        'user_id': '1',
        'pickup_lat': 11.01,
        'pickup_lng': 76.95,
        'pickup_address': 'Saibaba Colony',
      });
      expect(booking.status, BookingStatus.arrivedAtHospital);

      AppConstants.setServerHost('https://192.168.0.105:8000/api');
      expect(AppConstants.effectiveHost, '192.168.0.105');
      expect(AppConstants.reverbHost, '192.168.0.105');
      expect(AppConstants.defaultLocalBaseUrl, 'http://192.168.0.105:8000/api');
      expect(AppConstants.candidateHosts, contains('192.168.0.105'));
      AppConstants.setServerHost(null);
      expect(AppConstants.hasCustomServerHost, isFalse);
      expect(
        AppConstants.candidateHosts.any(
          (h) => h.contains('liferoute-emergency.com'),
        ),
        isFalse,
      );
    });

    test(
      '6. Models have zero hardcoded default names or static ETA/distance',
      () {
        final user = UserModel.fromJson({});
        expect(user.name, isEmpty);

        final driver = DriverModel.fromJson({});
        expect(driver.name, isEmpty);

        final booking = BookingModel.fromJson({});
        expect(booking.etaMinutes, 0);
        expect(booking.distanceKm, 0.0);
      },
    );

    test(
      '7. RouteService calculates remaining polyline KM and ETA accurately',
      () {
        final polyline = [
          const LatLng(11.0000, 76.9500),
          const LatLng(11.0100, 76.9500),
          const LatLng(11.0200, 76.9500),
        ];
        final fullMeters = RouteService.calculatePolylineDistanceMeters(
          polyline,
        );
        expect(fullMeters, greaterThan(2000));

        final halfwayMeters = RouteService.calculateRemainingPolylineMeters(
          polyline,
          const LatLng(11.0100, 76.9500),
          const LatLng(11.0200, 76.9500),
        );
        expect(halfwayMeters, lessThan(fullMeters));
        expect(halfwayMeters, inInclusiveRange(900.0, 1400.0));
        expect(
          RouteService.estimateEtaMinutes(halfwayMeters),
          greaterThanOrEqualTo(1),
        );
        expect(RouteService.estimateEtaMinutes(0), 0);
      },
    );

    testWidgets(
      '8. RouteProgressBar renders live KM, ETA, and Arrived state cleanly',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RouteProgressBar(
                etaMinutes: 4,
                distanceKm: 2.4,
                phaseLabel: 'AMBULANCE TO PICKUP',
                progress: 0.6,
              ),
            ),
          ),
        );
        expect(find.text('2.4 km'), findsOneWidget);
        expect(find.text('4 min'), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RouteProgressBar(
                etaMinutes: 2,
                distanceKm: 0.85,
                phaseLabel: 'AMBULANCE TO PICKUP',
                progress: 0.8,
              ),
            ),
          ),
        );
        expect(find.text('850 m'), findsOneWidget);
        expect(find.text('850 m remaining'), findsOneWidget);
        expect(find.text('2 min'), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RouteProgressBar(
                etaMinutes: 0,
                distanceKm: 0.0,
                phaseLabel: 'AT HOSPITAL',
                progress: 1.0,
              ),
            ),
          ),
        );
        expect(find.text('At destination'), findsOneWidget);
        expect(find.text('Arrived!'), findsOneWidget);
      },
    );

    test('9. RouteService guards invalid coordinates, trims active roadway, and computes spherical bearing', () async {
      expect(RouteService.isValidCoordinate(const LatLng(0.0, 0.0)), isFalse);
      expect(
        RouteService.isValidCoordinate(const LatLng(11.0168, 76.9558)),
        isTrue,
      );

      final emptyInvalid = await RouteService.getRoadRoute(
        const LatLng(0.0, 0.0),
        const LatLng(11.0168, 76.9558),
      );
      expect(emptyInvalid, isEmpty);

      final trimmed = RouteService.trimRemainingRoute(
        const [
          LatLng(11.0000, 76.9500),
          LatLng(11.0100, 76.9500),
          LatLng(11.0200, 76.9500),
        ],
        const LatLng(11.0105, 76.9500),
        targetPos: const LatLng(11.0200, 76.9500),
      );
      expect(trimmed.length, 2);
      expect(trimmed.first.latitude, closeTo(11.0105, 0.0001));
      expect(trimmed.last.latitude, closeTo(11.0200, 0.0001));

      expect(
        RouteService.calculateBearing(
          const LatLng(11.0000, 76.9500),
          const LatLng(11.0100, 76.9500),
        ),
        inInclusiveRange(0.0, 2.0),
      );
      expect(
        RouteService.calculateBearing(
          const LatLng(11.0000, 76.9500),
          const LatLng(11.0000, 76.9600),
        ),
        inInclusiveRange(88.0, 92.0),
      );
    });

    testWidgets('10. Emergency 1-Tap Login, no server connection icon, and history deduplication', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();
      await storage.setDemoMode(true);
      final apiClient = ApiClient(storage);
      final authNotifier = AuthNotifier(apiClient, storage);

      // Verify Emergency 1-Tap Guest Access with genuine recognized SIM number
      final emergencySuccess = await authNotifier.signInAsEmergencyGuest(
        genuineSimPhone: '+91 98428 30451',
      );
      expect(emergencySuccess, isTrue);
      expect(authNotifier.state.user?.name, 'Emergency Caller');
      expect(authNotifier.state.user?.phone, '+91 9842830451');

      // Verify LoginScreen has 1-Tap Emergency Access removed and NO dns_rounded icon
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            authProvider.overrideWith((ref) => authNotifier),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('🚨 1-Tap Emergency Access'), findsNothing);
      expect(find.byIcon(Icons.dns_rounded), findsNothing);

      // Verify StorageService deduplicates repeated trips in history
      final sampleBooking = BookingModel(
        id: 'bk-test-101',
        referenceNumber: 'REF-101',
        status: BookingStatus.tripCompleted,
        userId: 'usr-1',
        callbackPhone: '+91 98450 12345',
        pickupLat: 11.0168,
        pickupLng: 76.9558,
        pickupAddress: 'Coimbatore Emergency Bay',
        createdAt: DateTime.now(),
      );

      await storage.saveBookingHistory([sampleBooking, sampleBooking, sampleBooking]);
      final loadedHistory = storage.getBookingHistory();
      expect(loadedHistory.length, 1);
      expect(loadedHistory.first.id, 'bk-test-101');
    });
  });
}
