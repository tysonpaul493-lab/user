import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RouteService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        if (!kIsWeb) 'User-Agent': 'A2IEmergency/1.0 (Android Emergency Routing)',
        'Accept': 'application/json',
      },
    ),
  );

  // In-memory cache ONLY for verified real OSRM road geometries
  static final Map<String, List<LatLng>> _routeCache = {};

  static bool isValidCoordinate(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        !(point.latitude == 0.0 && point.longitude == 0.0) &&
        point.latitude.abs() <= 90.0 &&
        point.longitude.abs() <= 180.0;
  }

  static Future<List<LatLng>?> _fetchFromOsrmEndpoint(
    String baseUrl,
    LatLng start,
    LatLng end,
  ) async {
    final url =
        '$baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    final response = await _dio.get(url);
    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map;
      if (data['code'] == 'Ok' && data['routes'] is List) {
        final routesList = data['routes'] as List;
        if (routesList.isNotEmpty) {
          final coordinates = routesList[0]['geometry']?['coordinates'] as List?;
          if (coordinates != null && coordinates.isNotEmpty) {
            final roadPoints = coordinates
                .whereType<List>()
                .where((c) => c.length >= 2)
                .map(
                  (coord) => LatLng(
                    (coord[1] as num).toDouble(),
                    (coord[0] as num).toDouble(),
                  ),
                )
                .toList();
            if (roadPoints.length >= 2) {
              return roadPoints;
            }
          }
        }
      }
    }
    return null;
  }

  /// Fetch the exact road pathway between two coordinates using OSRM.
  /// Retries with a secondary OSRM mirror on transient failure and never caches fallbacks.
  static Future<List<LatLng>> getRoadRoute(LatLng start, LatLng end) async {
    if (!isValidCoordinate(start) || !isValidCoordinate(end)) {
      return [];
    }

    if (calculateHaversineMeters(start, end) < 15.0) {
      return [start, end];
    }

    // Cache key rounded to 4 decimals (~11 meters)
    final cacheKey =
        '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}->${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}';
    final cached = _routeCache[cacheKey];
    if (cached != null && cached.length >= 2) {
      return cached;
    }

    const mirrors = [
      'https://router.project-osrm.org/route/v1/driving',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving',
    ];

    for (final mirror in mirrors) {
      try {
        final roadPoints = await _fetchFromOsrmEndpoint(mirror, start, end);
        if (roadPoints != null && roadPoints.length >= 2) {
          _routeCache[cacheKey] = roadPoints;
          return roadPoints;
        }
      } catch (e) {
        debugPrint('⚠️ OSRM routing lookup failed ($mirror): $e');
      }
    }

    // Return clean direct endpoints without caching so the next tick retries real OSRM
    return [start, end];
  }

  /// Trims already-traveled vertices behind [currentPos] along a road polyline so the
  /// displayed roadway starts from the ambulance's current position cleanly.
  static List<LatLng> trimRemainingRoute(
    List<LatLng> fullRoute,
    LatLng currentPos, {
    LatLng? targetPos,
  }) {
    if (!isValidCoordinate(currentPos)) return fullRoute;
    if (fullRoute.length < 2) {
      if (targetPos != null && isValidCoordinate(targetPos)) {
        return [currentPos, targetPos];
      }
      return fullRoute;
    }

    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < fullRoute.length; i++) {
      final d = calculateHaversineMeters(fullRoute[i], currentPos);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // If ambulance moved far off the cached road polyline, show direct bridge to next segment/target
    if (minDist > 500.0 && targetPos != null && isValidCoordinate(targetPos)) {
      return [currentPos, targetPos];
    }

    final remaining = <LatLng>[currentPos];
    for (int i = closestIdx + 1; i < fullRoute.length; i++) {
      remaining.add(fullRoute[i]);
    }
    if (remaining.length < 2 && fullRoute.isNotEmpty) {
      remaining.add(fullRoute.last);
    }
    return remaining;
  }

  /// Haversine straight-line distance in meters between two LatLng points (pure Dart).
  static double calculateHaversineMeters(LatLng a, LatLng b) {
    if ((a.latitude == 0.0 && a.longitude == 0.0) ||
        (b.latitude == 0.0 && b.longitude == 0.0)) {
      return 0.0;
    }
    const double earthRadiusM = 6371000.0;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final double lat1Rad = a.latitude * math.pi / 180.0;
    final double lat2Rad = b.latitude * math.pi / 180.0;

    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(h), math.sqrt(math.max(0.0, 1.0 - h)));
    return earthRadiusM * c;
  }

  /// Urban driving distance estimate in meters when no road polyline is cached.
  static double calculateEstimatedDrivingMeters(LatLng start, LatLng end) {
    final aerialM = calculateHaversineMeters(start, end);
    if (aerialM <= 20.0) return 0.0;
    if (aerialM <= 50.0) return 100.0;
    return (aerialM * 1.28) + 150.0;
  }

  /// Sum exact road distance in meters along a polyline.
  static double calculatePolylineDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += calculateHaversineMeters(points[i], points[i + 1]);
    }
    return total;
  }

  /// Calculate remaining road distance along [polyline] from [currentPos] to the end (or [targetPos]).
  static double calculateRemainingPolylineMeters(
    List<LatLng> polyline,
    LatLng currentPos,
    LatLng targetPos,
  ) {
    if (polyline.length < 2) {
      return calculateEstimatedDrivingMeters(currentPos, targetPos);
    }

    int closestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < polyline.length; i++) {
      final d = calculateHaversineMeters(polyline[i], currentPos);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    // If ambulance drifted far off the cached polyline (> 400 m), compute direct driving estimate
    if (minDist > 400.0) {
      return calculateEstimatedDrivingMeters(currentPos, targetPos);
    }

    double remaining = minDist;
    for (int i = closestIdx; i < polyline.length - 1; i++) {
      remaining += calculateHaversineMeters(polyline[i], polyline[i + 1]);
    }
    return remaining;
  }

  /// Estimate emergency ambulance arrival minutes at 35 km/h average urban speed.
  static int estimateEtaMinutes(double meters) {
    if (meters <= 50.0) return 0;
    final minutes = ((meters / 1000.0) / 35.0 * 60.0).ceil();
    return minutes.clamp(1, 120);
  }

  /// Calculate the driving heading/bearing between two coordinates in degrees (0 - 360)
  static double calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * math.pi / 180.0;
    final startLng = start.longitude * math.pi / 180.0;
    final endLat = end.latitude * math.pi / 180.0;
    final endLng = end.longitude * math.pi / 180.0;

    final dLng = endLng - startLng;
    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);
    final deg = math.atan2(y, x) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  /// Clear cache
  static void clearCache() {
    _routeCache.clear();
  }
}
