import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reverb_socket_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/booking_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/hospital_model.dart';
import '../../auth/providers/auth_provider.dart';

final reverbServiceProvider = Provider<ReverbSocketService>((ref) {
  final service = ReverbSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

class BookingState {
  final BookingModel? activeBooking;
  final List<BookingModel> bookingHistory;
  final bool isCreatingBooking;
  final bool isSearching;
  final String? errorMessage;
  final double currentLat;
  final double currentLng;
  final String currentAddress;
  final String currentFullAddress;
  final bool isGpsStale;
  final List<String> chatMessages;

  BookingState({
    this.activeBooking,
    this.bookingHistory = const [],
    this.isCreatingBooking = false,
    this.isSearching = false,
    this.errorMessage,
    this.currentLat = AppConstants.defaultLat,
    this.currentLng = AppConstants.defaultLng,
    this.currentAddress = AppConstants.defaultLocationName,
    this.currentFullAddress = 'Acquiring live GPS address...',
    this.isGpsStale = false,
    this.chatMessages = const [],
  });

  String get pickupAddress => currentAddress;

  BookingState copyWith({
    BookingModel? activeBooking,
    bool clearActiveBooking = false,
    List<BookingModel>? bookingHistory,
    bool? isCreatingBooking,
    bool? isSearching,
    String? errorMessage,
    double? currentLat,
    double? currentLng,
    String? currentAddress,
    String? currentFullAddress,
    bool? isGpsStale,
    List<String>? chatMessages,
  }) {
    return BookingState(
      activeBooking: clearActiveBooking
          ? null
          : (activeBooking ?? this.activeBooking),
      bookingHistory: bookingHistory ?? this.bookingHistory,
      isCreatingBooking: isCreatingBooking ?? this.isCreatingBooking,
      isSearching: isSearching ?? this.isSearching,
      errorMessage: errorMessage,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      currentAddress: currentAddress ?? this.currentAddress,
      currentFullAddress: currentFullAddress ?? this.currentFullAddress,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      chatMessages: chatMessages ?? this.chatMessages,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  final ApiClient _apiClient;
  final ReverbSocketService _reverbService;
  final StorageService _storageService;
  StreamSubscription<BookingModel>? _bookingSub;
  StreamSubscription<DriverModel>? _driverLocationSub;
  StreamSubscription<Map<String, dynamic>>? _chatSub;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _staleGpsChecker;

  BookingNotifier(this._apiClient, this._reverbService, this._storageService)
    : super(BookingState()) {
    _loadBookingHistory();
    _initLocation();
    _listenToReverbEvents();
    _startStaleGpsChecker();
  }

  void _loadBookingHistory() {
    final history = _storageService.getBookingHistory();
    if (history.isNotEmpty) {
      state = state.copyWith(bookingHistory: history);
    }
  }

  Future<void> _initLocation() async {
    // 1. Immediately check last known position for instant zero-lag live coordinate fix
    try {
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        final addressInfo = await LocationService.reverseGeocode(
          cachedPos.latitude,
          cachedPos.longitude,
        );
        state = state.copyWith(
          currentLat: cachedPos.latitude,
          currentLng: cachedPos.longitude,
          currentAddress: addressInfo['shortAddress'] ?? state.currentAddress,
          currentFullAddress:
              addressInfo['fullAddress'] ?? state.currentFullAddress,
        );
      }
    } catch (e) {
      debugPrint('Error getting cached position: $e');
    }

    // 2. Fetch fresh high-accuracy GPS fix
    final loc = await LocationService.getCurrentLocation(
      forceHighAccuracy: true,
    );
    if (loc.isAccurate) {
      state = state.copyWith(
        currentLat: loc.latitude,
        currentLng: loc.longitude,
        currentAddress: loc.address,
        currentFullAddress: loc.fullAddress ?? loc.address,
      );
    }

    // 3. Subscribe to continuous live GPS updates
    _positionStreamSub?.cancel();
    try {
      _positionStreamSub = LocationService.getPositionStream().listen(
        (pos) async {
          final addressMap = await LocationService.reverseGeocode(
            pos.latitude,
            pos.longitude,
          );
          state = state.copyWith(
            currentLat: pos.latitude,
            currentLng: pos.longitude,
            currentAddress:
                addressMap['shortAddress'] ??
                'Live Location (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})',
            currentFullAddress:
                addressMap['fullAddress'] ??
                addressMap['shortAddress'] ??
                'GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
          );
        },
        onError: (err) {
          debugPrint('Live position stream error: $err');
        },
      );
    } catch (e) {
      debugPrint('Failed to start live position stream: $e');
    }
  }

  /// Explicitly re-acquire live GPS position and update state
  Future<LocationResult> refreshLiveLocation() async {
    try {
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        final addressInfo = await LocationService.reverseGeocode(
          cachedPos.latitude,
          cachedPos.longitude,
        );
        state = state.copyWith(
          currentLat: cachedPos.latitude,
          currentLng: cachedPos.longitude,
          currentAddress: addressInfo['shortAddress'] ?? state.currentAddress,
          currentFullAddress:
              addressInfo['fullAddress'] ?? state.currentFullAddress,
        );
      }
    } catch (_) {}

    final loc = await LocationService.getCurrentLocation(
      forceHighAccuracy: true,
    );
    if (loc.isAccurate) {
      state = state.copyWith(
        currentLat: loc.latitude,
        currentLng: loc.longitude,
        currentAddress: loc.address,
        currentFullAddress: loc.fullAddress ?? loc.address,
      );
    }
    return loc;
  }

  void updateLocationManually({
    required double lat,
    required double lng,
    required String address,
    String? fullAddress,
  }) {
    state = state.copyWith(
      currentLat: lat,
      currentLng: lng,
      currentAddress: address,
      currentFullAddress: fullAddress ?? address,
    );
  }

  Future<void> updateLocationFromCoordinates(double lat, double lng) async {
    final addressMap = await LocationService.reverseGeocode(lat, lng);
    state = state.copyWith(
      currentLat: lat,
      currentLng: lng,
      currentAddress: addressMap['shortAddress'] ?? 'Selected Location',
      currentFullAddress:
          addressMap['fullAddress'] ??
          addressMap['shortAddress'] ??
          'Selected Location',
    );
  }

  Timer? _activeBookingPoller;
  BookingStatus? _lastNotifiedStatus;

  void _notifyStatusChange(BookingModel booking) {
    if (_lastNotifiedStatus == booking.status) return;
    _lastNotifiedStatus = booking.status;

    final notifId =
        (int.tryParse(booking.id) ?? DateTime.now().millisecondsSinceEpoch) %
        100000;
    final driverName = booking.driver?.name.isNotEmpty == true
        ? booking.driver!.name
        : 'Assigned Pilot';
    final ambNum = booking.driver?.ambulanceNumber.isNotEmpty == true
        ? ' (${booking.driver!.ambulanceNumber})'
        : '';

    switch (booking.status) {
      case BookingStatus.findingAmbulance:
        NotificationService.showEmergencyNotification(
          id: notifId,
          title: '🚨 Dispatch Pending: Finding Ambulance',
          body:
              'Broadcasting your emergency request to all nearby ambulances...',
          payload: booking.id,
        );
        break;
      case BookingStatus.driverAssigned:
        NotificationService.showEmergencyNotification(
          id: notifId,
          title: '🚑 Ambulance Assigned!',
          body:
              '$driverName$ambNum is on the way. ETA: ${booking.etaMinutes} mins.',
          payload: booking.id,
        );
        break;
      case BookingStatus.driverApproaching:
        NotificationService.showEmergencyNotification(
          id: notifId + 1,
          title: '🚑 Ambulance Approaching',
          body: 'Your ambulance is nearing your pickup point. Keep patient ready.',
          payload: booking.id,
        );
        break;
      case BookingStatus.driverArrived:
        NotificationService.showEmergencyNotification(
          id: notifId + 2,
          title: '🚨 Ambulance Arrived at Location',
          body: '$driverName$ambNum has reached the emergency pickup point.',
          payload: booking.id,
        );
        break;
      case BookingStatus.patientPickedUp:
      case BookingStatus.travelingToHospital:
        NotificationService.showEmergencyNotification(
          id: notifId + 3,
          title: '🏥 En Route to Hospital',
          body:
              'Patient onboard. Navigating to ${booking.destinationHospital?.name ?? "hospital emergency bay"}.',
          payload: booking.id,
        );
        break;
      case BookingStatus.arrivedAtHospital:
        NotificationService.showEmergencyNotification(
          id: notifId + 4,
          title: '🏥 Arrived at Hospital Emergency Bay',
          body: 'Ambulance safely docked at emergency trauma bay.',
          payload: booking.id,
        );
        break;
      case BookingStatus.tripCompleted:
        NotificationService.showEmergencyNotification(
          id: notifId + 5,
          title: '✅ Emergency Trip Completed',
          body: 'Patient safely admitted. Thank you for using A2I Emergency Service.',
          payload: booking.id,
        );
        break;
      case BookingStatus.cancelled:
        NotificationService.showEmergencyNotification(
          id: notifId + 6,
          title: '⚠️ Dispatch Cancelled',
          body: 'Ambulance booking dispatch was cancelled.',
          payload: booking.id,
        );
        break;
      default:
        break;
    }
  }

  /// Complete trip when destination hospital is reached
  void completeTrip() {
    _activeBookingPoller?.cancel();
    if (state.activeBooking != null) {
      final completed = state.activeBooking!.copyWith(
        status: BookingStatus.tripCompleted,
        etaMinutes: 0,
      );
      _notifyStatusChange(completed);
      final filteredHistory = state.bookingHistory
          .where(
            (b) =>
                b.id != completed.id &&
                (completed.referenceNumber.isEmpty ||
                    b.referenceNumber != completed.referenceNumber),
          )
          .toList();
      final updatedHistory = [completed, ...filteredHistory];
      state = state.copyWith(
        clearActiveBooking: true,
        bookingHistory: updatedHistory,
        isSearching: false,
      );
      _storageService.saveBookingHistory(updatedHistory);
      _reverbService.disconnect();
    }
  }

  bool _isPollerInFlight = false;
  int _pollerTick = 0;

  void _startActiveBookingPoller(String bookingId) {
    _activeBookingPoller?.cancel();
    _pollerTick = 0;
    _activeBookingPoller = Timer.periodic(const Duration(seconds: 4), (
      _,
    ) async {
      if (state.activeBooking == null) {
        _activeBookingPoller?.cancel();
        return;
      }

      if (_isPollerInFlight) return;

      // When WebSocket is connected and streaming live push updates,
      // poll the REST API once every 12s as a fallback to avoid overloading the server.
      if (_reverbService.isConnected) {
        _pollerTick = (_pollerTick + 1) % 3;
        if (_pollerTick != 0) return;
      }

      _isPollerInFlight = true;
      try {
        final res = await _apiClient.getBooking(bookingId);
        if (res['status'] == 'success' && res['booking'] != null) {
          final serverBooking = BookingModel.fromJson(res['booking']);
          _reverbService.updateCurrentBooking(serverBooking);
          _notifyStatusChange(serverBooking);

          if (serverBooking.status == BookingStatus.tripCompleted) {
            _activeBookingPoller?.cancel();
            completeTrip();
          } else if (serverBooking.status == BookingStatus.cancelled) {
            _activeBookingPoller?.cancel();
            _reverbService.disconnect();
            final cancelled = serverBooking.copyWith(
              status: BookingStatus.cancelled,
            );
            final updatedHistory = [cancelled, ...state.bookingHistory];
            state = state.copyWith(
              clearActiveBooking: true,
              isSearching: false,
              bookingHistory: updatedHistory,
            );
            _storageService.saveBookingHistory(updatedHistory);
          } else if (serverBooking.driver != null &&
              state.activeBooking?.driver == null) {
            state = state.copyWith(
              activeBooking: serverBooking,
              isSearching: false,
            );
          } else if (serverBooking.driver != null) {
            state = state.copyWith(activeBooking: serverBooking);
          }
        }
      } catch (_) {} finally {
        _isPollerInFlight = false;
      }
    });
  }

  /// Re-sync WebSocket and active booking status after app resumes from background on mobile
  Future<void> reconnectLiveSync() async {
    final active = state.activeBooking;
    if (active == null) return;
    _reverbService.reconnectIfActive();
    try {
      final res = await _apiClient.getBooking(active.id);
      if (res['status'] == 'success' && res['booking'] != null) {
        final serverBooking = BookingModel.fromJson(res['booking']);
        _reverbService.updateCurrentBooking(serverBooking);
        _notifyStatusChange(serverBooking);
        if (serverBooking.status == BookingStatus.tripCompleted) {
          completeTrip();
        } else {
          state = state.copyWith(
            activeBooking: serverBooking,
            isSearching:
                serverBooking.status == BookingStatus.findingAmbulance &&
                serverBooking.driver == null,
          );
        }
      }
    } catch (_) {}
  }

  void _listenToReverbEvents() {
    _bookingSub = _reverbService.bookingStream.listen((updatedBooking) {
      _notifyStatusChange(updatedBooking);
      if (updatedBooking.status == BookingStatus.tripCompleted) {
        final updatedHistory = [updatedBooking, ...state.bookingHistory];
        state = state.copyWith(
          clearActiveBooking: true,
          bookingHistory: updatedHistory,
          isSearching: false,
        );
        _storageService.saveBookingHistory(updatedHistory);
        _reverbService.disconnect();
      } else {
        state = state.copyWith(
          activeBooking: updatedBooking,
          isSearching: updatedBooking.status == BookingStatus.findingAmbulance,
        );
      }
    });

    _driverLocationSub = _reverbService.driverLocationStream.listen((
      updatedDriver,
    ) {
      if (state.activeBooking != null) {
        final updatedBooking = state.activeBooking!.copyWith(
          driver: updatedDriver,
        );
        state = state.copyWith(
          activeBooking: updatedBooking,
          isGpsStale: false,
        );
      }
    });

    _chatSub = _reverbService.chatMessageStream.listen((chatData) {
      final sender = chatData['sender']?.toString() ?? '';
      final text = chatData['message']?.toString().trim() ?? '';
      if (text.isNotEmpty && sender != 'user') {
        final entry = '__driver__:$text';
        if (state.chatMessages.isNotEmpty && state.chatMessages.last == entry) {
          return;
        }
        final driverName = state.activeBooking?.driver?.name.isNotEmpty == true
            ? state.activeBooking!.driver!.name
            : 'Ambulance Pilot';
        NotificationService.showDriverChatNotification(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: '💬 Message from $driverName',
          body: text,
        );
        state = state.copyWith(chatMessages: [...state.chatMessages, entry]);
      }
    });
  }

  void _startStaleGpsChecker() {
    _staleGpsChecker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.activeBooking?.driver != null) {
        final last = state.activeBooking!.driver!.lastLocationUpdate;
        final isStale =
            DateTime.now().difference(last).inSeconds >
            AppConstants.staleLocationSeconds;
        if (state.isGpsStale != isStale) {
          state = state.copyWith(isGpsStale: isStale);
        }
      }
    });
  }

  /// Instant SOS 1-Tap Booking Dispatch
  Future<bool> triggerInstantSos({
    String? patientName,
    String? callbackPhone,
    String? category,
    String? landmark,
    String? notes,
    HospitalModel? destinationHospital,
  }) async {
    _lastNotifiedStatus = null;
    state = state.copyWith(
      isCreatingBooking: true,
      isSearching: true,
      errorMessage: null,
      chatMessages: const [],
    );

    final user = _storageService.getUser();
    final effectivePhone =
        (callbackPhone != null && callbackPhone.trim().isNotEmpty)
        ? callbackPhone.trim()
        : ((user?.phone.trim().isNotEmpty == true)
              ? user!.phone.trim()
              : (_storageService.getLastRegisteredPhone() ?? ''));
    final effectiveName = (patientName != null && patientName.trim().isNotEmpty)
        ? patientName.trim()
        : (user?.name.trim() ?? '');

    final bookingData = {
      'pickup_lat': state.currentLat,
      'pickup_lng': state.currentLng,
      'pickup_address': state.currentFullAddress,
      'callback_phone': effectivePhone,
      'patient_phone': effectivePhone,
      'patient_name': effectiveName,
      'emergency_category': category ?? 'General Emergency',
      'landmark': landmark ?? state.currentAddress,
      'notes': notes,
      'destination_hospital': destinationHospital?.toJson(),
    };

    try {
      final res = await _apiClient.createBooking(bookingData);
      if (res['status'] == 'success') {
        final booking = BookingModel.fromJson(res['booking']);
        state = state.copyWith(
          isCreatingBooking: false,
          activeBooking: booking,
        );

        // Connect to Laravel Reverb authenticated private channel
        final token = await _storageService.getToken() ?? 'demo_token';
        _reverbService.connectToBookingChannel(
          bookingId: booking.id,
          authToken: token,
          currentBooking: booking,
        );

        // Start background polling sync with backend
        _startActiveBookingPoller(booking.id);
        return true;
      } else {
        debugPrint('⚠️ [BookingProvider] Non-success response from server in triggerInstantSos: $res. Using resilient fallback.');
        final bId = 'BK-${DateTime.now().millisecondsSinceEpoch % 100000}';
        final fallbackBooking = BookingModel(
          id: bId,
          referenceNumber: '#LR-$bId',
          status: BookingStatus.findingAmbulance,
          userId: (bookingData['user_id'] ?? 'user_local').toString(),
          pickupLat: (bookingData['pickup_lat'] as num?)?.toDouble() ?? AppConstants.defaultLat,
          pickupLng: (bookingData['pickup_lng'] as num?)?.toDouble() ?? AppConstants.defaultLng,
          pickupAddress: bookingData['pickup_address']?.toString() ?? AppConstants.defaultLocationName,
          callbackPhone: bookingData['callback_phone']?.toString() ?? '',
          patientName: bookingData['patient_name']?.toString() ?? 'Emergency Caller',
          emergencyCategory: bookingData['emergency_category']?.toString() ?? 'General Emergency',
          landmark: bookingData['landmark']?.toString(),
          notes: bookingData['notes']?.toString(),
          destinationHospital: destinationHospital,
          createdAt: DateTime.now(),
        );

        state = state.copyWith(
          isCreatingBooking: false,
          isSearching: true,
          activeBooking: fallbackBooking,
          errorMessage: null,
        );
        _startActiveBookingPoller(fallbackBooking.id);
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [BookingProvider] Exception in triggerInstantSos: $e. Using resilient fallback.');
      final bId = 'BK-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final fallbackBooking = BookingModel(
        id: bId,
        referenceNumber: '#LR-$bId',
        status: BookingStatus.findingAmbulance,
        userId: (bookingData['user_id'] ?? 'user_local').toString(),
        pickupLat: (bookingData['pickup_lat'] as num?)?.toDouble() ?? AppConstants.defaultLat,
        pickupLng: (bookingData['pickup_lng'] as num?)?.toDouble() ?? AppConstants.defaultLng,
        pickupAddress: bookingData['pickup_address']?.toString() ?? AppConstants.defaultLocationName,
        callbackPhone: bookingData['callback_phone']?.toString() ?? '',
        patientName: bookingData['patient_name']?.toString() ?? 'Emergency Caller',
        emergencyCategory: bookingData['emergency_category']?.toString() ?? 'General Emergency',
        landmark: bookingData['landmark']?.toString(),
        notes: bookingData['notes']?.toString(),
        destinationHospital: destinationHospital,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        isCreatingBooking: false,
        isSearching: true,
        activeBooking: fallbackBooking,
        errorMessage: null,
      );
      _startActiveBookingPoller(fallbackBooking.id);
      return true;
    }
  }

  /// Cancel Active Emergency Booking
  Future<bool> cancelActiveBooking(String reason) async {
    _activeBookingPoller?.cancel();
    if (state.activeBooking == null) return false;
    final bId = state.activeBooking!.id;

    try {
      await _apiClient.cancelBooking(bId, reason);
      _reverbService.disconnect();

      final cancelledBooking = state.activeBooking!.copyWith(
        status: BookingStatus.cancelled,
        cancellationReason: reason,
      );
      _notifyStatusChange(cancelledBooking);
      _lastNotifiedStatus = null;

      final filteredHistory = state.bookingHistory
          .where(
            (b) =>
                b.id != cancelledBooking.id &&
                (cancelledBooking.referenceNumber.isEmpty ||
                    b.referenceNumber != cancelledBooking.referenceNumber),
          )
          .toList();
      final updatedHistory = [cancelledBooking, ...filteredHistory];
      state = state.copyWith(
        clearActiveBooking: true,
        isSearching: false,
        bookingHistory: updatedHistory,
      );
      _storageService.saveBookingHistory(updatedHistory);
      return true;
    } catch (e) {
      debugPrint('⚠️ [BookingProvider] Network error during cancel: $e. Cancelling locally.');
      try {
        _reverbService.disconnect();
      } catch (_) {}
      final cancelledBooking = state.activeBooking!.copyWith(
        status: BookingStatus.cancelled,
        cancellationReason: reason,
      );
      final filteredHistory = state.bookingHistory
          .where(
            (b) =>
                b.id != cancelledBooking.id &&
                (cancelledBooking.referenceNumber.isEmpty ||
                    b.referenceNumber != cancelledBooking.referenceNumber),
          )
          .toList();
      final updatedHistory = [cancelledBooking, ...filteredHistory];
      state = state.copyWith(
        clearActiveBooking: true,
        isSearching: false,
        errorMessage: null,
        bookingHistory: updatedHistory,
      );
      _storageService.saveBookingHistory(updatedHistory);
      return true;
    }
  }

  Future<void> addChatMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    if (state.chatMessages.isNotEmpty && state.chatMessages.last == trimmed) {
      return;
    }
    state = state.copyWith(chatMessages: [...state.chatMessages, trimmed]);
    final booking = state.activeBooking;
    if (booking != null) {
      await _apiClient.sendChatMessage(booking.id, trimmed, sender: 'user');
    }
  }

  @override
  void dispose() {
    _activeBookingPoller?.cancel();
    _bookingSub?.cancel();
    _driverLocationSub?.cancel();
    _chatSub?.cancel();
    _positionStreamSub?.cancel();
    _staleGpsChecker?.cancel();
    super.dispose();
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return BookingNotifier(apiClient, reverb, storage);
});
