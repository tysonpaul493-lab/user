import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
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

  /// Fetch Nearby Hospitals genuinely from LifeRoute backend database
  Future<List<Map<String, dynamic>>> getNearbyHospitals(
    double lat,
    double lng, {
    String? category,
  }) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get(
          '/hospitals/nearby',
          queryParameters: {
            'lat': lat,
            'lng': lng,
            if (category != null && category.isNotEmpty) 'specialty': category,
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final rawList = (data['data'] ?? data['hospitals']) as List?;
        if (rawList != null && rawList.isNotEmpty) {
          final list = rawList
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          return _filterAndSortHospitals(list, category);
        }
      }
    } catch (e) {
      debugPrint('⚠️ LifeRoute backend nearby hospitals error: $e');
    }

    return [];
  }

  /// Fetch User Booking History from genuine backend database
  Future<List<Map<String, dynamic>>> getBookingHistory({String? phone}) async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get(
          '/bookings/history',
          queryParameters: phone != null && phone.isNotEmpty ? {'phone': phone} : null,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final list = (data['data'] ?? data['bookings']) as List?;
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Fetch booking history error: $e');
    }
    return [];
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
        final distA = (a['distance_km'] as num?)?.toDouble() ?? 999999.0;
        final distB = (b['distance_km'] as num?)?.toDouble() ?? 999999.0;
        return distA.compareTo(distB);
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
      final distA = (a['distance_km'] as num?)?.toDouble() ?? 999999.0;
      final distB = (b['distance_km'] as num?)?.toDouble() ?? 999999.0;
      return distA.compareTo(distB);
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
