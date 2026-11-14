import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
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
          final isGov = h.isGovernment ||
              h.name.toLowerCase().contains('government') ||
              h.name.toLowerCase().contains('108') ||
              h.name.toLowerCase().contains('cmch') ||
              h.name.toLowerCase().contains('esi') ||
              h.name.toLowerCase().contains('gh') ||
              h.emergencyServices.any((s) => s.toLowerCase().contains('108') || s.toLowerCase().contains('free') || s.toLowerCase().contains('gov'));
          if (!isGov) return false;
        } else if (f.contains('trauma')) {
          final isTrauma = h.hasTraumaCenter ||
              h.name.toLowerCase().contains('trauma') ||
              h.emergencyServices.any((s) => s.toLowerCase().contains('trauma') || s.toLowerCase().contains('accident') || s.toLowerCase().contains('casualty') || s.toLowerCase().contains('ortho'));
          if (!isTrauma) return false;
        } else if (f.contains('icu')) {
          final isIcu = h.hasIcuBed ||
              h.name.toLowerCase().contains('icu') ||
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

      // 2. Filter by Emergency Medical Category (when no top chip override is active)
      if (cat != null && cat.isNotEmpty && cat != 'all' && !h.isGovernment) {
        final services = h.emergencyServices.map((s) => s.toLowerCase()).toList();
        final name = h.name.toLowerCase();

        if (cat.contains('cardiac') || cat.contains('heart')) {
          final isCard = services.any((s) => s.contains('cardiac') || s.contains('cath lab') || s.contains('ccu')) ||
              name.contains('cardiac') ||
              name.contains('gknm') ||
              name.contains('ramakrishna') ||
              name.contains('kmch') ||
              name.contains('richmond') ||
              name.contains('kg');
          if (!isCard) return false;
        } else if (cat.contains('trauma') || cat.contains('accident')) {
          final isTrauma = h.hasTraumaCenter ||
              services.any((s) => s.contains('trauma') || s.contains('casualty') || s.contains('ortho')) ||
              name.contains('trauma') ||
              name.contains('ganga') ||
              name.contains('kmch') ||
              name.contains('ashwin') ||
              name.contains('richmond');
          if (!isTrauma) return false;
        } else if (cat.contains('breath') || cat.contains('air')) {
          final isBreath = services.any((s) => s.contains('pulmonary') || s.contains('icu') || s.contains('ventilator')) ||
              name.contains('psg') ||
              name.contains('kmch') ||
              name.contains('ramakrishna');
          if (!isBreath) return false;
        } else if (cat.contains('maternity') || cat.contains('pregnan')) {
          final isMat = services.any((s) => s.contains('maternity') || s.contains('delivery') || s.contains('neonatal')) ||
              name.contains('gknm') ||
              name.contains('psg') ||
              name.contains('masonic') ||
              name.contains('esi');
          if (!isMat) return false;
        } else if (cat.contains('stroke') || cat.contains('neuro')) {
          final isStroke = services.any((s) => s.contains('stroke') || s.contains('thrombolysis') || s.contains('neuro')) ||
              name.contains('stroke') ||
              name.contains('kg') ||
              name.contains('kmch') ||
              name.contains('royal care') ||
              name.contains('ramakrishna');
          if (!isStroke) return false;
        } else if (cat.contains('pediatric') || cat.contains('child')) {
          final isPed = services.any((s) => s.contains('pediatric') || s.contains('picu') || s.contains('nicu') || s.contains('neonatal')) ||
              name.contains('ramakrishna') ||
              name.contains('masonic') ||
              name.contains('psg') ||
              name.contains('gknm');
          if (!isPed) return false;
        } else if (cat.contains('burn')) {
          final isBurn = services.any((s) => s.contains('burn') || s.contains('plastic')) ||
              name.contains('ganga') ||
              name.contains('cmch');
          if (!isBurn) return false;
        } else if (cat.contains('poison') || cat.contains('snake')) {
          final isPoison = services.any((s) => s.contains('poison') || s.contains('toxicology') || s.contains('antivenom')) ||
              name.contains('cmch') ||
              name.contains('kg');
          if (!isPoison) return false;
        } else if (cat.contains('senior') || cat.contains('geriatric') || cat.contains('elder')) {
          final isSenior = services.any((s) => s.contains('icu') || s.contains('cardiac') || s.contains('emergency') || s.contains('dialysis')) ||
              name.contains('cmch') ||
              name.contains('kg') ||
              name.contains('ramakrishna') ||
              name.contains('gknm') ||
              name.contains('psg');
          if (!isSenior) return false;
        }
      }

      return true;
    }).toList();

    // 1st Priority: Government Hospitals at the top of the suggestion & nearest list!
    // 2nd Priority: Nearest distance in kilometers from user's live coordinates
    result.sort((a, b) {
      if (a.isGovernment && !b.isGovernment) return -1;
      if (!a.isGovernment && b.isGovernment) return 1;
      final distA = (userLat != null && userLng != null)
          ? LocationService.calculateDrivingDistanceKm(userLat!, userLng!, a.lat, a.lng)
          : a.distanceKm;
      final distB = (userLat != null && userLng != null)
          ? LocationService.calculateDrivingDistanceKm(userLat!, userLng!, b.lat, b.lng)
          : b.distanceKm;
      return distA.compareTo(distB);
    });
    return result;
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

  HospitalNotifier(this._apiClient) : super(HospitalState()) {
    fetchNearbyHospitals();
  }

  Future<void> fetchNearbyHospitals({double? lat, double? lng, String? category}) async {
    state = state.copyWith(isLoading: true);
    final targetLat = lat ?? _lastLat ?? AppConstants.defaultLat;
    final targetLng = lng ?? _lastLng ?? AppConstants.defaultLng;
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
        final dist = LocationService.calculateDrivingDistanceKm(targetLat, targetLng, h.lat, h.lng);
        final eta = (dist * 2.4).ceil().clamp(2, 60);
        return h.copyWith(
          distanceKm: double.parse(dist.toStringAsFixed(1)),
          estimatedDriveTime: '$eta min',
        );
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

