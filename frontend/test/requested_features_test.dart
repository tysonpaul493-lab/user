import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emergency_user/core/constants/app_constants.dart';
import 'package:emergency_user/core/services/storage_service.dart';
import 'package:emergency_user/core/network/api_client.dart';
import 'package:emergency_user/features/auth/providers/auth_provider.dart';
import 'package:emergency_user/features/booking/providers/booking_provider.dart';
import 'package:emergency_user/shared/widgets/header_location_pill.dart';
import 'package:emergency_user/features/auth/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Request Requirements Verification Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('1. Default mock placeholders removed across constants & booking state', () {
      expect(AppConstants.defaultLocationName, 'Locating Current GPS Position...');
      expect(AppConstants.defaultLocationName.contains('Kovilmedu'), isFalse);

      final bookingState = BookingState();
      expect(bookingState.currentFullAddress, 'Acquiring live GPS address...');
      expect(bookingState.currentFullAddress.contains('Kovilmedu'), isFalse);
    });

    test('2. Profile name persists across logout and restore on login with same phone', () async {
      final storage = await StorageService.init();
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
      final initialOtp = container.read(authProvider).lastGeneratedOtp ?? '123456';
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
      final secondOtp = container.read(authProvider).lastGeneratedOtp ?? '654321';
      await authNotifier.verifyOtp(secondOtp);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Verify that the updated profile name and phone automatically appear!
      final restoredUser = container.read(authProvider).user;
      expect(restoredUser?.name, 'Aravind Swaminathan');
      expect(restoredUser?.phone, '8428304510');
      expect(restoredUser?.bloodGroup, 'O+');
      expect(restoredUser?.emergencyNotes, 'Diabetic Patient');
    });

    testWidgets('3. HeaderLocationPill prominently renders user name on the red bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeaderLocationPill(
              userName: 'Aravind Swaminathan',
              userPhone: '8428304510',
              liveLocationAddress: 'Door No. 40, Amphitheatre Parkway, Santa Clara District',
              onLocationTap: () {},
              onSettingsTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Aravind Swaminathan'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // Initial avatar
      expect(find.textContaining('8428304510'), findsOneWidget);
      expect(find.textContaining('Door No. 40, Amphitheatre Parkway'), findsOneWidget);
    });

    testWidgets('4. Login screen: Unwanted bars removed, top SMS notification, and auto-fill on OTP tap', (WidgetTester tester) async {
      final storage = await StorageService.init();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4a. Verify unwanted bars above "Get Verification Code" are NOT present
      expect(find.textContaining('Free SMS API Key'), findsNothing);
      expect(find.textContaining('Fast2SMS'), findsNothing);
      expect(find.textContaining('Legal Consent'), findsNothing);
      expect(find.textContaining('Terms of Service & Indian IT Rules'), findsNothing);

      // Verify "Get Verification Code" button is present
      expect(find.text('Get Verification Code'), findsOneWidget);

      // 4b. Enter phone number and tap "Get Verification Code"
      await tester.enterText(find.byType(TextField).first, '8428304510');
      await tester.tap(find.text('Get Verification Code'));
      await tester.pumpAndSettle();

      // Verify top-of-screen SMS notification appears
      expect(find.text('Messages'), findsOneWidget);
      expect(find.textContaining('LifeRoute Emergency: Your OTP verification code is'), findsOneWidget);
      expect(find.textContaining('Valid for 10 min'), findsOneWidget);

      // Verify in-card banner is removed
      expect(find.textContaining('Incoming SMS • LifeRoute Dispatch'), findsNothing);

      // Verify auto-fill chip is NOT displayed initially before tapping OTP field
      expect(find.textContaining('Auto-fill code from SMS'), findsNothing);

      // 4c. Tap OTP input field -> auto-fill option appears
      final otpFields = find.byType(TextField);
      expect(otpFields, findsWidgets);
      await tester.tap(otpFields.last);
      await tester.pumpAndSettle();

      // Auto-fill chip is now displayed!
      final autoFillChip = find.textContaining('Auto-fill code from SMS');
      expect(autoFillChip, findsOneWidget);

      // 4d. Tapping auto-fill populates the OTP
      await tester.tap(autoFillChip);
      await tester.pumpAndSettle();

      final otpControllerText = tester.widget<TextField>(otpFields.last).controller?.text;
      expect(otpControllerText?.length, 6);
      expect(int.tryParse(otpControllerText!), isNotNull);
    });
  });
}
