import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/route_service.dart';
import '../../../models/hospital_model.dart';
import '../../auth/providers/auth_provider.dart';

class HospitalState {
  final List<HospitalModel> hospitals;
  final bool isLoading;
  final String searchQuery;
  final String? selectedFilter;
  final String? activeCategory;
  final HospitalModel? selectedDestinationHospital;
  final List<LatLng>? roadRouteToDestination;
  final bool isLoadingRoute;
  final double? userLat;
  final double? userLng;

  HospitalState({
    this.hospitals = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedFilter,
    this.activeCategory,
    this.selectedDestinationHospital,
    this.roadRouteToDestination,
    this.isLoadingRoute = false,
    this.userLat,
    this.userLng,
  });

  List<HospitalModel> get filteredHospitals {
    final q = searchQuery.trim().toLowerCase();
    final cat = (selectedFilter != null && selectedFilter != 'All')
        ? null
        : activeCategory?.trim().toLowerCase();

    final result = hospitals.where((h) {
      if (q.isNotEmpty) {
        final matchesName = h.name.toLowerCase().contains(q);
        final matchesAddress = h.address.toLowerCase().contains(q);
        final matchesServices = h.emergencyServices.any((s) => s.toLowerCase().contains(q));
        if (!matchesName && !matchesAddress && !matchesServices) return false;
      }

      // 1. Specialty Filter Chips ('All', 'Government (108)', 'Trauma', 'ICU', '24x7')
      if (selectedFilter != null && selectedFilter != 'All') {
        final f = selectedFilter!.toLowerCase();
        if (f.contains('gov') || f.contains('108')) {
          if (!h.isGovernment) return false;
        } else if (f.contains('trauma')) {
          final isTrauma = h.hasTraumaCenter ||
              h.name.toLowerCase().contains('trauma') ||
              h.emergencyServices.any((s) => s.toLowerCase().contains('trauma') || s.toLowerCase().contains('accident') || s.toLowerCase().contains('casualty') || s.toLowerCase().contains('ortho') || s.toLowerCase().contains('emergency'));
          if (!isTrauma) return false;
        } else if (f.contains('icu')) {
          final isIcu = h.hasIcuBed ||
              h.name.toLowerCase().contains('icu') ||
              h.name.toLowerCase().contains('multi') ||
              h.emergencyServices.any((s) => s.toLowerCase().contains('icu') || s.toLowerCase().contains('critical') || s.toLowerCase().contains('ccu') || s.toLowerCase().contains('picu') || s.toLowerCase().contains('ventilator'));
          if (!isIcu) return false;
        } else if (f.contains('24') || f.contains('7')) {
          final is24x7 = h.emergencyServices.any((s) => s.contains('24') || s.toLowerCase().contains('emergency') || s.toLowerCase().contains('casualty')) ||
              h.name.toLowerCase().contains('24') ||
              h.name.toLowerCase().contains('emergency') ||
              h.hasIcuBed ||
              h.hasTraumaCenter;
          if (!is24x7) return false;
        }
      }

      // 2. Prioritize matching specialties without filtering out un-tagged acute surrounding hospitals
      if (cat != null && cat.isNotEmpty && cat != 'all' && !h.isGovernment && h.emergencyServices.isNotEmpty) {
        final services = h.emergencyServices.map((s) => s.toLowerCase()).toList();
        final name = h.name.toLowerCase();
        if (cat.contains('cardiac') || cat.contains('heart')) {
          final match = services.any((s) => s.contains('cardiac') || s.contains('cath lab') || s.contains('ccu')) || name.contains('cardiac') || name.contains('heart');
          if (match) return true;
        } else if (cat.contains('stroke') || cat.contains('neuro')) {
          final match = services.any((s) => s.contains('stroke') || s.contains('neuro')) || name.contains('neuro') || name.contains('stroke');
          if (match) return true;
        } else if (cat.contains('pediatric') || cat.contains('child')) {
          final match = services.any((s) => s.contains('pediatric') || s.contains('nicu') || s.contains('picu')) || name.contains('child') || name.contains('pediatric');
          if (match) return true;
        }
      }

      return true;
    }).toList();

    final finalResult = (result.isEmpty && q.isEmpty && (selectedFilter == null || selectedFilter == 'All')) ? hospitals : result;

    // Sort by real proximity, giving priority boost to nearby government hospitals within 25km
    finalResult.sort((a, b) {
      final distA = (userLat != null && userLng != null && userLat != 0.0 && userLng != 0.0)
          ? LocationService.calculateDrivingDistanceKm(userLat!, userLng!, a.lat, a.lng)
          : a.distanceKm;
      final distB = (userLat != null && userLng != null && userLat != 0.0 && userLng != 0.0)
          ? LocationService.calculateDrivingDistanceKm(userLat!, userLng!, b.lat, b.lng)
          : b.distanceKm;
      final aGov = a.isGovernment && distA <= 25.0;
      final bGov = b.isGovernment && distB <= 25.0;
      if (aGov && !bGov) return -1;
      if (!aGov && bGov) return 1;
      return distA.compareTo(distB);
    });
    return finalResult;
  }

