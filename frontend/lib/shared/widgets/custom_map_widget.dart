import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';

class CustomMapWidget extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng>? routePoints;
  final List<LatLng>? hospitalRoutePoints;
  final LatLng? driverPosition;
  final double driverHeading;
  final LatLng? userPosition;
  final LatLng? hospitalPosition;
  final String? hospitalName;
  final MapController? mapController;
  final bool showUserPulse;
  final VoidCallback? onMapTap;
  final void Function(LatLng position)? onPositionChanged;
  final void Function(LatLng tappedPosition)? onMapCoordinateTap;

  const CustomMapWidget({
    super.key,
    required this.center,
    this.zoom = 14.8,
    this.routePoints,
    this.hospitalRoutePoints,
    this.driverPosition,
    this.driverHeading = 0.0,
    this.userPosition,
    this.hospitalPosition,
    this.hospitalName,
    this.mapController,
    this.showUserPulse = true,
    this.onMapTap,
    this.onPositionChanged,
    this.onMapCoordinateTap,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // 1. User Pickup Pin Marker (Matching reference image)
    final effectiveUserPos = userPosition ?? center;
    markers.add(
      Marker(
        point: effectiveUserPos,
        width: 52,
        height: 52,
        child: _buildUserPinMarker(),
      ),
    );

    // 2. Driver Ambulance Marker (Matching reference image)
    if (driverPosition != null) {
      markers.add(
        Marker(
          point: driverPosition!,
          width: 54,
          height: 54,
          child: _buildDriverAmbulanceMarker(),
        ),
      );
    }

    // 3. Destination Hospital Marker (If selected)
    if (hospitalPosition != null) {
      markers.add(
        Marker(
          point: hospitalPosition!,
          width: 130,
          height: 64,
          child: _buildHospitalMarker(hospitalName ?? 'Hospital'),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: (_, pos) {
          onMapCoordinateTap?.call(pos);
          onMapTap?.call();
        },
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            onPositionChanged?.call(camera.center);
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // Clean OpenStreetMap Tile Layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.liferoute.emergency_user',
          maxZoom: 19,
        ),

        // Route Polylines (Real road networks via OSRM, NOT straight lines)
        PolylineLayer(
          polylines: [
            // Hospital Route Polyline (Medical Blue road pathway from user to destination)
            if (hospitalRoutePoints != null && hospitalRoutePoints!.length > 1)
              Polyline(
                points: hospitalRoutePoints!,
                strokeWidth: 5.0,
                color: const Color(0xFF2563EB),
                borderColor: const Color(0xFFBFDBFE),
                borderStrokeWidth: 2.0,
              ),

            // Ambulance Route Polyline (Vibrant Red road pathway from ambulance to user)
            if (routePoints != null && routePoints!.length > 1)
              Polyline(
                points: routePoints!,
                strokeWidth: 5.5,
                color: AppColors.primaryRed,
                borderColor: const Color(0xFFFFC1C1),
                borderStrokeWidth: 2.0,
              ),
          ],
        ),

        // Markers Layer
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildUserPinMarker() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer live pulsing radar accuracy ring
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryRed.withValues(alpha: 0.18),
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          // Inner solid circle with white border and GPS center icon
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.my_location_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAmbulanceMarker() {
    return Transform.rotate(
      angle: (driverHeading * 3.1415926535) / 180,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalMarker(String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }
}
