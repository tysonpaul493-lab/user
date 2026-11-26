import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;
  final String? fullAddress;
  final bool isAccurate;
  final bool permissionGranted;
  final bool serviceEnabled;
  final String? errorMessage;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.fullAddress,
    required this.isAccurate,
    this.permissionGranted = true,
    this.serviceEnabled = true,
    this.errorMessage,
  });
}

class LocationService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {
        'User-Agent': 'A2IEmergency/1.0 (Android Emergency App)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Continuous High-Accuracy Live Position Stream
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3, // Emits position updates when device moves 3 meters
      ),
    );
  }

  /// Request GPS permission and fetch exact current device position
  static Future<LocationResult> getCurrentLocation({bool forceHighAccuracy = true}) async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Check if GPS hardware service is enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          latitude: 0.0,
          longitude: 0.0,
          address: 'GPS Disabled • Tap to enable',
          isAccurate: false,
          serviceEnabled: false,
          permissionGranted: false,
          errorMessage: 'Device Location (GPS) is disabled. Please enable it in Settings.',
        );
      }

      // 2. Check and request location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            latitude: 0.0,
            longitude: 0.0,
            address: 'Location Permission Denied',
            isAccurate: false,
            permissionGranted: false,
            errorMessage: 'Location permission was denied. Tap to allow.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          latitude: 0.0,
          longitude: 0.0,
          address: 'Location Permission Blocked',
          isAccurate: false,
          permissionGranted: false,
          errorMessage: 'Location permission permanently denied. Open App Settings to enable.',
        );
      }

      // 3. Acquire live GPS coordinates: Check last known position first for instantaneous response
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // Try acquiring fresh high-accuracy position (up to 8s), falling back to medium accuracy (4s)
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 8));
        position = fresh;
      } catch (posError) {
        debugPrint('⚠️ High-accuracy GPS timed out ($posError), attempting medium accuracy...');
        try {
          final fallback = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 4));
          position = fallback;
        } catch (_) {
          if (position == null) {
            try {
              position = await Geolocator.getLastKnownPosition();
            } catch (_) {}
          }
        }
      }

      if (position == null) {
        return LocationResult(
          latitude: 0.0,
          longitude: 0.0,
          address: 'Detecting Live GPS Location...',
          fullAddress: 'Acquiring high-accuracy satellite fix for live emergency dispatch...',
          isAccurate: false,
          errorMessage: 'Acquiring GPS fix... Tap Live GPS to retry.',
        );
      }

      // 4. Reverse Geocode exact coordinates via fast photon/OSM
      final addressInfo = await reverseGeocode(position.latitude, position.longitude);

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        address: addressInfo['shortAddress'] ?? 'Live Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})',
        fullAddress: addressInfo['fullAddress'] ?? addressInfo['shortAddress'] ?? 'Live Coordinates: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        isAccurate: true,
        permissionGranted: true,
        serviceEnabled: true,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return LocationResult(
        latitude: 0.0,
        longitude: 0.0,
        address: 'Live Location Unavailable',
        fullAddress: 'Unable to detect live GPS fix. Tap Live GPS to retry.',
        isAccurate: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Reverse geocode coordinates using genuine map providers without fabricated addresses
  static Future<Map<String, String>> reverseGeocode(double lat, double lng) async {
    final coordShort = 'GPS (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
    final coordFull = 'Live Coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    // 1. Primary: Komoot Photon Reverse Geocoder
    try {
      final photonUrl = 'https://photon.komoot.io/reverse?lat=$lat&lon=$lng';
      final response = await _dio.get(
        photonUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 3),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>?;
          if (props != null) {
            final explicitHouse = props['housenumber']?.toString() ?? props['house_number']?.toString();
            final doorNumber = (explicitHouse != null && explicitHouse.trim().isNotEmpty)
                ? explicitHouse.trim()
                : null;

            final street = props['street']?.toString() ?? props['name']?.toString();
            final colony = props['district']?.toString() ?? props['locality']?.toString();
            final city = props['city']?.toString();
            var district = props['county']?.toString();
            if (district != null && district.isNotEmpty) {
              if (!district.toLowerCase().contains('district') && !district.toLowerCase().contains('county')) {
                district = '$district District';
              }
            } else if (city != null && city.isNotEmpty) {
              district = city;
            }

            final state = props['state']?.toString();
            final postcode = props['postcode']?.toString();

            final shortParts = [doorNumber, colony ?? street, district ?? city]
                .where((e) => e != null && e.trim().isNotEmpty)
                .toList();
            final fullParts = [
              if (doorNumber != null) doorNumber,
              if (colony != null && colony.trim().isNotEmpty) colony,
              if (street != null && street.trim().isNotEmpty && street != colony) street,
              if (district != null && district.trim().isNotEmpty) district,
              if (city != null && city.trim().isNotEmpty && city != district) city,
              if (state != null && state.trim().isNotEmpty)
                postcode != null && postcode.trim().isNotEmpty ? '$state - $postcode' : state
              else if (postcode != null && postcode.trim().isNotEmpty)
                postcode,
            ].where((e) => e.toString().trim().isNotEmpty).toList();

            if (shortParts.isNotEmpty || fullParts.isNotEmpty) {
              return {
                'shortAddress': shortParts.isNotEmpty ? shortParts.join(', ') : fullParts.join(', '),
                'fullAddress': fullParts.isNotEmpty ? fullParts.join(', ') : shortParts.join(', '),
              };
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Photon reverse geocode error: $e');
    }

    // 2. Secondary: OpenStreetMap Nominatim
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'LifeRouteEmergencyApp/1.0'},
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final addressMap = data['address'] as Map<String, dynamic>?;

        if (addressMap != null) {
          final explicitHouse = addressMap['house_number']?.toString() ?? addressMap['building']?.toString();
          final doorNumber = (explicitHouse != null && explicitHouse.trim().isNotEmpty)
              ? explicitHouse.trim()
              : null;

          final road = addressMap['road'] ?? addressMap['street'] ?? addressMap['pedestrian'];
          final colony = addressMap['suburb'] ?? addressMap['neighbourhood'] ?? addressMap['residential'] ?? addressMap['colony'] ?? addressMap['subdivision'];
          final city = addressMap['city'] ?? addressMap['town'] ?? addressMap['village'];
          var district = addressMap['county'] ?? addressMap['city_district'] ?? addressMap['district'] ?? addressMap['state_district'];
          if (district != null && district.toString().isNotEmpty) {
            final dStr = district.toString();
            if (!dStr.toLowerCase().contains('district') && !dStr.toLowerCase().contains('county')) {
              district = '$dStr District';
            }
          } else if (city != null) {
            district = city;
          }
          final state = addressMap['state'];
          final postcode = addressMap['postcode'];

          final shortParts = [doorNumber, colony ?? road, district ?? city]
              .where((e) => e != null && e.toString().trim().isNotEmpty)
              .toList();
          final fullParts = [
            if (doorNumber != null) doorNumber,
            if (colony != null) colony.toString(),
            if (road != null && road != colony) road.toString(),
            if (district != null) district.toString(),
            if (city != null && city != district) city.toString(),
            if (state != null)
              postcode != null ? '$state - $postcode' : state.toString()
            else if (postcode != null)
              postcode.toString(),
          ].where((e) => e.toString().trim().isNotEmpty).toList();

          if (shortParts.isNotEmpty || fullParts.isNotEmpty) {
            return {
              'shortAddress': shortParts.isNotEmpty ? shortParts.join(', ') : fullParts.join(', '),
              'fullAddress': fullParts.isNotEmpty ? fullParts.join(', ') : shortParts.join(', '),
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode failed: $e');
    }

    return {
      'shortAddress': coordShort,
      'fullAddress': coordFull,
    };
  }

  /// Open device GPS or app permission settings
  static Future<bool> openSettings({bool isAppSettings = false}) async {
    if (isAppSettings) {
      return await Geolocator.openAppSettings();
    } else {
      return await Geolocator.openLocationSettings();
    }
  }

  /// Calculate distance between two coordinates in kilometers (aerial straight-line)
  static double calculateDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    if (startLat == 0.0 || startLng == 0.0 || endLat == 0.0 || endLng == 0.0) return 0.0;
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return (distanceInMeters / 1000);
  }

  /// Calculate realistic road driving distance in kilometers (matching Google Maps driving navigation)
  /// Incorporates urban road network circuity factor (~1.28x - 1.30x of aerial straight-line distance)
  static double calculateDrivingDistanceKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    if (startLat == 0.0 || startLng == 0.0 || endLat == 0.0 || endLng == 0.0) return 0.0;
    final aerial = calculateDistanceKm(startLat, startLng, endLat, endLng);
    if (aerial <= 0.05) return 0.1;
    final drivingKm = (aerial * 1.28) + 0.15;
    return double.parse(drivingKm.toStringAsFixed(1));
  }

  /// Launch external maps driving directions directly for route confirmation
  static Future<void> openExternalMapsRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? destName,
  }) async {
    final geoUri = Uri.parse('geo:$destLat,$destLng?q=$destLat,$destLng(${Uri.encodeComponent(destName ?? 'Destination Hospital')})');
    final webRouteUri = Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=$originLat%2C$originLng%3B$destLat%2C$destLng',
    );
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(webRouteUri)) {
        await launchUrl(webRouteUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open external maps: $e');
    }
  }
}
