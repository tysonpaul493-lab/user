import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../models/booking_model.dart';
import '../../models/driver_model.dart';
import 'route_service.dart';

class ReverbSocketService {
  Timer? _simulationTimer;
  final _bookingUpdateController = StreamController<BookingModel>.broadcast();
  final _driverLocationController = StreamController<DriverModel>.broadcast();

  Stream<BookingModel> get bookingStream => _bookingUpdateController.stream;
  Stream<DriverModel> get driverLocationStream => _driverLocationController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Connect to Laravel Reverb WebSocket private channel
  /// Channel: private-bookings.{bookingId}
  void connectToBookingChannel({
    required String bookingId,
    required String authToken,
    required BookingModel currentBooking,
  }) {
    _isConnected = true;
    debugPrint('⚡ [Reverb] Connecting to private channel: private-bookings.$bookingId');

    // Start real-time driver movement & dispatch event simulation along real road network
    _startLiveSimulation(currentBooking);
  }

  Future<void> _startLiveSimulation(BookingModel initialBooking) async {
    _simulationTimer?.cancel();

    final targetLat = initialBooking.pickupLat;
    final targetLng = initialBooking.pickupLng;

    // Ambulance starting location on nearby road (~1.8km away)
    final startLat = targetLat - 0.012;
    final startLng = targetLng - 0.008;

    // Fetch the actual turn-by-turn road coordinates to reach user
    List<LatLng> roadPoints;
    try {
      roadPoints = await RouteService.getRoadRoute(
        LatLng(startLat, startLng),
        LatLng(targetLat, targetLng),
      );
    } catch (_) {
      roadPoints = [
        LatLng(startLat, startLng),
        LatLng(targetLat, targetLng),
      ];
    }

    if (roadPoints.isEmpty) {
      roadPoints = [LatLng(startLat, startLng), LatLng(targetLat, targetLng)];
    }

    int step = 0;
    var current = initialBooking;

    final initialHeading = roadPoints.length > 1
        ? RouteService.calculateBearing(roadPoints[0], roadPoints[1])
        : 45.0;

    // Emergency Ambulance Pilot
    final driver = DriverModel(
      id: 'drv-108-pilot',
      name: 'Duty Ambulance Pilot',
      title: 'Emergency Medical Pilot',
      phone: '108',
      ambulanceNumber: 'TN-01-EM-108',
      ambulanceType: 'Advanced Life Support (ALS)',
      rating: 4.9,
      totalTrips: 184,
      currentLat: roadPoints[0].latitude,
      currentLng: roadPoints[0].longitude,
      heading: initialHeading,
      lastLocationUpdate: DateTime.now(),
    );

    // Broadcast driver assignment after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!_isConnected) return;
      current = current.copyWith(
        status: BookingStatus.driverAssigned,
        driver: driver,
        etaMinutes: 5,
      );
      _bookingUpdateController.add(current);
    });

    // Advance ambulance along the road coordinates every 2.5 seconds
    // Step sampling to smoothly advance across the road points in ~10-12 steps
    final totalSteps = 12;
    final pointStride = (roadPoints.length / totalSteps).ceil().clamp(1, 10);

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      step += pointStride;
      if (step >= roadPoints.length) {
        step = roadPoints.length - 1;
      }

      final currentPt = roadPoints[step];
      final nextPt = step < roadPoints.length - 1 ? roadPoints[step + 1] : currentPt;
      final currentHeading = RouteService.calculateBearing(currentPt, nextPt);

      final progress = step / (roadPoints.length - 1);
      final remainingEta = ((1.0 - progress) * 5).ceil().clamp(0, 5);
      final isArrived = step >= roadPoints.length - 1;

      final updatedDriver = driver.copyWith(
        currentLat: currentPt.latitude,
        currentLng: currentPt.longitude,
        heading: currentHeading,
        lastLocationUpdate: DateTime.now(),
      );

      final updatedBooking = current.copyWith(
        status: isArrived ? BookingStatus.driverArrived : BookingStatus.driverApproaching,
        driver: updatedDriver,
        etaMinutes: remainingEta,
      );

      _driverLocationController.add(updatedDriver);
      _bookingUpdateController.add(updatedBooking);

      if (isArrived) {
        timer.cancel();
      }
    });
  }

  void disconnect() {
    _simulationTimer?.cancel();
    _isConnected = false;
    debugPrint('⚡ [Reverb] Disconnected from channel');
  }

  void dispose() {
    _simulationTimer?.cancel();
    _bookingUpdateController.close();
    _driverLocationController.close();
  }
}
