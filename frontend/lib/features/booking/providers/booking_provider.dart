import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
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
    this.chatMessages = const [
      'Ambulance dispatched. On my way with sirens on.',
      'Heavy traffic avoided via rapid-response bypass.',
    ],
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
      activeBooking: clearActiveBooking ? null : (activeBooking ?? this.activeBooking),
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
    } else {
      final initialTrip = BookingModel(
        id: 'completed_trip_108',
        referenceNumber: '#108-TN-CBE-9941',
        status: BookingStatus.tripCompleted,
        userId: '1',
        callbackPhone: '+91 98765 43210',
        patientName: 'Subramanian Raman',
        emergencyCategory: 'Cardiac Emergency (108 ALS)',
        pickupLat: 11.0168,
        pickupLng: 76.9558,
        pickupAddress: 'Door No. 14B, 3rd Cross, NSR Road, Saibaba Colony, Coimbatore District, Tamil Nadu - 641011',
        landmark: 'Near Ganga Hospital Annexe',
        notes: 'High-flow oxygen given, continuous ECG, vitals stabilized',
        destinationHospital: HospitalModel(
          id: 'cmch-coimbatore-108',
          name: 'Government Coimbatore Medical College Hospital (CMCH 108)',
          address: 'Avinashi Road, Near Collectorate, Coimbatore District - 641018',
          emergencyPhone: '108',
          lat: 11.0028,
          lng: 76.9669,
          distanceKm: 2.4,
          estimatedDriveTime: '6 min',
          emergencyServices: const [
            'Free 108 Emergency',
            'Level 1 Trauma Care',
            'Emergency ICU',
            'Cardiac Cath Lab',
          ],
          hasTraumaCenter: true,
          hasIcuBed: true,
        ),
        driver: DriverModel(
          id: 'drv_108_cbe',
          name: 'Muruganandam',
          title: '108 Ambulance Pilot',
          phone: '+91 94431 10800',
          ambulanceNumber: 'TN 38 G 1084',
          ambulanceType: '108 ALS Ambulance',
          currentLat: 11.0028,
          currentLng: 76.9669,
          rating: 4.95,
          totalTrips: 1420,
          lastLocationUpdate: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
        distanceKm: 3.2,
        etaMinutes: 0,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      state = state.copyWith(bookingHistory: [initialTrip]);
      _storageService.saveBookingHistory([initialTrip]);
    }
  }

  Future<void> _initLocation() async {
    // 1. Immediately check last known position for instant zero-lag live coordinate fix
    try {
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        final addressInfo = await LocationService.reverseGeocode(cachedPos.latitude, cachedPos.longitude);
        state = state.copyWith(
          currentLat: cachedPos.latitude,
          currentLng: cachedPos.longitude,
          currentAddress: addressInfo['shortAddress'] ?? state.currentAddress,
          currentFullAddress: addressInfo['fullAddress'] ?? state.currentFullAddress,
        );
      }
    } catch (e) {
      debugPrint('Error getting cached position: $e');
    }

    // 2. Fetch fresh high-accuracy GPS fix
    final loc = await LocationService.getCurrentLocation(forceHighAccuracy: true);
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
      _positionStreamSub = LocationService.getPositionStream().listen((pos) async {
        final addressMap = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        state = state.copyWith(
          currentLat: pos.latitude,
          currentLng: pos.longitude,
          currentAddress: addressMap['shortAddress'] ?? 'Live Location (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})',
          currentFullAddress: addressMap['fullAddress'] ?? addressMap['shortAddress'] ?? 'GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        );
      }, onError: (err) {
        debugPrint('Live position stream error: $err');
      });
    } catch (e) {
      debugPrint('Failed to start live position stream: $e');
    }
  }

  /// Explicitly re-acquire live GPS position and update state
  Future<LocationResult> refreshLiveLocation() async {
    try {
      final cachedPos = await Geolocator.getLastKnownPosition();
      if (cachedPos != null) {
        final addressInfo = await LocationService.reverseGeocode(cachedPos.latitude, cachedPos.longitude);
        state = state.copyWith(
          currentLat: cachedPos.latitude,
          currentLng: cachedPos.longitude,
          currentAddress: addressInfo['shortAddress'] ?? state.currentAddress,
          currentFullAddress: addressInfo['fullAddress'] ?? state.currentFullAddress,
        );
      }
    } catch (_) {}

    final loc = await LocationService.getCurrentLocation(forceHighAccuracy: true);
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
      currentFullAddress: addressMap['fullAddress'] ?? addressMap['shortAddress'] ?? 'Selected Location',
    );
  }

  Timer? _activeBookingPoller;

  /// Complete trip when destination hospital is reached
  void completeTrip() {
    _activeBookingPoller?.cancel();
    if (state.activeBooking != null) {
      final completed = state.activeBooking!.copyWith(
        status: BookingStatus.tripCompleted,
        etaMinutes: 0,
      );
      final updatedHistory = [completed, ...state.bookingHistory];
      state = state.copyWith(
        clearActiveBooking: true,
        bookingHistory: updatedHistory,
        isSearching: false,
      );
      _storageService.saveBookingHistory(updatedHistory);
      _reverbService.disconnect();
    }
  }

  void _startActiveBookingPoller(String bookingId) {
    _activeBookingPoller?.cancel();
    _activeBookingPoller = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (state.activeBooking == null) {
        _activeBookingPoller?.cancel();
        return;
      }

      try {
        final res = await _apiClient.getBooking(bookingId);
        if (res['status'] == 'success' && res['booking'] != null) {
          final serverBooking = BookingModel.fromJson(res['booking']);
          _reverbService.updateCurrentBooking(serverBooking);

          if (serverBooking.status == BookingStatus.tripCompleted) {
            _activeBookingPoller?.cancel();
            completeTrip();
          } else if (serverBooking.driver != null && state.activeBooking?.driver == null) {
            state = state.copyWith(
              activeBooking: serverBooking,
              isSearching: false,
            );
          } else if (serverBooking.driver != null) {
            state = state.copyWith(
              activeBooking: serverBooking,
            );
          }
        }
      } catch (_) {}
    });
  }

  void _listenToReverbEvents() {
    _bookingSub = _reverbService.bookingStream.listen((updatedBooking) {
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

    _driverLocationSub = _reverbService.driverLocationStream.listen((updatedDriver) {
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
  }


  void _startStaleGpsChecker() {
    _staleGpsChecker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.activeBooking?.driver != null) {
        final last = state.activeBooking!.driver!.lastLocationUpdate;
        final isStale = DateTime.now().difference(last).inSeconds > AppConstants.staleLocationSeconds;
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
    state = state.copyWith(isCreatingBooking: true, isSearching: true, errorMessage: null);

    final user = _storageService.getUser();
    final effectivePhone = (callbackPhone != null && callbackPhone.trim().isNotEmpty)
        ? callbackPhone.trim()
        : ((user?.phone != null && user!.phone.isNotEmpty)
            ? user.phone
            : '+91 84283 04510');
    final effectiveName = (patientName != null && patientName.trim().isNotEmpty)
        ? patientName.trim()
        : ((user?.name != null && user!.name.isNotEmpty)
            ? user.name
            : 'Emergency Requester');

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
        state = state.copyWith(
          isCreatingBooking: false,
          isSearching: false,
          errorMessage: res['message'] ?? 'Failed to dispatch ambulance',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isCreatingBooking: false,
        isSearching: false,
        errorMessage: e.toString(),
      );
      return false;
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

      final updatedHistory = [cancelledBooking, ...state.bookingHistory];
      state = state.copyWith(
        clearActiveBooking: true,
        isSearching: false,
        bookingHistory: updatedHistory,
      );
      _storageService.saveBookingHistory(updatedHistory);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  void addChatMessage(String message) {
    state = state.copyWith(
      chatMessages: [...state.chatMessages, message],
    );
  }

  @override
  void dispose() {
    _activeBookingPoller?.cancel();
    _bookingSub?.cancel();
    _driverLocationSub?.cancel();
    _positionStreamSub?.cancel();
    _staleGpsChecker?.cancel();
    super.dispose();
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final reverb = ref.watch(reverbServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return BookingNotifier(apiClient, reverb, storage);
});
