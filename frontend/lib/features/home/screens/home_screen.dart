import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/route_service.dart';
import '../../../models/booking_model.dart';
import '../../../shared/widgets/custom_map_widget.dart';
import '../../../shared/widgets/header_location_pill.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../../booking/screens/emergency_booking_sheet.dart';
import '../../hospitals/providers/hospital_provider.dart';
import '../../hospitals/screens/hospital_finder_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../tracking/screens/live_tracking_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  bool _isLocating = false;

  void _safeMoveMap(LatLng target, double zoom) {
    try {
      _mapController.move(target, zoom);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Automatically track user's real live GPS on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackLiveLocation(showToast: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(bookingProvider.notifier).reconnectLiveSync();
      _trackLiveLocation(showToast: false);
    }
  }

  /// Request GPS permission, get high-accuracy coordinates, reverse geocode, and center the map
  Future<void> _trackLiveLocation({bool showToast = true}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final loc = await ref
          .read(bookingProvider.notifier)
          .refreshLiveLocation();
      if (!mounted) return;

      if (loc.isAccurate) {
        // Fetch hospitals strictly surrounding the user's real live location
        ref
            .read(hospitalProvider.notifier)
            .fetchNearbyHospitals(lat: loc.latitude, lng: loc.longitude);
        _safeMoveMap(LatLng(loc.latitude, loc.longitude), 16.5);
      } else {
        if (showToast) {
          _showLocationPermissionDialog(
            loc.errorMessage ?? 'Please enable GPS location to pinpoint your exact emergency position.',
            isAppSettings: !loc.serviceEnabled ? false : true,
          );
        }
      }
    } catch (e) {
      if (mounted && showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location update: $e'),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showLocationPermissionDialog(
    String message, {
    bool isAppSettings = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: AppColors.primaryRed),
            SizedBox(width: 10),
            Text(
              'Location Access',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await LocationService.openSettings(isAppSettings: isAppSettings);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isAppSettings ? 'Open App Settings' : 'Enable Device GPS',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final hospitalState = ref.watch(hospitalProvider);
    final authState = ref.watch(authProvider);
    final locale = authState.selectedLocale;
    final selectedHospital = hospitalState.selectedDestinationHospital;
    final hospitalRoadRoute = hospitalState.roadRouteToDestination;
    final activeBooking = bookingState.activeBooking;

    final userLat = bookingState.currentLat;
    final userLng = bookingState.currentLng;

    final bool isTripActive =
        activeBooking != null &&
        activeBooking.status.isActive &&
        activeBooking.status != BookingStatus.tripCompleted &&
        activeBooking.status != BookingStatus.cancelled &&
        activeBooking.status != BookingStatus.noAmbulanceAvailable;

    // Automatically clean up when trip is completed so no tracking lingers on home page
    if (activeBooking != null && !isTripActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bookingProvider.notifier).completeTrip();
        ref.read(hospitalProvider.notifier).selectHospital(null);
      });
    }

    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (previous == null ||
          previous.currentLat != next.currentLat ||
          previous.currentLng != next.currentLng) {
        if (selectedHospital == null) {
          _safeMoveMap(LatLng(next.currentLat, next.currentLng), 16.5);
        } else {
          ref
              .read(hospitalProvider.notifier)
              .refreshRoadRoute(LatLng(next.currentLat, next.currentLng));
        }
        ref
            .read(hospitalProvider.notifier)
            .fetchNearbyHospitals(lat: next.currentLat, lng: next.currentLng);
      }
    });

    ref.listen<HospitalState>(hospitalProvider, (previous, next) {
      if (next.selectedDestinationHospital != null &&
          next.selectedDestinationHospital !=
              previous?.selectedDestinationHospital) {
        final h = next.selectedDestinationHospital!;
        final midLat = (userLat + h.lat) / 2;
        final midLng = (userLng + h.lng) / 2;
        _safeMoveMap(LatLng(midLat, midLng), 14.3);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. Solid Top Section: User Profile Header, Live GPS Actions & Exact Pickup Location Bar (Fills background completely)
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Red Bar: User Name & Mobile Number Pill (Opens Profile)
                    HeaderLocationPill(
                      userName:
                          authState.user?.name ??
                          AppLocalizations.tr('emergencyUser', locale),
                      userPhone:
                          (authState.user?.phone != null &&
                              authState.user!.phone.isNotEmpty)
                          ? authState.user!.phone
                          : AppLocalizations.tr('tapToAddMobile', locale),
                      liveLocationAddress:
                          bookingState.currentAddress.isNotEmpty
                          ? bookingState.currentAddress
                          : AppLocalizations.tr('resolvingLiveGps', locale),
                      onLocationTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                      onSettingsTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Quick Actions Row: Live GPS + Instant Language Switcher (EN | தமிழ் | हिंदी)
                    Row(
                      children: [
                        Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          child: InkWell(
                            onTap: _isLocating
                                ? null
                                : () => _trackLiveLocation(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryRed.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _isLocating
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryRed,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          color: AppColors.primaryRed,
                                          size: 15,
                                        ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isLocating
                                        ? AppLocalizations.tr(
                                            'locating',
                                            locale,
                                          )
                                        : AppLocalizations.tr(
                                            'liveGps',
                                            locale,
                                          ),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Instant Language Switcher Pill (EN | தமிழ் | हिंदी)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _langButton(
                                code: 'en',
                                label: 'EN',
                                isSelected: locale == 'en',
                              ),
                              const SizedBox(width: 2),
                              _langButton(
                                code: 'ta',
                                label: 'தமிழ்',
                                isSelected: locale == 'ta',
                              ),
                              const SizedBox(width: 2),
                              _langButton(
                                code: 'hi',
                                label: 'हिंदी',
                                isSelected: locale == 'hi',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // BIG BAR: EXACT LIVE USER PICKUP LOCATION
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _openLocationPicker(context, locale),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primaryRed.withValues(
                                alpha: 0.35,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.tr(
                                      'exactPickupLocation',
                                      locale,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryRed,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    AppLocalizations.tr('changeOnMap', locale),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.touch_app_rounded,
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.my_location_rounded,
                                      color: AppColors.primaryRed,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bookingState
                                                  .currentFullAddress
                                                  .isNotEmpty
                                              ? bookingState.currentFullAddress
                                              : bookingState.currentAddress,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFEE2E2),
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.tr(
                                              'addressFormatHint',
                                              locale,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedHospital != null) ...[
                                const SizedBox(height: 8),
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderLight,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${AppLocalizations.tr('routeTo', locale)}${selectedHospital.name} (${selectedHospital.distanceKm} km • ${selectedHospital.estimatedDriveTime})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E40AF),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        ref
                                            .read(hospitalProvider.notifier)
                                            .selectHospital(null);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (hospitalState
                                  .filteredHospitals
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderLight,
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    final b = ref.read(bookingProvider);
                                    ref
                                        .read(hospitalProvider.notifier)
                                        .fetchNearbyHospitals(
                                          lat: b.currentLat,
                                          lng: b.currentLng,
                                        );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const HospitalFinderScreen(
                                              isSelectionMode: true,
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_hospital_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Builder(
                                          builder: (_) {
                                            final h = hospitalState
                                                .filteredHospitals
                                                .first;
                                            final liveKm =
                                                LocationService.calculateDrivingDistanceKm(
                                                  bookingState.currentLat,
                                                  bookingState.currentLng,
                                                  h.lat,
                                                  h.lng,
                                                );
                                            final liveEta = (liveKm * 2.4)
                                                .ceil()
                                                .clamp(2, 60);
                                            return Text(
                                              '${AppLocalizations.tr('nearestHospital', locale)}${h.name} (${liveKm.toStringAsFixed(1)} km • $liveEta min)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E40AF),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        AppLocalizations.tr('change', locale),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 10,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Map and Floating Controls strictly below the live pickup location bar
          Expanded(
            child: Stack(
              children: [
                // Clean Map Background with Road Pathway Routing (Interactive pickup marker)
                Positioned.fill(
                  child: CustomMapWidget(
                    center: LatLng(userLat, userLng),
                    zoom: selectedHospital != null ? 14.5 : 15.0,
                    userPosition: LatLng(userLat, userLng),
                    hospitalPosition: selectedHospital != null
                        ? LatLng(selectedHospital.lat, selectedHospital.lng)
                        : null,
                    hospitalName: selectedHospital?.name,
                    hospitalRoutePoints: hospitalRoadRoute,
                    showUserPulse: true,
                    mapController: _mapController,
                    onMapCoordinateTap: (tappedPos) {
                      ref
                          .read(bookingProvider.notifier)
                          .updateLocationFromCoordinates(
                            tappedPos.latitude,
                            tappedPos.longitude,
                          );
                      ref
                          .read(hospitalProvider.notifier)
                          .fetchNearbyHospitals(
                            lat: tappedPos.latitude,
                            lng: tappedPos.longitude,
                          );
                    },
                  ),
                ),
                // Floating Re-Center GPS Button (Bottom Right of Map)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Material(
                    elevation: 4,
                    shape: const CircleBorder(),
                    color: Colors.white,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _trackLiveLocation(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.gps_fixed_rounded,
                          color: AppColors.primaryRed,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating 108 / 112 Emergency Hotline Dialer (Bottom Left of Map)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _showEmergencyAidDialog(context, locale),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primaryRed.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_in_talk_rounded,
                              color: AppColors.primaryRed,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLocalizations.tr('aid108_112', locale),
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // PENDING DISPATCH SEARCH BANNER
                if (bookingState.isSearching ||
                    (activeBooking != null &&
                        activeBooking.status == BookingStatus.findingAmbulance))
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🚨 AMBULANCE DISPATCH PENDING',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Broadcasting emergency call to nearby 108 units...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (activeBooking != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LiveTrackingScreen(),
                                  ),
                                );
                              } else {
                                _handleSosTap(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: const Size(60, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'VIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Bottom Landscape Section: Duty Ambulance Bar (ONLY when active trip is in progress!) + Landscape "BOOK AMBULANCE" Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A) When an Ambulance is Booked & Active: Duty Ambulance Bar (Cleaned up immediately upon completion)
                    if (isTripActive) ...[
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LiveTrackingScreen(),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF334155)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Duty Ambulance Pilot Avatar with pulsing green light
                              Stack(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryRed.withValues(
                                        alpha: 0.15,
                                      ),
                                      border: Border.all(
                                        color: AppColors.primaryRed,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.airport_shuttle_rounded,
                                      color: AppColors.primaryRed,
                                      size: 24,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '${AppLocalizations.tr('dutyAmbulance', locale)} • ${activeBooking.status.localizedLabel(locale).toUpperCase()}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      activeBooking.driver != null
                                          ? (activeBooking.driver!.name.trim().isNotEmpty
                                              ? '${activeBooking.driver!.name} • ${activeBooking.driver!.ambulanceNumber}'
                                              : (activeBooking.driver!.ambulanceNumber.isNotEmpty
                                                  ? activeBooking.driver!.ambulanceNumber
                                                  : activeBooking.driver!.phone))
                                          : activeBooking.referenceNumber,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Builder(
                                      builder: (_) {
                                        final drv = activeBooking.driver;
                                        final isToHosp = activeBooking.status == BookingStatus.patientPickedUp ||
                                            activeBooking.status == BookingStatus.travelingToHospital ||
                                            activeBooking.status == BookingStatus.arrivedAtHospital;
                                        final hosp = activeBooking.destinationHospital;
                                        final tLat = (isToHosp && hosp != null) ? hosp.lat : activeBooking.pickupLat;
                                        final tLng = (isToHosp && hosp != null) ? hosp.lng : activeBooking.pickupLng;
                                        final liveKm = (drv != null &&
                                                RouteService.isValidCoordinate(
                                                  LatLng(drv.currentLat, drv.currentLng),
                                                ))
                                            ? LocationService.calculateDrivingDistanceKm(
                                                drv.currentLat,
                                                drv.currentLng,
                                                tLat,
                                                tLng,
                                              )
                                            : activeBooking.distanceKm;
                                        final liveMin = liveKm <= 0.05
                                            ? 0
                                            : (liveKm / 35.0 * 60.0).ceil().clamp(1, 120);
                                        final distStr = liveKm < 1.0
                                            ? '${(liveKm * 1000).round()} m'
                                            : '${liveKm.toStringAsFixed(1)} km';
                                        final statusTxt = liveMin <= 0
                                            ? 'Arrived • Tap for route'
                                            : '$distStr • $liveMin min • Tap for route';
                                        return Text(
                                          statusTxt,
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.tr('track', locale),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // B) LANDSCAPE-SHAPED "BOOK AMBULANCE NOW" BUTTON
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.redGlowShadow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSosTap(context),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.airport_shuttle_rounded,
                                    color: AppColors.primaryRed,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        AppLocalizations.tr(
                                          'bookAmbulanceNow',
                                          locale,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppLocalizations.tr(
                                          'tapForInstantDispatch',
                                          locale,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSosTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmergencyBookingSheet(),
    );
  }

  void _showEmergencyAidDialog(BuildContext context, String locale) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: AppColors.primaryRed,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.tr('help', locale),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              tileColor: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                AppLocalizations.tr('call108Title', locale),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                AppLocalizations.tr('call108Sub', locale),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.primaryRed,
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse('tel:108');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              tileColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                AppLocalizations.tr('call112Title', locale),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                AppLocalizations.tr('call112Sub', locale),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF2563EB),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse('tel:112');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _openLocationPicker(BuildContext context, String locale) {
    final controller = TextEditingController(
      text: ref.read(bookingProvider).currentAddress,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.tr('setPickupLocation', locale),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            // Direct 1-Tap Live GPS Button
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _trackLiveLocation();
                },
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  AppLocalizations.tr('useExactLiveAddress', locale),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tap map guide button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.tr('tapToSetPin', locale)),
                    backgroundColor: AppColors.primaryRed,
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(
                Icons.touch_app_rounded,
                color: AppColors.primaryRed,
                size: 18,
              ),
              label: Text(
                AppLocalizations.tr('tapToSetPin', locale),
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.borderLight)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    AppLocalizations.tr('orEnterManually', locale),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.borderLight)),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.pin_drop_rounded,
                  color: AppColors.primaryRed,
                ),
                labelText: AppLocalizations.tr('streetAddressHint', locale),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final addr = controller.text.trim();
                if (addr.isNotEmpty) {
                  ref
                      .read(bookingProvider.notifier)
                      .updateLocationManually(
                        lat: ref.read(bookingProvider).currentLat,
                        lng: ref.read(bookingProvider).currentLng,
                        address: addr,
                      );
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                AppLocalizations.tr('saveAddress', locale),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langButton({
    required String code,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => ref.read(authProvider.notifier).setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
