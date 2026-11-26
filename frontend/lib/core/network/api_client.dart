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

  /// Verify user login with registered mobile number and physical SIM verification
  Future<Map<String, dynamic>> loginUser(
    String phone, {
    String? name,
    String? simNumber,
    List<String>? simNumbers,
    bool? hasSim,
    bool? hasPermission,
    String? carrier,
  }) async {
    try {
      final payload = <String, dynamic>{
        'phone': phone,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (simNumber != null && simNumber.trim().isNotEmpty) 'sim_number': simNumber.trim(),
        if (simNumbers != null && simNumbers.isNotEmpty) 'sim_numbers': simNumbers,
        if (hasSim != null) 'has_sim': hasSim,
        if (hasPermission != null) 'has_permission': hasPermission,
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

  /// Revoke current user token on logout
  Future<void> logoutUser() async {
    try {
      await _dio.post('/user/auth/logout');
    } catch (_) {}
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
          'blood_group': bloodGroup ?? '',
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

  /// Sort hospitals by genuine surrounding distance while prioritizing nearby Government hospitals
  List<Map<String, dynamic>> _filterAndSortHospitals(
    List<Map<String, dynamic>> list,
    String? category,
  ) {
    list.sort((a, b) {
      final distA = (a['distance_km'] as num?)?.toDouble() ?? 999999.0;
      final distB = (b['distance_km'] as num?)?.toDouble() ?? 999999.0;
      final aGov = _isGovernment(a['name']?.toString() ?? '') && distA <= 25.0;
      final bGov = _isGovernment(b['name']?.toString() ?? '') && distB <= 25.0;
      if (aGov && !bGov) return -1;
      if (!aGov && bGov) return 1;
      return distA.compareTo(distB);
    });
    return list;
  }

  bool _isGovernment(String name) {
    final lower = name.toLowerCase();
    return lower.contains('government') ||
        lower.contains('govt') ||
        lower.contains('general hospital') ||
        lower.contains('medical college') ||
        lower.contains('district hospital') ||
        lower.contains('taluk') ||
        lower.contains('cmch') ||
        lower.contains('esi');
  }
}