  HospitalState copyWith({
    List<HospitalModel>? hospitals,
    bool? isLoading,
    String? searchQuery,
    String? selectedFilter,
    bool clearFilter = false,
    String? activeCategory,
    bool clearCategory = false,
    HospitalModel? selectedDestinationHospital,
    bool clearSelectedHospital = false,
    List<LatLng>? roadRouteToDestination,
    bool clearRoadRoute = false,
    bool? isLoadingRoute,
    double? userLat,
    double? userLng,
  }) {
    return HospitalState(
      hospitals: hospitals ?? this.hospitals,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: clearFilter
          ? null
          : (selectedFilter ?? this.selectedFilter),
      activeCategory: clearCategory
          ? null
          : (activeCategory ?? this.activeCategory),
      selectedDestinationHospital: clearSelectedHospital
          ? null
          : (selectedDestinationHospital ?? this.selectedDestinationHospital),
      roadRouteToDestination: clearRoadRoute
          ? null
          : (roadRouteToDestination ?? this.roadRouteToDestination),
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
    );
  }
}

class HospitalNotifier extends StateNotifier<HospitalState> {
  final ApiClient _apiClient;
  double? _lastLat;
  double? _lastLng;

  HospitalNotifier(this._apiClient) : super(HospitalState());

  Future<void> fetchNearbyHospitals({double? lat, double? lng, String? category}) async {
    state = state.copyWith(isLoading: true);
    var targetLat = (lat != null && lat != 0.0)
        ? lat
        : (_lastLat != null && _lastLat != 0.0 ? _lastLat! : 0.0);
    var targetLng = (lng != null && lng != 0.0)
        ? lng
        : (_lastLng != null && _lastLng != 0.0 ? _lastLng! : 0.0);

    // If coordinates are not yet set, acquire live device GPS instead of fake default coords
    if (targetLat == 0.0 || targetLng == 0.0) {
      try {
        final loc = await LocationService.getCurrentLocation(forceHighAccuracy: false);
        if (loc.isAccurate && (loc.latitude != 0.0 || loc.longitude != 0.0)) {
          targetLat = loc.latitude;
          targetLng = loc.longitude;
        }
      } catch (_) {}
    }

    if (targetLat == 0.0 && targetLng == 0.0) {
      state = state.copyWith(isLoading: false);
      return;
    }

    _lastLat = targetLat;
    _lastLng = targetLng;
    final targetCategory = category ?? state.activeCategory;

    try {
      final rawList = await _apiClient.getNearbyHospitals(
        targetLat,
        targetLng,
        category: targetCategory,
      );
      final hospitals = rawList.map((e) {
        final h = HospitalModel.fromJson(e);
        if (targetLat != 0.0 && targetLng != 0.0 && h.lat != 0.0 && h.lng != 0.0) {
          final dist = LocationService.calculateDrivingDistanceKm(targetLat, targetLng, h.lat, h.lng);
          final eta = (dist * 2.4).ceil().clamp(2, 60);
          return h.copyWith(
            distanceKm: double.parse(dist.toStringAsFixed(1)),
            estimatedDriveTime: '$eta min',
          );
        }
        return h;
      }).toList();
      state = state.copyWith(
        isLoading: false,
        hospitals: hospitals,
        activeCategory: targetCategory,
        userLat: targetLat,
        userLng: targetLng,
      );

      // If a destination was already selected, refresh road route with current user position
      if (state.selectedDestinationHospital != null) {
        refreshRoadRoute(LatLng(targetLat, targetLng));
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setCategory(String? category) {
    state = state.copyWith(
      activeCategory: category,
      clearCategory: category == null,
    );
    if (_lastLat != null && _lastLng != null) {
      fetchNearbyHospitals(lat: _lastLat, lng: _lastLng, category: category);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String? filter) {
    if (filter == null || filter == 'All') {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(selectedFilter: filter);
    }
  }

  Future<void> _fetchAndApplyRoadRoute(HospitalModel hospital, LatLng userPosition) async {
    try {
      final route = await RouteService.getRoadRoute(
        userPosition,
        LatLng(hospital.lat, hospital.lng),
      );
      HospitalModel updatedHospital = hospital;
      if (route.length > 2) {
        final roadMeters = RouteService.calculatePolylineDistanceMeters(route);
        final roadKm = double.parse((roadMeters / 1000.0).toStringAsFixed(1));
        final roadEtaMin = RouteService.estimateEtaMinutes(roadMeters);
        updatedHospital = hospital.copyWith(
          distanceKm: roadKm,
          estimatedDriveTime: '$roadEtaMin min',
        );
      }
      state = state.copyWith(
        selectedDestinationHospital: updatedHospital,
        roadRouteToDestination: route,
        isLoadingRoute: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingRoute: false);
    }
  }

  Future<void> selectHospital(HospitalModel? hospital, {LatLng? userPosition}) async {
    if (hospital == null) {
      state = state.copyWith(
        clearSelectedHospital: true,
        clearRoadRoute: true,
        isLoadingRoute: false,
      );
      return;
    }

    state = state.copyWith(
      selectedDestinationHospital: hospital,
      isLoadingRoute: userPosition != null,
    );

    if (userPosition != null) {
      await _fetchAndApplyRoadRoute(hospital, userPosition);
    }
  }

  Future<void> refreshRoadRoute(LatLng userPosition) async {
    final hospital = state.selectedDestinationHospital;
    if (hospital == null) return;

    state = state.copyWith(isLoadingRoute: true);
    await _fetchAndApplyRoadRoute(hospital, userPosition);
  }
}

final hospitalProvider = StateNotifierProvider<HospitalNotifier, HospitalState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HospitalNotifier(apiClient);
});

