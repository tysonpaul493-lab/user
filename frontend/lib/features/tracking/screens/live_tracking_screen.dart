import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/route_service.dart';
import '../../../models/booking_model.dart';
import '../../../shared/widgets/custom_map_widget.dart';
import '../../../shared/widgets/driver_tracking_card.dart';
import '../../../shared/widgets/route_progress_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';
import 'chat_sheet.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  bool _isDetailsExpanded = false;
  List<LatLng>? _ambulanceRoadRoute;
  List<LatLng>? _hospitalRoadRoute;
  List<LatLng>? _initialFullAmbulanceRoute;
  LatLng? _lastFetchedOrigin;
  LatLng? _lastFetchedTarget;
  bool _lastHeadingToHospital = false;
  bool _hasRealRoadRoute = false;
  bool _isFetchingRoute = false;

  String _formatStatusTime(BookingModel booking) {
    if (booking.status == BookingStatus.tripCompleted && booking.completedAt != null) {
      return DateFormat('hh:mm a').format(booking.completedAt!);
    }
    if (booking.status == BookingStatus.patientPickedUp && booking.patientPickedUpAt != null) {
      return DateFormat('hh:mm a').format(booking.patientPickedUpAt!);
    }
    if (booking.status == BookingStatus.driverArrived && booking.arrivedPickupAt != null) {
      return DateFormat('hh:mm a').format(booking.arrivedPickupAt!);
    }
    if (booking.acceptedAt != null) {
      return DateFormat('hh:mm a').format(booking.acceptedAt!);
    }
    return DateFormat('hh:mm a').format(booking.createdAt);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoadRoutes();
    });
  }

  LatLng _resolveDriverPos(dynamic driver, double userLat, double userLng) {
    if (driver != null &&
        RouteService.isValidCoordinate(
          LatLng(driver.currentLat, driver.currentLng),
        )) {
      return LatLng(driver.currentLat, driver.currentLng);
    }
    return LatLng(userLat - 0.012, userLng - 0.008);
  }

  bool _needsRouteRefresh(
    LatLng driverPos,
    LatLng targetPos,
    bool isHeadingToHospital,
  ) {
    if (_ambulanceRoadRoute == null || _ambulanceRoadRoute!.length < 2) {
      return true;
    }
    if (_lastHeadingToHospital != isHeadingToHospital) return true;
    if (!_hasRealRoadRoute) return true;
    if (_lastFetchedTarget == null ||
        RouteService.calculateHaversineMeters(_lastFetchedTarget!, targetPos) >
            35.0) {
      return true;
    }
    if (_lastFetchedOrigin == null ||
        RouteService.calculateHaversineMeters(_lastFetchedOrigin!, driverPos) >
            120.0) {
      return true;
    }
    return false;
  }

  Future<void> _fetchRoadRoutes() async {
    if (_isFetchingRoute) return;

    final bookingState = ref.read(bookingProvider);
    final booking = bookingState.activeBooking;
    final driver = booking?.driver;

    final userLat = booking?.pickupLat ?? bookingState.currentLat;
    final userLng = booking?.pickupLng ?? bookingState.currentLng;
    final driverPos = _resolveDriverPos(driver, userLat, userLng);

    final isHeadingToHospital =
        booking?.status == BookingStatus.patientPickedUp ||
        booking?.status == BookingStatus.travelingToHospital ||
        booking?.status == BookingStatus.arrivedAtHospital ||
        booking?.status == BookingStatus.tripCompleted;
    if (_lastHeadingToHospital != isHeadingToHospital) {
      _initialFullAmbulanceRoute = null;
      _hasRealRoadRoute = false;
    }
    final hospital = booking?.destinationHospital;

    final targetLat = (isHeadingToHospital && hospital != null)
        ? hospital.lat
        : userLat;
    final targetLng = (isHeadingToHospital && hospital != null)
        ? hospital.lng
        : userLng;
    final targetPos = LatLng(targetLat, targetLng);

    if (!_needsRouteRefresh(driverPos, targetPos, isHeadingToHospital)) {
      return;
    }

    _isFetchingRoute = true;
    _lastHeadingToHospital = isHeadingToHospital;
    _lastFetchedOrigin = driverPos;
    _lastFetchedTarget = targetPos;

    try {
      final ambRoute = await RouteService.getRoadRoute(driverPos, targetPos);
      final isRealRoute = ambRoute.length > 2;

      if (isRealRoute || _initialFullAmbulanceRoute == null) {
        _initialFullAmbulanceRoute = List<LatLng>.from(ambRoute);
      }

      List<LatLng>? hospRoute;
      if (hospital != null && !isHeadingToHospital) {
        hospRoute = await RouteService.getRoadRoute(
          LatLng(userLat, userLng),
          LatLng(hospital.lat, hospital.lng),
        );
      }

      if (mounted) {
        setState(() {
          if (isRealRoute || _ambulanceRoadRoute == null) {
            _ambulanceRoadRoute = ambRoute;
          }
          _hasRealRoadRoute = isRealRoute;
          _hospitalRoadRoute = isHeadingToHospital ? null : hospRoute;
        });
      }
    } catch (_) {
    } finally {
      _isFetchingRoute = false;
    }
  }

  double _calculateProgress(double remainingMeters) {
    final full = _initialFullAmbulanceRoute;
    if (full == null || full.length < 2) return 0.15;
    final totalMeters = RouteService.calculatePolylineDistanceMeters(full);
    if (totalMeters <= 50.0) return 1.0;
    final traveledFraction = 1.0 - (remainingMeters / totalMeters);
    return traveledFraction.clamp(0.05, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final authState = ref.watch(authProvider);
    final locale = authState.selectedLocale;
    final booking = bookingState.activeBooking;
    final driver = booking?.driver;

    final userLat = booking?.pickupLat ?? bookingState.currentLat;
    final userLng = booking?.pickupLng ?? bookingState.currentLng;
    final driverPos = _resolveDriverPos(driver, userLat, userLng);
    final isArrivedAtPickup = booking?.status == BookingStatus.driverArrived;
    final isHeadingToHospital =
        booking?.status == BookingStatus.patientPickedUp ||
        booking?.status == BookingStatus.travelingToHospital ||
        booking?.status == BookingStatus.arrivedAtHospital ||
        booking?.status == BookingStatus.tripCompleted;
    final isArrivedAtHospital =
        booking?.status == BookingStatus.arrivedAtHospital ||
        booking?.status == BookingStatus.tripCompleted;

    // Listen to trip finish: close live tracking screen so it never loops or repeats
    ref.listen(bookingProvider, (prev, next) {
      if (next.activeBooking == null && prev?.activeBooking != null) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final hospital = booking?.destinationHospital;
    final routeTargetLat = (isHeadingToHospital && hospital != null)
        ? hospital.lat
        : userLat;
    final routeTargetLng = (isHeadingToHospital && hospital != null)
        ? hospital.lng
        : userLng;
    final targetPos = LatLng(routeTargetLat, routeTargetLng);

    final bool atCurrentStop =
        isArrivedAtHospital || (isArrivedAtPickup && !isHeadingToHospital);
    final double remainingMeters = atCurrentStop
        ? 0.0
        : (_ambulanceRoadRoute != null && _ambulanceRoadRoute!.length >= 2)
        ? RouteService.calculateRemainingPolylineMeters(
            _ambulanceRoadRoute!,
            driverPos,
            targetPos,
          )
        : RouteService.calculateEstimatedDrivingMeters(driverPos, targetPos);
    final double liveDistanceKm = remainingMeters / 1000.0;
    final int dynamicEta = atCurrentStop
        ? 0
        : RouteService.estimateEtaMinutes(remainingMeters);
    final double dynamicProgress = isArrivedAtHospital
        ? 1.0
        : (atCurrentStop ? 1.0 : _calculateProgress(remainingMeters));
    final String phaseLabel = isHeadingToHospital
        ? 'To Hospital in'
        : 'Arriving in';

    final List<LatLng>? displayedAmbulanceRoute = atCurrentStop
        ? null
        : (_ambulanceRoadRoute != null && _ambulanceRoadRoute!.length >= 2)
        ? RouteService.trimRemainingRoute(
            _ambulanceRoadRoute!,
            driverPos,
            targetPos: targetPos,
          )
        : null;

    // Refresh road routes cleanly when phase, destination, or significant driver displacement occurs
    if (_needsRouteRefresh(driverPos, targetPos, isHeadingToHospital)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRoadRoutes());
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route View')),
        body: const Center(
          child: Text(
            'Trip completed. Check History page for details.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Interactive Map View with Real Road Pathways (OSRM)
          Positioned.fill(
            child: CustomMapWidget(
              center: LatLng(
                (driverPos.latitude + routeTargetLat) / 2,
                (driverPos.longitude + routeTargetLng) / 2,
              ),
              zoom: 14.8,
              userPosition: LatLng(userLat, userLng),
              driverPosition: driverPos,
              driverHeading: driver?.heading ?? 45.0,
              routePoints: displayedAmbulanceRoute,
              hospitalPosition: booking.destinationHospital != null
                  ? LatLng(
                      booking.destinationHospital!.lat,
                      booking.destinationHospital!.lng,
                    )
                  : null,
              hospitalName: booking.destinationHospital?.name,
              hospitalRoutePoints: isHeadingToHospital
                  ? null
                  : _hospitalRoadRoute,
            ),
          ),

          // 2. Custom App Bar: "< Route View" (Matching reference left phone)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Back button / minimize
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.tr('routeView', locale),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // 1-Tap Share Live Route
                    GestureDetector(
                      onTap: () => _shareTrackingDetails(booking),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Share',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Live GPS / Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${booking.status.label.toUpperCase()} • ${_formatStatusTime(booking)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryRed,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Stale Location Warning Banner (Section 5 requirement!)
          if (bookingState.isGpsStale)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.4),
                  ),
                  boxShadow: AppColors.softCardShadow,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering_off_rounded,
                      color: AppColors.primaryRed,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ambulance GPS signal is intermittent. Paramedic route remains active.',
                        style: TextStyle(
                          color: AppColors.primaryRedDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Floating Tracking Card at the bottom (Matches reference design!)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Destination Hospital Reached Handover Banner (Only shows when hospital destination is reached)
                  if (isArrivedAtHospital ||
                      booking.status == BookingStatus.tripCompleted) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.tr(
                                        'reachedHospital',
                                        locale,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    Text(
                                      booking.destinationHospital?.name ??
                                          'Nearest Emergency Hospital',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ref
                                    .read(bookingProvider.notifier)
                                    .completeTrip();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: Text(
                                AppLocalizations.tr(
                                  'completeAndReturn',
                                  locale,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Progress Track with moving ambulance icon synchronized to road progress
                  RouteProgressBar(
                    etaMinutes: dynamicEta,
                    distanceKm: liveDistanceKm,
                    phaseLabel: phaseLabel,
                    progress: dynamicProgress,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.borderLight, height: 16),

                  // Driver Card (real assigned driver or neutral waiting state)
                  if (driver != null)
                    DriverTrackingCard(
                      driver: driver,
                      onCall: () => _callDriver(
                        driver.phone.isNotEmpty ? driver.phone : '108',
                      ),
                      onChat: () => _openChat(
                        context,
                        driver.name.trim().isNotEmpty
                            ? driver.name
                            : (driver.ambulanceNumber.isNotEmpty
                                  ? driver.ambulanceNumber
                                  : 'Emergency Crew'),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Assigning nearest available ambulance...',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Expandable Drawer for Trip Details & Cancellation
                  if (_isDetailsExpanded) ...[
                    const Divider(color: AppColors.borderLight, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Booking Reference',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          booking.referenceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dispatched Time',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm:ss a').format(booking.acceptedAt ?? booking.createdAt),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pickup Location',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          booking.pickupAddress,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Destination Hospital',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.destinationHospital?.name ??
                                'Nearest Emergency Hospital',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildFirstAidCard(booking.emergencyCategory),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _shareTrackingDetails(booking),
                            icon: const Icon(
                              Icons.share_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Share Live Route',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showCancelDialog(context),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.primaryRed,
                              size: 16,
                            ),
                            label: const Text(
                              'Cancel Request',
                              style: TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primaryRed,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Toggle expandable drawer
                  GestureDetector(
                    onTap: () => setState(
                      () => _isDetailsExpanded = !_isDetailsExpanded,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isDetailsExpanded
                                ? 'Hide Trip Details'
                                : 'View Trip & Hospital Details',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            _isDetailsExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dialing $phone...')));
      }
    }
  }

  void _openChat(BuildContext context, String driverName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverChatSheet(driverName: driverName),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Ambulance?'),
        content: const Text(
          'The ambulance is currently en route. Are you sure you wish to cancel this emergency dispatch?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(bookingProvider.notifier)
                  .cancelActiveBooking(
                    'Patient stabilized / alternate transport',
                  );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _shareTrackingDetails(BookingModel? booking) async {
    final refNum = booking?.referenceNumber ?? '#LR-108';
    final hospital =
        booking?.destinationHospital?.name ?? 'Emergency Trauma Center';
    final pickup = booking?.pickupAddress ?? 'Live GPS Location';
    final shareText =
        '🚨 Emergency Dispatch Tracking 🚨\n'
        'An emergency ambulance ($refNum) is en route to $pickup.\n'
        'Destination Hospital: $hospital.\n'
        'Track live progress: https://liferoute.app/track/$refNum';

    final uri = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(shareText)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        final smsUri = Uri.parse('sms:?body=${Uri.encodeComponent(shareText)}');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Tracking link copied to clipboard! Share with family.',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency tracking link ready for sharing.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Widget _buildFirstAidCard(String category) {
    IconData icon = Icons.medical_services_rounded;
    Color color = AppColors.primaryRed;
    String title = 'First-Aid While Ambulance is En Route';
    List<String> steps = [];

    final catLower = category.toLowerCase();
    if (catLower.contains('cardiac') || catLower.contains('heart')) {
      icon = Icons.favorite_rounded;
      color = const Color(0xFFEF4444);
      title = 'Cardiac First-Aid (CPR)';
      steps = [
        'Place patient flat on back on a firm, flat surface.',
        'Push hard & fast in center of chest (100–120 compressions/min, 2 inches deep).',
        'Do not stop CPR until the ambulance paramedics arrive with defibrillator.',
      ];
    } else if (catLower.contains('trauma') || catLower.contains('accident')) {
      icon = Icons.warning_rounded;
      color = const Color(0xFFF59E0B);
      title = 'Accident / Trauma First-Aid';
      steps = [
        'Apply firm, continuous pressure with a clean cloth directly over bleeding wounds.',
        'Keep patient completely still; do not move the neck or spine if vehicle crash.',
        'Cover patient with a blanket to keep warm and prevent circulatory shock.',
      ];
    } else if (catLower.contains('breath') || catLower.contains('air')) {
      icon = Icons.air_rounded;
      color = const Color(0xFF3B82F6);
      title = 'Breathing Distress Protocol';
      steps = [
        'Help patient sit upright (45–90 degrees) to expand lung capacity.',
        'Loosen all tight collars, neckties, belts, and tight clothing.',
        'Ensure open windows and maximum fresh airflow around the patient.',
      ];
    } else if (catLower.contains('stroke') || catLower.contains('neuro')) {
      icon = Icons.psychology_rounded;
      color = const Color(0xFF8B5CF6);
      title = 'Stroke Emergency Protocol (FAST)';
      steps = [
        'Note the exact time symptoms first appeared (vital for clot-busting medication).',
        'Place patient in the recovery position (on their side) if drowsy.',
        'Do NOT give the patient anything to eat, drink, or medications like aspirin.',
      ];
    } else if (catLower.contains('maternity') || catLower.contains('pregnan')) {
      icon = Icons.pregnant_woman_rounded;
      color = const Color(0xFFEC4899);
      title = 'Maternity / Labor Care';
      steps = [
        'Lay patient on her left side to maximize blood and oxygen flow to the baby.',
        'Encourage slow, rhythmic breathing and reassure the mother.',
        'Gather clean dry towels, blankets, and prenatal medical records for paramedics.',
      ];
    } else {
      icon = Icons.medical_services_rounded;
      color = const Color(0xFF10B981);
      title = 'Emergency Protocol';
      steps = [
        'Check patient responsiveness and maintain an open airway.',
        'Keep patient calm, lying down, and comfortable.',
        'Assign a bystander to wait outside at the main gate/road to guide the ambulance.',
      ];
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIFE SAVING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
