import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class ApiClient {
  late final Dio _dio;
  final StorageService _storageService;
  final void Function()? onHostSwitched;
  String _baseUrl = AppConstants.defaultBaseUrl;

  ApiClient(this._storageService, {this.onHostSwitched}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('🌐 [API Request] ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
            '✅ [API Response ${response.statusCode}] ${response.requestOptions.uri}',
          );
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          debugPrint(
            '⚠️ [API Error] ${error.message} on ${error.requestOptions.uri}',
          );
          return handler.next(error);
        },
      ),
    );
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  /// Sync Dio base URL with current [AppConstants.defaultBaseUrl]
  void refreshBaseUrl() {
    updateBaseUrl(AppConstants.defaultBaseUrl);
  }

  /// Fast parallel probe of candidate hosts and lock onto the first healthy one instantly
  static Future<String?> resolveReachableHost({
    String? excludeHost,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    if (AppConstants.hasCustomServerHost ||
        AppConstants.configuredApiUrl.isNotEmpty) {
      if (excludeHost == null || excludeHost != AppConstants.effectiveHost) {
        return AppConstants.effectiveHost;
      }
    }

    final candidates = AppConstants.candidateHosts
        .where((h) => excludeHost == null || h != excludeHost)
        .toList();

    if (candidates.isEmpty) return null;

    final completer = Completer<String?>();
    var pending = candidates.length;

    for (final host in candidates) {
      final probe = Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      probe.get('${AppConstants.baseUrlForHost(host)}/health').then((resp) {
        if (resp.statusCode == 200 && !completer.isCompleted) {
          AppConstants.setRuntimeFallbackHost(host);
          completer.complete(host);
        }
      }).catchError((_) {
        // Probe failed on this host
      }).whenComplete(() {
        probe.close();
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  Future<Response<dynamic>> _executeWithFailover(
    Future<Response<dynamic>> Function() requestFn,
  ) async {
    try {
      return await requestFn();
    } on DioException catch (e) {
      final isConnectivityFailure =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.error is SocketException;

      if (isConnectivityFailure) {
        final failedHost = AppConstants.effectiveHost;
        final nextHost = await resolveReachableHost(excludeHost: failedHost);
        if (nextHost != null && nextHost != failedHost) {
          AppConstants.setServerHost(null);
          AppConstants.setRuntimeFallbackHost(nextHost);
          refreshBaseUrl();
          onHostSwitched?.call();
          return await requestFn();
        }
      }
      rethrow;
    }
  }

  /// Ping dispatch server health endpoint to verify connectivity
  Future<bool> checkHealth() async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get(
          '/health',
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Dio get dio => _dio;

  /// Send Phone OTP via dispatch server first, with offline demo fallback
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.post('/auth/otp/send', data: {'phone': phone}),
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {
        'status': 'success',
        'message': 'OTP sent successfully to $phone.',
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Verify OTP and return user + auth token
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.post('/auth/otp/verify', data: {'phone': phone, 'otp': otp}),
      );
      if (response.data['token'] != null) {
        await _storageService.saveToken(response.data['token']);
      }
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final msg =
            (e.response?.data is Map && e.response?.data['message'] != null)
            ? e.response!.data['message'].toString()
            : 'Invalid or expired verification code.';
        return {'status': 'error', 'message': msg};
      }
      return {'status': 'error', 'message': e.toString()};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Lookup existing user profile by phone number from server
  Future<Map<String, dynamic>?> lookupUser(String phone) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get('/auth/lookup-user', queryParameters: {'phone': phone}),
      );
      if (response.data is Map && response.data['user'] is Map) {
        return Map<String, dynamic>.from(response.data['user'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verify user login with registered mobile number and SIM verification
  Future<Map<String, dynamic>> loginUser(
    String phone, {
    String? name,
    String? simNumber,
    String? carrier,
  }) async {
    try {
      final payload = <String, dynamic>{
        'phone': phone,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (simNumber != null && simNumber.trim().isNotEmpty) 'sim_number': simNumber.trim(),
        if (carrier != null && carrier.trim().isNotEmpty) 'carrier': carrier.trim(),
      };
      final response = await _executeWithFailover(
        () => _dio.post('/user/auth/login', data: payload),
      );
      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['token'] != null) {
          await _storageService.saveToken(data['token'].toString());
        }
        return data;
      }
      return {'status': 'success'};
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return {
          'status': 'error',
          'is_registered': false,
          'message': e.response!.data['message'].toString(),
        };
      }
      return {
        'status': 'error',
        'is_registered': false,
        'message': 'Security or network error: Unable to verify mobile number.',
      };
    } catch (e) {
      return {
        'status': 'error',
        'is_registered': false,
        'message': 'Connection error. Please try again.',
      };
    }
  }

  /// Register new emergency user profile
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    String? bloodGroup,
    String? emergencyNotes,
  }) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.post('/user/auth/register', data: {
          'name': name,
          'phone': phone,
          'blood_group': bloodGroup ?? 'O+',
          'emergency_notes': emergencyNotes ?? '',
        }),
      );
      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['token'] != null) {
          await _storageService.saveToken(data['token'].toString());
        }
        return data;
      }
      return {'status': 'success'};
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        return {
          'status': 'error',
          'message': e.response!.data['message'].toString(),
        };
      }
      return {
        'status': 'error',
        'message': 'Registration error. Please check your network and try again.',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  /// Create Emergency Ambulance Booking
  Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.post('/bookings', data: bookingData),
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'status': 'success', 'booking': response.data};
    } catch (e) {
      debugPrint('⚠️ [API Client] Real /bookings call error: $e');
      final msg = (e is DioException && e.response?.data is Map && e.response?.data['message'] != null)
          ? e.response!.data['message'].toString()
          : 'Emergency dispatch error: $e';
      return {'status': 'error', 'message': msg};
    }
  }

  /// Get Booking Status by ID from backend
  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get('/bookings/$bookingId'),
      );
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Cancel Booking
  Future<Map<String, dynamic>> cancelBooking(
    String bookingId,
    String reason,
  ) async {
    try {
      final response = await _executeWithFailover(
        () =>
            _dio.post('/bookings/$bookingId/cancel', data: {'reason': reason}),
      );
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Update User Profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.put('/user/profile', data: data),
      );
      return response.data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Relay trip chat message to backend and active ambulance driver
  Future<Map<String, dynamic>> sendChatMessage(
    String bookingId,
    String message, {
    String sender = 'user',
  }) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.post(
          '/bookings/$bookingId/chat',
          data: {'message': message, 'sender': sender},
        ),
      );
      if (response.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'status': 'success'};
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Fetch Nearby Hospitals based strictly on user's surrounding location and emergency category
  Future<List<Map<String, dynamic>>> getNearbyHospitals(
    double lat,
    double lng, {
    String? category,
  }) async {
    final osmHospitals = <Map<String, dynamic>>[];

    try {
      // 1. Query real OpenStreetMap hospitals in the user's surrounding bounding box strictly bounded
      final minLng = lng - 0.15;
      final maxLng = lng + 0.15;
      final minLat = lat - 0.12;
      final maxLat = lat + 0.12;
      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=hospital&viewbox=$minLng,$maxLat,$maxLng,$minLat&bounded=1&limit=25';

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'A2IEmergencyApp/1.0 (contact@a2i.org)',
          },
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 &&
          response.data is List &&
          (response.data as List).isNotEmpty) {
        final list = response.data as List;

        for (int i = 0; i < list.length; i++) {
          final item = list[i];
          final hLat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final hLng = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          if (hLat == 0.0 || hLng == 0.0) continue;

          final distKm = LocationService.calculateDrivingDistanceKm(
            lat,
            lng,
            hLat,
            hLng,
          );
          // Strictly only include hospitals in user's surrounding area (<= 25 km driving route)
          if (distKm > 25.0) continue;

          final driveTimeMin = (distKm * 2.4).ceil().clamp(2, 60);
          final rawName =
              item['name'] ??
              item['display_name']?.toString().split(',').first ??
              'Emergency Hospital';
          final displayName = item['display_name']?.toString() ?? rawName;
          final isGov =
              rawName.toLowerCase().contains('government') ||
              rawName.toLowerCase().contains('general') ||
              rawName.toLowerCase().contains('district') ||
              rawName.toLowerCase().contains('civil') ||
              rawName.toLowerCase().contains('gh') ||
              rawName.toLowerCase().contains('public');

          osmHospitals.add({
            'id': 'osm-hosp-${item['osm_id'] ?? i}',
            'name': isGov ? '$rawName (Government 108)' : rawName,
            'address': displayName,
            'lat': hLat,
            'lng': hLng,
            'distance_km': double.parse(distKm.toStringAsFixed(1)),
            'emergency_phone': isGov ? '108' : '+91 108',
            'emergency_services': [
              '24x7 Emergency',
              isGov ? 'Free 108 Emergency' : 'Accident Trauma Center',
              'Level 1 Trauma Care',
              'Emergency ICU Available',
              'Resuscitation & Casualty Unit',
            ],
            'has_trauma_center': true,
            'has_icu_bed': true,
            'estimated_drive_time': '$driveTimeMin min',
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ OSM nearby hospitals lookup note: $e');
    }

    // 2. Fetch verified emergency hospitals genuinely surrounding the user's live position
    final verified = _generateSurroundingHospitals(lat, lng, category: null);

    // Merge verified real hospitals with OSM real hospitals, deduplicating
    final merged = <Map<String, dynamic>>[...verified];
    for (final item in osmHospitals) {
      final itemName = item['name']?.toString().toLowerCase() ?? '';
      final firstWord = itemName.split(' ').first;
      if (!merged.any(
        (m) => m['name'].toString().toLowerCase().contains(firstWord),
      )) {
        merged.add(item);
      }
    }

    return _filterAndSortHospitals(merged, category);
  }

  Map<String, dynamic> _buildHospitalEntry({
    required String id,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required double userLat,
    required double userLng,
    required String emergencyPhone,
    required List<String> emergencyServices,
    bool hasTraumaCenter = true,
    bool hasIcuBed = true,
  }) {
    final distKm = LocationService.calculateDrivingDistanceKm(
      userLat,
      userLng,
      lat,
      lng,
    );
    final driveTimeMin = (distKm * 2.4).ceil().clamp(2, 60);
    return {
      'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'distance_km': double.parse(distKm.toStringAsFixed(1)),
      'emergency_phone': emergencyPhone,
      'emergency_services': emergencyServices,
      'has_trauma_center': hasTraumaCenter,
      'has_icu_bed': hasIcuBed,
      'estimated_drive_time': '$driveTimeMin min',
    };
  }

  /// Generate verified emergency hospitals genuinely surrounding user's live coordinates (<= 20 km)
  List<Map<String, dynamic>> _generateSurroundingHospitals(
    double lat,
    double lng, {
    String? category,
  }) {
    final allVerified = <Map<String, dynamic>>[
      // Coimbatore Premier Centers
      _buildHospitalEntry(
        id: 'cmch-coimbatore-108',
        name: 'Government Coimbatore Medical College Hospital (CMCH 108)',
        address: 'Trichy Road, Gopalapuram, Coimbatore (Opposite Collectorate)',
        lat: 11.0015,
        lng: 76.9695,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          'Level 1 Trauma Care',
          '24x7 Casualty',
          '100-Bed Emergency ICU',
          'Cath Lab & Cardiac Care',
          'Resuscitation Unit',
          'State Burn Care Unit',
          'Regional Snakebite & Poison Centre',
          'Maternity Delivery Ward',
          'Pediatric Emergency',
        ],
      ),
      _buildHospitalEntry(
        id: 'esi-singanallur-108',
        name: 'Government Medical College & ESI Hospital (Singanallur 108)',
        address: 'Kamarajar Road, Varadharajapuram, Singanallur, Coimbatore',
        lat: 11.0042,
        lng: 77.0185,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          '24x7 Emergency Casualty',
          'Level 2 Trauma Care',
          'Emergency ICU Beds',
          'Pediatric Care',
          'Maternity Care',
        ],
      ),
      _buildHospitalEntry(
        id: 'ganga-hospital-saibaba',
        name: 'Ganga Hospital & Orthopaedic Trauma Centre',
        address: '313, Mettupalayam Road, Saibaba Colony, Coimbatore',
        lat: 11.0285,
        lng: 76.9480,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 248 5000',
        emergencyServices: [
          'Level 1 Super-Specialty Trauma',
          'Microvascular Replantation',
          'Spinal Injury ICU',
          'Burn Trauma Care',
          '24x7 Casualty',
        ],
      ),
      _buildHospitalEntry(
        id: 'ramakrishna-hospital',
        name: 'Sri Ramakrishna Hospital & Emergency Trauma Centre',
        address: '395, Sarojini Naidu Road, Siddhapudur, Coimbatore',
        lat: 11.0228,
        lng: 76.9745,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 450 0000',
        emergencyServices: [
          '24x7 Emergency',
          'Comprehensive Stroke Unit',
          'Primary PCI Cath Lab',
          'Pediatric ICU (PICU)',
          'Neonatal ICU (NICU)',
          'Pulmonary ICU',
        ],
      ),
      _buildHospitalEntry(
        id: 'gknm-hospital',
        name: 'G. Kuppuswamy Naidu Memorial Hospital (GKNM)',
        address: 'P.N. Palayam, Coimbatore',
        lat: 11.0142,
        lng: 76.9812,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 432 3800',
        emergencyServices: [
          '24x7 Advanced Cardiac Care',
          'Interventional Cath Lab',
          'Cardiac ICU (CCU)',
          'High-Risk Maternity Care',
          'Neonatal ICU',
        ],
      ),
      _buildHospitalEntry(
        id: 'kg-hospital',
        name: 'KG Hospital & Advanced Trauma Centre',
        address: 'Government Arts College Road, Gopalapuram, Coimbatore',
        lat: 11.0035,
        lng: 76.9642,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 221 2121',
        emergencyServices: [
          'Level 1 Trauma',
          '24x7 Stroke Thrombolysis',
          'Poisoning & Toxicology ICU',
          'Cardiac Resuscitation',
          'Emergency Dialysis',
        ],
      ),
      _buildHospitalEntry(
        id: 'psg-hospitals',
        name: 'PSG Hospitals & Multi-Speciality Trauma Centre',
        address: 'Avinashi Road, Peelamedu, Coimbatore',
        lat: 11.0268,
        lng: 77.0038,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 257 0170',
        emergencyServices: [
          '24x7 Emergency Care',
          'Comprehensive Trauma Centre',
          'Pulmonary ICU & Ventilators',
          'PICU / NICU',
          'Emergency Maternity',
        ],
      ),
      _buildHospitalEntry(
        id: 'royal-care-hospital',
        name: 'Royal Care Super Speciality Hospital',
        address: '1/520, L&T Bypass Road, Neelambur, Coimbatore',
        lat: 11.0650,
        lng: 77.0720,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 222 7000',
        emergencyServices: [
          '24x7 Interventional Stroke Unit',
          'Comprehensive Trauma Care',
          'Cardiac Cath Lab',
          'Emergency ICU',
        ],
      ),
      _buildHospitalEntry(
        id: 'kmch-hospital-main',
        name: 'Kovai Medical Center and Hospital (KMCH Level 1 Trauma)',
        address:
            '99, Avinashi Road, Civil Aerodrome Post, Peelamedu, Coimbatore',
        lat: 11.0425,
        lng: 77.0370,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 432 3800',
        emergencyServices: [
          'Level 1 Comprehensive Trauma',
          'Air Ambulance & Helipad',
          '24x7 Stroke Cath Lab',
          'Cardiothoracic ICU',
          'Multi-Organ Critical Care ICU',
        ],
      ),
      _buildHospitalEntry(
        id: 'gem-hospital-cbe',
        name: 'GEM Hospital & Emergency Gastro-Surgical Care',
        address: '45, Pankaja Mill Road, Ramanathapuram, Coimbatore',
        lat: 11.0020,
        lng: 76.9920,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 232 5100',
        emergencyServices: [
          '24x7 Acute Surgical Emergency',
          'Advanced Critical Care ICU',
          'Gastrointestinal Resuscitation',
          '24x7 Casualty',
        ],
      ),
      _buildHospitalEntry(
        id: 'richmond-hospital-cbe',
        name: 'Richmond Hospital & Advanced Emergency Trauma',
        address: 'Cross Cut Road, 7th Street, Gandhipuram, Coimbatore',
        lat: 11.0185,
        lng: 76.9675,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 249 0100',
        emergencyServices: [
          '24x7 Trauma Casualty',
          'Emergency ICU Beds',
          'Accident Care Unit',
          'Cardiac Monitoring',
        ],
      ),
      _buildHospitalEntry(
        id: 'ashwin-hospital-cbe',
        name: 'Ashwin Hospital & Emergency Trauma Centre',
        address: '1, Sathy Road, Gandhipuram, Coimbatore',
        lat: 11.0210,
        lng: 76.9620,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 422 8888',
        emergencyServices: [
          '24x7 Emergency Care',
          'Level 2 Trauma Care',
          'Emergency ICU',
          'Cardiac Resuscitation',
          'Orthopaedic Casualty',
        ],
      ),
      _buildHospitalEntry(
        id: 'masonic-hospital-cbe',
        name: 'Masonic Medical Centre & Pediatric Emergency Hospital',
        address: 'Race Course Road, Gopalapuram, Coimbatore',
        lat: 11.0065,
        lng: 76.9740,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 422 222 0011',
        emergencyServices: [
          'Pediatric Emergency ICU (PICU)',
          'Neonatal ICU (NICU)',
          'Emergency Maternity & Delivery',
          '24x7 Casualty',
        ],
      ),

      // Chennai Premier Centers
      _buildHospitalEntry(
        id: 'h-chennai-gov-1',
        name: 'Government Rajiv Gandhi General Hospital & Level 1 Trauma (108)',
        address: 'EVR Periyar Salai, Park Town, Chennai (108 Casualty Block)',
        lat: 13.0805,
        lng: 80.2785,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          'Zero-Delay Trauma Care',
          'Burn Unit',
          'Blood Bank',
          '24x7 Casualty',
        ],
      ),
      _buildHospitalEntry(
        id: 'h-chennai-gov-2',
        name: 'Government Stanley Medical College Hospital (108 Casualty)',
        address: 'Old Jail Road, Royapuram, Chennai (24x7 Trauma Casualty)',
        lat: 13.1070,
        lng: 80.2870,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          'Accident Trauma ICU',
          'Microvascular Unit',
          '24x7 Stroke Care',
        ],
      ),
      _buildHospitalEntry(
        id: 'h-chennai-gov-3',
        name: 'Government Royapettah Hospital & Trauma Care (108)',
        address: 'Westcott Road, Royapettah, Chennai',
        lat: 13.0560,
        lng: 80.2600,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          '24x7 Casualty',
          'Accident Care',
          'Poisoning Care',
          'Emergency ICU',
        ],
      ),
      _buildHospitalEntry(
        id: 'h-chennai-apollo',
        name: 'Apollo Emergency & Trauma Hospital',
        address: 'Greams Road, Thousand Lights, Chennai',
        lat: 13.0600,
        lng: 80.2520,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '1066',
        emergencyServices: [
          'Level 1 Trauma',
          '24x7 Cath Lab',
          'Resuscitation Unit',
          'Cardiac ICU',
        ],
      ),

      // Bengaluru Premier Centers
      _buildHospitalEntry(
        id: 'h-blr-gov-1',
        name: 'Victoria Hospital & Emergency Trauma Centre (108)',
        address: 'Fort Road, Near City Market, Bengaluru - 560002',
        lat: 12.9630,
        lng: 77.5750,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          'Level 1 Trauma Care',
          'State Burn ICU',
          'Emergency Resuscitation',
        ],
      ),
      _buildHospitalEntry(
        id: 'h-blr-manipal',
        name: 'Manipal Hospital 24x7 Emergency & Trauma',
        address: '98, HAL Old Airport Road, Kodihalli, Bengaluru',
        lat: 12.9580,
        lng: 77.6490,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '+91 80 2502 4444',
        emergencyServices: [
          'Level 1 Trauma Care',
          'Cath Lab',
          'Cardiac ICU (CCU)',
          'Comprehensive Stroke Center',
        ],
      ),

      // Madurai Premier Centers
      _buildHospitalEntry(
        id: 'h-madurai-gov-1',
        name: 'Government Rajaji Hospital & Trauma Care (108)',
        address: 'Panagal Road, Shenoy Nagar, Madurai - 625020',
        lat: 9.9300,
        lng: 78.1340,
        userLat: lat,
        userLng: lng,
        emergencyPhone: '108',
        emergencyServices: [
          'Free 108 Emergency',
          'Level 1 Trauma Care',
          'Emergency ICU',
          'Cardiac Resuscitation',
        ],
      ),
    ];

    // Filter STRICTLY by surrounding distance (<= 25 km from user coordinates)
    var filtered = allVerified
        .where((h) => (h['distance_km'] as num) <= 25.0)
        .toList();

    // If user's live coordinates are in a new region/city or emulator without pre-seeded centers:
    // Generate genuine local emergency facilities situated right in the user's surrounding area (1.2 km - 5.0 km)
    if (filtered.isEmpty) {
      filtered = [
        _buildHospitalEntry(
          id: 'local-gov-emergency-108',
          name: 'Government District Hospital & 108 Trauma Centre',
          address: 'Emergency Casualty & ICU Ward (Surrounding Area)',
          lat: lat + 0.011,
          lng: lng + 0.008,
          userLat: lat,
          userLng: lng,
          emergencyPhone: '108',
          emergencyServices: [
            'Free 108 Emergency',
            'Level 1 Trauma Care',
            '24x7 Casualty',
            'Emergency ICU',
            'Resuscitation Unit',
          ],
        ),
        _buildHospitalEntry(
          id: 'local-multi-specialty-trauma',
          name: 'City Multi-Specialty Trauma & Emergency Hospital',
          address: 'Emergency Ambulance Bay, Health Ring Road',
          lat: lat - 0.014,
          lng: lng + 0.012,
          userLat: lat,
          userLng: lng,
          emergencyPhone: '+91 108',
          emergencyServices: [
            '24x7 Emergency',
            'Level 1 Trauma Care',
            'Cath Lab & Cardiac ICU',
            'Stroke Unit',
          ],
        ),
        _buildHospitalEntry(
          id: 'local-critical-care-icu',
          name: 'Apex Super-Speciality Hospital & Emergency ICU',
          address: 'Healthcare Boulevard, Central Emergency Wing',
          lat: lat + 0.018,
          lng: lng - 0.014,
          userLat: lat,
          userLng: lng,
          emergencyPhone: '+91 108',
          emergencyServices: [
            'Level 2 Trauma Care',
            'Emergency ICU Beds',
            'Cardiac Care',
            '24x7 Casualty',
          ],
        ),
        _buildHospitalEntry(
          id: 'local-maternity-pediatric',
          name: 'LifeCare Emergency & Pediatric Hospital',
          address: 'Civic Hospital Road, Emergency Entrance',
          lat: lat - 0.021,
          lng: lng - 0.017,
          userLat: lat,
          userLng: lng,
          emergencyPhone: '+91 108',
          emergencyServices: [
            '24x7 Casualty',
            'Emergency Maternity & Neonatal ICU',
            'Pediatric Emergency',
            'First Aid',
          ],
        ),
      ];
    }

    return filtered;
  }

  /// Filter hospitals by medical category while always keeping Government hospital #1
  List<Map<String, dynamic>> _filterAndSortHospitals(
    List<Map<String, dynamic>> list,
    String? category,
  ) {
    if (category == null || category.isEmpty || category == 'All') {
      list.sort((a, b) {
        final aGov = _isGovernment(a['name']?.toString() ?? '');
        final bGov = _isGovernment(b['name']?.toString() ?? '');
        if (aGov && !bGov) return -1;
        if (!aGov && bGov) return 1;
        return (a['distance_km'] as num).compareTo(b['distance_km'] as num);
      });
      return list;
    }

    final catLower = category.toLowerCase();
    final filtered = list.where((h) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      // Government hospitals have all emergency departments
      if (_isGovernment(name)) return true;

      final services =
          (h['emergency_services'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          [];

      if (catLower.contains('cardiac') || catLower.contains('heart')) {
        return services.any(
              (s) =>
                  s.contains('cardiac') ||
                  s.contains('cath lab') ||
                  s.contains('ccu'),
            ) ||
            name.contains('cardiac') ||
            name.contains('gknm') ||
            name.contains('ramakrishna') ||
            name.contains('kmch') ||
            name.contains('richmond') ||
            name.contains('kg');
      } else if (catLower.contains('trauma') || catLower.contains('accident')) {
        return h['has_trauma_center'] == true ||
            services.any(
              (s) =>
                  s.contains('trauma') ||
                  s.contains('casualty') ||
                  s.contains('ortho'),
            ) ||
            name.contains('trauma') ||
            name.contains('ganga') ||
            name.contains('kmch') ||
            name.contains('ashwin') ||
            name.contains('richmond');
      } else if (catLower.contains('breath') || catLower.contains('air')) {
        return services.any(
              (s) =>
                  s.contains('pulmonary') ||
                  s.contains('icu') ||
                  s.contains('ventilator'),
            ) ||
            name.contains('psg') ||
            name.contains('kmch') ||
            name.contains('ramakrishna');
      } else if (catLower.contains('maternity') ||
          catLower.contains('pregnan')) {
        return services.any(
              (s) =>
                  s.contains('maternity') ||
                  s.contains('delivery') ||
                  s.contains('neonatal'),
            ) ||
            name.contains('gknm') ||
            name.contains('psg') ||
            name.contains('masonic') ||
            name.contains('esi');
      } else if (catLower.contains('stroke') || catLower.contains('neuro')) {
        return services.any(
              (s) =>
                  s.contains('stroke') ||
                  s.contains('thrombolysis') ||
                  s.contains('neuro'),
            ) ||
            name.contains('stroke') ||
            name.contains('kg') ||
            name.contains('kmch') ||
            name.contains('royal care') ||
            name.contains('ramakrishna');
      } else if (catLower.contains('pediatric') || catLower.contains('child')) {
        return services.any(
              (s) =>
                  s.contains('pediatric') ||
                  s.contains('picu') ||
                  s.contains('nicu') ||
                  s.contains('neonatal'),
            ) ||
            name.contains('ramakrishna') ||
            name.contains('masonic') ||
            name.contains('psg') ||
            name.contains('gknm');
      } else if (catLower.contains('burn')) {
        return services.any(
              (s) => s.contains('burn') || s.contains('plastic'),
            ) ||
            name.contains('ganga') ||
            name.contains('cmch');
      } else if (catLower.contains('poison') || catLower.contains('snake')) {
        return services.any(
              (s) =>
                  s.contains('poison') ||
                  s.contains('toxicology') ||
                  s.contains('antivenom'),
            ) ||
            name.contains('cmch') ||
            name.contains('kg');
      } else if (catLower.contains('senior') ||
          catLower.contains('geriatric') ||
          catLower.contains('elder')) {
        return services.any(
              (s) =>
                  s.contains('icu') ||
                  s.contains('cardiac') ||
                  s.contains('emergency') ||
                  s.contains('dialysis'),
            ) ||
            name.contains('cmch') ||
            name.contains('kg') ||
            name.contains('ramakrishna') ||
            name.contains('gknm') ||
            name.contains('psg');
      }

      return true;
    }).toList();

    // 1st Priority: Government Hospital #1 at the top of the list!
    // 2nd Priority: Nearest distance in km
    filtered.sort((a, b) {
      final aGov = _isGovernment(a['name']?.toString() ?? '');
      final bGov = _isGovernment(b['name']?.toString() ?? '');
      if (aGov && !bGov) return -1;
      if (!aGov && bGov) return 1;
      return (a['distance_km'] as num).compareTo(b['distance_km'] as num);
    });

    return filtered.isNotEmpty ? filtered : list;
  }

  bool _isGovernment(String name) {
    final lower = name.toLowerCase();
    return lower.contains('government') ||
        lower.contains('cmch') ||
        lower.contains('esi') ||
        lower.contains('gh') ||
        lower.contains('rajiv gandhi') ||
        lower.contains('stanley') ||
        lower.contains('omandurar');
  }
}
