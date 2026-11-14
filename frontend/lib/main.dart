import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure local storage & shared preferences
  final storageService = await StorageService.init();
  AppConstants.setServerHost(storageService.getServerHost());

  // Fast auto-resolution of server host (LAN Wi-Fi, USB, emulator)
  if (!AppConstants.hasCustomServerHost) {
    try {
      await ApiClient.resolveReachableHost().timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  // Initialize push notification & background message handlers
  await NotificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const LifeRouteApp(),
    ),
  );
}

class LifeRouteApp extends ConsumerWidget {
  const LifeRouteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: Locale(authState.selectedLocale),
      home: const SplashScreen(),
    );
  }
}
