import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../../models/booking_model.dart';
import '../../models/driver_model.dart';

class ReverbSocketService {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _simulationTimer;
  DriverModel? _lastDriver;
  BookingModel? _currentBooking;

  final _bookingUpdateController = StreamController<BookingModel>.broadcast();
  final _driverLocationController = StreamController<DriverModel>.broadcast();

  Stream<BookingModel> get bookingStream => _bookingUpdateController.stream;
  Stream<DriverModel> get driverLocationStream => _driverLocationController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Connect to WebSocket private channel for live emergency tracking
  void connectToBookingChannel({
    required String bookingId,
    required String authToken,
    required BookingModel currentBooking,
  }) {
    _currentBooking = currentBooking;
    _isConnected = true;
    _lastDriver = currentBooking.driver;

    debugPrint('⚡ [Reverb] Connecting to private channels for booking: $bookingId');

    // 1. Connect to real backend WebSocket
    _connectRealSocket(bookingId);
  }

  void _connectRealSocket(String bookingId) async {
    try {
      final wsUrl = 'ws://${AppConstants.reverbHost}:${AppConstants.reverbPort}';
      debugPrint('🔌 [User WS] Connecting to $wsUrl');
      _socket?.close();
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));

      debugPrint('✅ [User WS] Connected to backend WebSocket server');

      // Subscribe to booking channels (both prefixed and non-prefixed)
      final channels = [
        'private-bookings.$bookingId',
        'private-booking.$bookingId',
        'emergency-broadcasts',
      ];

      for (final ch in channels) {
        _socket?.add(jsonEncode({
          'event': 'pusher:subscribe',
          'data': {'channel': ch},
        }));
      }

      _socket?.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            final eventName = parsed['event'] as String? ?? '';
            dynamic eventData = parsed['data'];
            if (eventData is String) {
              try {
                eventData = jsonDecode(eventData);
              } catch (_) {}
            }

            Map<String, dynamic> payload = {};
            if (eventData is Map<String, dynamic>) {
              payload = eventData;
            } else {
              payload = parsed;
            }

