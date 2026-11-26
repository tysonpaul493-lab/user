import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';
import '../../models/booking_model.dart';
import '../../models/driver_model.dart';

class ReverbSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  String? _activeWsUrl;
  String? _authToken;
  List<String> _pendingChannels = const [];
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DriverModel? _lastDriver;
  BookingModel? _currentBooking;

  final _bookingUpdateController = StreamController<BookingModel>.broadcast();
  final _driverLocationController = StreamController<DriverModel>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<BookingModel> get bookingStream => _bookingUpdateController.stream;
  Stream<DriverModel> get driverLocationStream => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get chatMessageStream => _chatMessageController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Connect to WebSocket private channel for live emergency tracking
  void connectToBookingChannel({
    required String bookingId,
    required String authToken,
    required BookingModel currentBooking,
  }) {
    _currentBooking = currentBooking;
    if (authToken.isNotEmpty) {
      _authToken = authToken;
    }
    _isConnected = true;
    _lastDriver = currentBooking.driver;

    final wsUrl = _buildWsUrl();
    if (_channel != null && _activeWsUrl == wsUrl) {
      debugPrint('⚡ [Reverb] Already connected to $wsUrl for booking: $bookingId');
      return;
    }

    debugPrint('⚡ [Reverb] Connecting to private channels for booking: $bookingId');

    // Connect to real backend WebSocket across both Web and Mobile
    _connectRealSocket(bookingId);
  }

  String _buildWsUrl() {
    if (AppConstants.configuredWsUrl.isNotEmpty) {
      return AppConstants.configuredWsUrl;
    }
    final isSecureWeb = kIsWeb && Uri.base.scheme == 'https';
    final useTls = AppConstants.reverbUseTls ||
        isSecureWeb ||
        AppConstants.reverbHost.contains('trycloudflare.com');
    final scheme = useTls ? 'wss' : 'ws';
    final host = AppConstants.reverbHost;
    final port = AppConstants.reverbPort;
    final path = '/app/${AppConstants.reverbAppKey}';
    if ((useTls && (port == 443 || port == 80)) || (!useTls && port == 80)) {
      return '$scheme://$host$path';
    }
    return '$scheme://$host:$port$path';
  }

  void _connectRealSocket(String bookingId) {
    try {
      final wsUrl = _buildWsUrl();
      debugPrint('🔌 [User WS] Connecting to $wsUrl');

      _reconnectTimer?.cancel();
      _pingTimer?.cancel();

      final oldSub = _channelSubscription;
      final oldChannel = _channel;
      _channelSubscription = null;
      _channel = null;

      try {
        oldSub?.cancel();
      } catch (_) {}
      try {
        oldChannel?.sink.close();
      } catch (_) {}

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      _activeWsUrl = wsUrl;
      _isConnected = true;
      _reconnectAttempts = 0;

      debugPrint('✅ [User WS] Connected to backend WebSocket server');

      // Subscribe to public broadcast immediately; authorize private channels after connection_established
      _pendingChannels = <String>[
        'private-bookings.$bookingId',
        'private-booking.$bookingId',
        if (_currentBooking != null && _currentBooking!.referenceNumber.isNotEmpty) ...[
          'private-bookings.${_currentBooking!.referenceNumber}',
          'private-booking.${_currentBooking!.referenceNumber}',
        ],
      ];

      channel.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': 'emergency-broadcasts'},
      }));

      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!identical(_channel, channel)) return;
        try {
          channel.sink.add(jsonEncode({'event': 'pusher:ping', 'data': {}}));
        } catch (_) {
          if (!identical(_channel, channel)) return;
          _scheduleReconnect(bookingId);
        }
      });

      _channelSubscription = channel.stream.listen(
        (data) {
          if (!identical(_channel, channel)) return;
          try {
            final parsed = jsonDecode(data.toString()) as Map<String, dynamic>;
            final eventName = parsed['event'] as String? ?? '';
            dynamic eventData = parsed['data'];
            if (eventData is String) {
              try {
                eventData = jsonDecode(eventData);
              } catch (_) {}
            }

            if (eventName == 'pusher:connection_established' && eventData is Map) {
              final sid = eventData['socket_id']?.toString();
              if (sid != null && sid.isNotEmpty) {
                _authorizeAndSubscribePrivateChannels(channel, sid);
              }
              return;
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
          if (!identical(_channel, channel)) return;
          debugPrint('❌ [User WS] Disconnected');
          _scheduleReconnect(bookingId);
        },
        onError: (e) {
          if (!identical(_channel, channel)) return;
          debugPrint('⚠️ [User WS] Socket error: $e');
          _scheduleReconnect(bookingId);
        },
      );
    } catch (e) {
      debugPrint('⚠️ [User WS] Could not connect to real backend WS: $e');
      _scheduleReconnect(bookingId);
    }
  }

  Future<void> _authorizeAndSubscribePrivateChannels(
    WebSocketChannel channel,
    String socketId,
  ) async {
    if (!identical(_channel, channel)) return;
    final token = _authToken;
    if (token == null || token.isEmpty || socketId.isEmpty) return;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ));
    final authUrl = '${AppConstants.defaultBaseUrl}/broadcasting/auth';

    for (final ch in _pendingChannels.toSet()) {
      if (!identical(_channel, channel)) break;
      try {
        final resp = await dio.post(
          authUrl,
          data: {'channel_name': ch, 'socket_id': socketId},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final auth = (resp.data is Map) ? resp.data['auth']?.toString() : null;
        if (auth != null && auth.isNotEmpty && identical(_channel, channel)) {
          channel.sink.add(jsonEncode({
            'event': 'pusher:subscribe',
            'data': {
              'channel': ch,
              'auth': auth,
              if (resp.data['channel_data'] != null)
                'channel_data': resp.data['channel_data'],
            },
          }));
        }
      } catch (e) {
        debugPrint('⚠️ [User WS] Auth failed for $ch: $e');
      }
    }
    dio.close();
  }

  int _reconnectAttempts = 0;

  void _scheduleReconnect(String bookingId) {
    if (_currentBooking == null) return;
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 2) ? 1 : ((_reconnectAttempts <= 4) ? 2 : 4);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_currentBooking != null) {
        _connectRealSocket(bookingId);
      }
    });
  }

  bool _matchesCurrentBooking(Map<String, dynamic> data) {
    final current = _currentBooking;
    if (current == null) return false;
    final bookingMap = data['booking'] is Map ? data['booking'] as Map : null;
    final incomingId = (data['booking_id'] ?? bookingMap?['id'] ?? bookingMap?['booking_id'])?.toString();
    final incomingRef = (data['booking_reference'] ?? bookingMap?['booking_reference'])?.toString();
    final incomingDriverId = (data['driver_id'] ?? data['driverId'])?.toString();

    if (incomingId != null && incomingId.isNotEmpty) {
      return incomingId == current.id;
    }
    if (incomingRef != null && incomingRef.isNotEmpty && current.referenceNumber.isNotEmpty) {
      return incomingRef == current.referenceNumber;
    }
    if (incomingDriverId != null && incomingDriverId.isNotEmpty && current.driver != null && current.driver!.id.isNotEmpty) {
      return incomingDriverId == current.driver!.id;
    }
    // Accept only if event came on a booking-specific channel or already has matching active trip
    return bookingMap == null && current.driver != null;
  }

  void _handleIncomingWsEvent(String eventName, Map<String, dynamic> data) {
    debugPrint('📩 [User WS Event] $eventName: ${jsonEncode(data)}');

    // 1. Driver Assigned / Booking Accepted
    if (eventName == 'DriverAssigned' ||
        eventName == 'BookingAccepted' ||
        eventName.contains('DriverAssigned')) {
      if (!_matchesCurrentBooking(data) && _currentBooking != null) return;

      final bookingMap = data['booking'] as Map<String, dynamic>?;
      final driverMap = (data['driver'] ?? bookingMap?['driver']) as Map<String, dynamic>?;

      if (driverMap != null) {
        _lastDriver = DriverModel.fromJson(driverMap);
      }

      if (_currentBooking != null) {
        final updated = _currentBooking!.copyWith(
          status: BookingStatus.driverAssigned,
          driver: _lastDriver,
          etaMinutes: (bookingMap?['eta_minutes'] as num?)?.toInt() ?? _currentBooking!.etaMinutes,
          distanceKm: (bookingMap?['distance_km'] as num?)?.toDouble() ?? _currentBooking!.distanceKm,
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
      if (!_matchesCurrentBooking(data)) return;

      final lat = (data['latitude'] ?? data['current_lat']) as num?;
      final lng = (data['longitude'] ?? data['current_lng']) as num?;
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
      final incomingDistKm = (data['distance_km'] as num?)?.toDouble();
      final incomingEtaMin = (data['eta_minutes'] as num?)?.toInt();
      if (lat == null || lng == null || (lat.toDouble() == 0.0 && lng.toDouble() == 0.0)) return;

      final driverMap = data['driver'] as Map<String, dynamic>?;
      if (driverMap != null) {
        _lastDriver = DriverModel.fromJson(driverMap);
      }

      final baseDriver = _lastDriver ??
          DriverModel(
            id: (data['driver_id'] ?? data['driverId'] ?? '').toString(),
            name: (data['driver_name'] ?? '').toString(),
            title: '',
            phone: '',
            ambulanceNumber: '',
            ambulanceType: '',
            rating: 0.0,
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
        _currentBooking = _currentBooking!.copyWith(
          driver: updatedDriver,
          distanceKm: incomingDistKm ?? _currentBooking!.distanceKm,
          etaMinutes: incomingEtaMin ?? _currentBooking!.etaMinutes,
        );
        _bookingUpdateController.add(_currentBooking!);
      }
    }

    // 2.5 Booking / Trip Cancelled
    else if (eventName == 'BookingCancelled' ||
        eventName == 'TripCancelled' ||
        eventName.contains('Cancelled')) {
      if (!_matchesCurrentBooking(data)) return;
      if (_currentBooking != null) {
        final cancelled = _currentBooking!.copyWith(
          status: BookingStatus.cancelled,
          cancellationReason: data['reason']?.toString(),
        );
        _currentBooking = cancelled;
        _bookingUpdateController.add(cancelled);
      }
      disconnect();
    }

    // 3. Trip Status Advance
    else if (eventName == 'TripStatusUpdated' || eventName == 'BookingUpdated') {
      if (!_matchesCurrentBooking(data)) return;
      final statusStr = data['booking']?['status']?.toString() ?? data['status']?.toString();
      if (_currentBooking != null && statusStr != null) {
        BookingStatus newStatus = _currentBooking!.status;
        if (statusStr.contains('cancelled')) {
          newStatus = BookingStatus.cancelled;
        } else if (statusStr.contains('approaching') || statusStr.contains('en_route')) {
          newStatus = BookingStatus.driverApproaching;
        } else if (statusStr.contains('arrived_at_pickup') || statusStr == 'driver_arrived') {
          newStatus = BookingStatus.driverArrived;
        } else if (statusStr.contains('picked_up') || statusStr.contains('onboard')) {
          newStatus = BookingStatus.patientPickedUp;
        } else if (statusStr.contains('arrived_at_hospital') || statusStr == 'arrivedAtHospital') {
          newStatus = BookingStatus.arrivedAtHospital;
        } else if (statusStr.contains('hospital') || statusStr.contains('traveling')) {
          newStatus = BookingStatus.travelingToHospital;
        } else if (statusStr.contains('completed')) {
          newStatus = BookingStatus.tripCompleted;
        }

        final bookingMap = data['booking'] as Map<String, dynamic>?;
        final updated = _currentBooking!.copyWith(
          status: newStatus,
          cancellationReason: data['reason']?.toString() ?? bookingMap?['cancel_reason']?.toString(),
          distanceKm: (bookingMap?['distance_km'] as num?)?.toDouble() ?? _currentBooking!.distanceKm,
          etaMinutes: (bookingMap?['eta_minutes'] as num?)?.toInt() ?? _currentBooking!.etaMinutes,
        );
        _currentBooking = updated;
        _bookingUpdateController.add(updated);
      }
    }

    // 4. Trip Chat Message Relay
    else if (eventName == 'TripChatMessage') {
      if (_currentBooking == null || _matchesCurrentBooking(data)) {
        _chatMessageController.add(data);
      }
    }

    // 5. Trip Completed Handover at Hospital
    else if (eventName == 'TripCompleted' || eventName.contains('Completed')) {
      if (!_matchesCurrentBooking(data)) return;
      debugPrint('🏁 [User WS] Trip completed by driver at destination hospital!');
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

  /// Reconnect live booking socket (e.g. after switching server IP)
  void reconnectIfActive({bool force = false}) {
    if (_currentBooking == null) return;
    final wsUrl = _buildWsUrl();
    if (!force && _isConnected && _channel != null && _activeWsUrl == wsUrl) {
      return;
    }
    _isConnected = true;
    _reconnectAttempts = 0;
    _connectRealSocket(_currentBooking!.id);
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
    _activeWsUrl = null;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    final oldSub = _channelSubscription;
    final oldChannel = _channel;
    _channelSubscription = null;
    _channel = null;
    try {
      oldSub?.cancel();
    } catch (_) {}
    try {
      oldChannel?.sink.close();
    } catch (_) {}
    debugPrint('⚡ [Socket] Disconnected from channels');
  }

  void dispose() {
    disconnect();
    _bookingUpdateController.close();
    _driverLocationController.close();
    _chatMessageController.close();
  }
}
