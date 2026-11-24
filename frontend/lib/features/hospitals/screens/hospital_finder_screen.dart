import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/hospital_provider.dart';

class HospitalFinderScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  final String? category;

  const HospitalFinderScreen({
    super.key,
    this.isSelectionMode = false,
    this.category,
  });

  @override
  ConsumerState<HospitalFinderScreen> createState() => _HospitalFinderScreenState();
}

class _HospitalFinderScreenState extends ConsumerState<HospitalFinderScreen> {
  final _searchController = TextEditingController();
  final List<String> _filters = ['All', 'Government (108)', 'Trauma', 'ICU', '24x7'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = ref.read(bookingProvider);
      ref.read(hospitalProvider.notifier).fetchNearbyHospitals(
            lat: booking.currentLat,
            lng: booking.currentLng,
            category: widget.category,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hospitalState = ref.watch(hospitalProvider);
    final bookingState = ref.watch(bookingProvider);
    final userLat = (bookingState.currentLat != 0.0) ? bookingState.currentLat : AppConstants.defaultLat;
    final userLng = (bookingState.currentLng != 0.0) ? bookingState.currentLng : AppConstants.defaultLng;
    final hospitals = [...hospitalState.filteredHospitals];

    // Sort strictly by live geographic distance from user current coordinates
    hospitals.sort((a, b) {
      if (a.isGovernment && !b.isGovernment) return -1;
      if (!a.isGovernment && b.isGovernment) return 1;
      final distA = LocationService.calculateDistanceKm(userLat, userLng, a.lat, a.lng);
      final distB = LocationService.calculateDistanceKm(userLat, userLng, b.lat, b.lng);
      return distA.compareTo(distB);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Nearest Hospital' : 'Nearby Emergency Hospitals'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(hospitalProvider.notifier).fetchNearbyHospitals(
                  lat: bookingState.currentLat,
                  lng: bookingState.currentLng,
                  category: widget.category,
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Surrounding Location Notice Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, color: Color(0xFF2563EB), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Surrounding: ${bookingState.currentAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Emergency Category Indicator (Only when no explicit filter chip is picked)
          if (widget.category != null && widget.category!.isNotEmpty && hospitalState.selectedFilter == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                border: Border(bottom: BorderSide(color: Color(0xFFFEE2E2))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_rounded, color: AppColors.primaryRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Category: ${widget.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      'Government 1st',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search & Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => ref.read(hospitalProvider.notifier).setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search hospital name, area or trauma center...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryRed),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(hospitalProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Specialty Filter Chips ('All', 'Government (108)', 'Trauma', 'ICU', '24x7')
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((f) {
                      final isSelected = (f == 'All' && hospitalState.selectedFilter == null) ||
                          (hospitalState.selectedFilter == f);
                      IconData iconData;
                      if (f.contains('Gov')) {
                        iconData = Icons.health_and_safety_rounded;
                      } else if (f.contains('Trauma')) {
                        iconData = Icons.medical_services_rounded;
                      } else if (f.contains('ICU')) {
                        iconData = Icons.monitor_heart_rounded;
                      } else if (f.contains('24')) {
                        iconData = Icons.access_time_filled_rounded;
                      } else {
                        iconData = Icons.local_hospital_rounded;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          avatar: Icon(
                            iconData,
                            size: 14,
                            color: isSelected ? Colors.white : AppColors.primaryRed,
                          ),
                          label: Text(f),
                          selectedColor: AppColors.primaryRed,
                          backgroundColor: Colors.grey.shade50,
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryRed : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          onSelected: (_) {
                            ref.read(hospitalProvider.notifier).setFilter(f);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Hospital List View
          Expanded(
            child: hospitalState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                : hospitals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                hospitalState.searchQuery.isNotEmpty
                                    ? 'No hospitals matching "${hospitalState.searchQuery}"'
                                    : 'No emergency centers found for selected filter',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Try clearing filters or search to view all nearby hospitals in your surroundings.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(hospitalProvider.notifier).setSearchQuery('');
                                  ref.read(hospitalProvider.notifier).setFilter('All');
                                  ref.read(hospitalProvider.notifier).setCategory(null);
                                  ref.read(hospitalProvider.notifier).fetchNearbyHospitals();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                label: const Text('Show All Nearest Hospitals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: hospitals.length,
                        itemBuilder: (context, index) {
                          final hospital = hospitals[index];
                          final isSelected = hospitalState.selectedDestinationHospital?.id == hospital.id;
                          final liveDistKm = LocationService.calculateDrivingDistanceKm(userLat, userLng, hospital.lat, hospital.lng);
                          final liveEtaMin = (liveDistKm * 2.4).ceil().clamp(2, 60);

                          final cardWidget = InkWell(
                            onTap: widget.isSelectionMode
                                ? () {
                                    final selectedWithLiveDistance = hospital.copyWith(
                                          distanceKm: double.parse(liveDistKm.toStringAsFixed(1)),
                                          estimatedDriveTime: '$liveEtaMin min',
                                        );
                                    ref.read(hospitalProvider.notifier).selectHospital(
                                          selectedWithLiveDistance,
                                          userPosition: LatLng(userLat, userLng),
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Selected ${hospital.name} (${liveDistKm.toStringAsFixed(1)} km) as destination!'),
                                        backgroundColor: AppColors.primaryRed,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryRed : AppColors.borderLight,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: AppColors.softCardShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hospital.isGovernment)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                                          SizedBox(width: 6),
                                          Text(
                                            'GOVERNMENT HOSPITAL • 108 PRIORITY',
                                            style: TextStyle(
                                              color: Color(0xFF047857),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital_rounded,
                                          color: AppColors.primaryRed,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hospital.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              hospital.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Distance & Drive time badges
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.navigation_rounded, size: 12, color: AppColors.primaryRed),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${liveDistKm.toStringAsFixed(1)} km',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.successBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 12, color: AppColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$liveEtaMin min ETA',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      if (hospital.hasTraumaCenter)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'TRAUMA LEVEL 1',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryRed,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Services Chips
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: hospital.emergencyServices.map((s) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),

                                  // Open External Maps Driving Route
                                  InkWell(
                                    onTap: () {
                                      LocationService.openExternalMapsRoute(
                                        originLat: userLat,
                                        originLng: userLng,
                                        destLat: hospital.lat,
                                        destLng: hospital.lng,
                                        destName: hospital.name,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.map_rounded, size: 15, color: Color(0xFF1D4ED8)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Open Route in Maps App (${liveDistKm.toStringAsFixed(1)} km)',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Action Buttons: Call & Select Destination
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _callHospital(hospital.emergencyPhone),
                                          icon: const Icon(Icons.call_rounded, size: 16, color: AppColors.primaryRed),
                                          label: const Text('Call Emergency', style: TextStyle(color: AppColors.primaryRed)),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            side: const BorderSide(color: AppColors.primaryRed),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            ref.read(hospitalProvider.notifier).selectHospital(
                                                  hospital,
                                                  userPosition: LatLng(bookingState.currentLat, bookingState.currentLng),
                                                );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Selected ${hospital.name} as destination!'),
                                                backgroundColor: AppColors.primaryRed,
                                              ),
                                            );
                                            if (widget.isSelectionMode) {
                                              Navigator.of(context).pop();
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isSelected ? AppColors.success : AppColors.primaryRed,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: Text(
                                            isSelected ? 'Destination Set' : 'Select Destination',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (index == 0 && hospital.isGovernment)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.verified_user_rounded, color: Color(0xFF047857), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '108 GOVERNMENT HOSPITALS (TOP SUGGESTION)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF047857),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!hospital.isGovernment && index > 0 && hospitals[index - 1].isGovernment)
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.borderLight),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.near_me_rounded, color: AppColors.textSecondary, size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'OTHER SURROUNDING EMERGENCY CENTERS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              cardWidget,
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _callHospital(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