            _handleIncomingWsEvent(eventName, payload);
          } catch (e) {
            debugPrint('Error parsing user WS message: $e');
          }
        },
        onDone: () {
          debugPrint('❌ [User WS] Disconnected');
          _scheduleReconnect(bookingId);
        },
        onError: (e) {
          debugPrint('⚠️ [User WS] Socket error: $e');
          _scheduleReconnect(bookingId);
        },
      );
    } catch (e) {
      debugPrint('⚠️ [User WS] Could not connect to real backend WS: $e');
      _scheduleReconnect(bookingId);
    }
  }

  void _scheduleReconnect(String bookingId) {
    if (!_isConnected) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (_isConnected) {
        _connectRealSocket(bookingId);
      }
    });
  }

  void _handleIncomingWsEvent(String eventName, Map<String, dynamic> data) {
    debugPrint('📩 [User WS Event] $eventName: ${jsonEncode(data)}');

    // 1. Driver Assigned / Booking Accepted
    if (eventName == 'DriverAssigned' ||
        eventName == 'BookingAccepted' ||
        eventName.contains('DriverAssigned')) {
      _simulationTimer?.cancel();

      final bookingMap = data['booking'] as Map<String, dynamic>?;
      final driverMap = (data['driver'] ?? bookingMap?['driver']) as Map<String, dynamic>?;

      if (driverMap != null) {
        _lastDriver = DriverModel.fromJson(driverMap);
      }

      if (_currentBooking != null) {
        final updated = _currentBooking!.copyWith(
          status: BookingStatus.driverAssigned,
          driver: _lastDriver,
          etaMinutes: (bookingMap?['eta_minutes'] as num?)?.toInt() ?? 5,
        );
        _currentBooking = updated;
        _bookingUpdateController.add(updated);
        if (_lastDriver != null) {
          _driverLocationController.add(_lastDriver!);
        }
      } else if (bookingMap != null) {
        final parsed = BookingModel.fromJson(bookingMap);
        _currentBooking = parsed;
        _bookingUpdateController.add(parsed);
      }
    }

    // 2. Driver Location Telemetry Update
    else if (eventName == 'DriverLocationUpdated' ||
        eventName == 'LocationUpdated' ||
        eventName.contains('Location')) {
      final lat = (data['latitude'] ?? data['current_lat']) as num?;
      final lng = (data['longitude'] ?? data['current_lng']) as num?;
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

      final driverMap = data['driver'] as Map<String, dynamic>?;
      if (_lastDriver == null && driverMap != null) {
        _lastDriver = DriverModel.fromJson(driverMap);
      }

      if (lat != null && lng != null) {
        final baseDriver = _lastDriver ??
            DriverModel(
              id: '1',
              name: 'Muruganandam',
              title: '108 Emergency Medical Pilot',
              phone: '+91 94431 10800',
              ambulanceNumber: 'TN-01-EA-1080',
              ambulanceType: 'Advanced Life Support (ALS)',
              rating: 4.95,
              currentLat: lat.toDouble(),
              currentLng: lng.toDouble(),
              heading: heading,
              lastLocationUpdate: DateTime.now(),
            );

        final updatedDriver = baseDriver.copyWith(
          currentLat: lat.toDouble(),
          currentLng: lng.toDouble(),
          heading: heading,
          lastLocationUpdate: DateTime.now(),
        );
        _lastDriver = updatedDriver;
        _driverLocationController.add(updatedDriver);

        if (_currentBooking != null) {
          _currentBooking = _currentBooking!.copyWith(driver: updatedDriver);
          _bookingUpdateController.add(_currentBooking!);
        }
      }
    }

    // 3. Trip Status Advance
    else if (eventName == 'TripStatusUpdated' || eventName == 'BookingUpdated') {
      final statusStr = data['booking']?['status']?.toString() ?? data['status']?.toString();
      if (_currentBooking != null && statusStr != null) {
        BookingStatus newStatus = _currentBooking!.status;
        if (statusStr.contains('approaching') || statusStr.contains('en_route')) {
          newStatus = BookingStatus.driverApproaching;
        } else if (statusStr.contains('arrived_at_pickup') || statusStr == 'driver_arrived') {
          newStatus = BookingStatus.driverArrived;
        } else if (statusStr.contains('picked_up') || statusStr.contains('onboard')) {
          newStatus = BookingStatus.patientPickedUp;
        } else if (statusStr.contains('hospital') || statusStr.contains('traveling')) {
          newStatus = BookingStatus.travelingToHospital;
        } else if (statusStr.contains('completed')) {
          newStatus = BookingStatus.tripCompleted;
        }

        final updated = _currentBooking!.copyWith(status: newStatus);
        _currentBooking = updated;
        _bookingUpdateController.add(updated);
      }
    }

    // 4. Trip Completed Handover at Hospital
    else if (eventName == 'TripCompleted' || eventName.contains('Completed')) {
      debugPrint('🏁 [User WS] Trip completed by driver at destination hospital!');
      _simulationTimer?.cancel();
      if (_currentBooking != null) {
        final completed = _currentBooking!.copyWith(
          status: BookingStatus.tripCompleted,
          etaMinutes: 0,
        );
        _currentBooking = completed;
        _bookingUpdateController.add(completed);
      }
      disconnect();
    }
  }

  /// Update current booking instance externally
  void updateCurrentBooking(BookingModel booking) {
    _currentBooking = booking;
    if (booking.driver != null) {
      _lastDriver = booking.driver;
    }
  }

  void disconnect() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _simulationTimer?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    debugPrint('⚡ [Reverb] Disconnected from channels');
  }

  void dispose() {
    disconnect();
    _bookingUpdateController.close();
    _driverLocationController.close();
  }
}
