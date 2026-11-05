import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';

class CustomMapWidget extends StatefulWidget {
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
  State<CustomMapWidget> createState() => _CustomMapWidgetState();
}

class _CustomMapWidgetState extends State<CustomMapWidget> {
  late final MapController _effectiveMapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _effectiveMapController = widget.mapController ?? MapController();
  }

  @override
  void didUpdateWidget(covariant CustomMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapReady && widget.center != oldWidget.center) {
      try {
        final zoom = _effectiveMapController.camera.zoom;
        _effectiveMapController.move(widget.center, zoom);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _effectiveMapController.camera.zoom;
      _effectiveMapController.move(_effectiveMapController.camera.center, math.min(19.0, currentZoom + 1.0));
    } catch (_) {}
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _effectiveMapController.camera.zoom;
      _effectiveMapController.move(_effectiveMapController.camera.center, math.max(4.0, currentZoom - 1.0));
    } catch (_) {}
  }

  void _recenter() {
    if (!_isMapReady) return;
    try {
      final target = widget.userPosition ?? widget.center;
      _effectiveMapController.move(target, 15.5);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // 1. User Pickup Pin Marker
    final effectiveUserPos = widget.userPosition ?? widget.center;
    markers.add(
      Marker(
        point: effectiveUserPos,
        width: 58,
        height: 58,
        child: _buildUserPinMarker(),
      ),
    );

    // 2. Destination Hospital Marker (Always visible with clear hospital badge)
    if (widget.hospitalPosition != null) {
      markers.add(
        Marker(
          point: widget.hospitalPosition!,
          width: 170,
          height: 72,
          alignment: Alignment.topCenter,
          child: _buildHospitalMarker(widget.hospitalName ?? 'Hospital Destination'),
        ),
      );
    }

    // 3. Driver Ambulance Marker
    if (widget.driverPosition != null) {
      markers.add(
        Marker(
          point: widget.driverPosition!,
          width: 56,
          height: 56,
          child: _buildDriverAmbulanceMarker(),
        ),
      );
    }

    return Stack(
      children: [
        // 1. Clean neutral base container while tiles load
        Positioned.fill(
          child: Container(
            color: const Color(0xFFE2E8F0),
          ),
        ),

        // 2. Interactive Map View with direct OpenStreetMap roadmap tiles
        FlutterMap(
          mapController: _effectiveMapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: 4.0,
            maxZoom: 19.5,
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
              }
            },
            onTap: (_, pos) {
              widget.onMapCoordinateTap?.call(pos);
              widget.onMapTap?.call();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) {
                widget.onPositionChanged?.call(camera.center);
              }
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Standard OpenStreetMap daylight roadmap tile layer with CartoDB fallback
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.liferoute.emergency',
              maxZoom: 19,
              fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            ),

            // Route Polylines (Real road networks via OSRM)
            PolylineLayer(
              polylines: [
                // Destination Hospital Route Underlay (Medical Emerald Glowing Ribbon)
                if (widget.hospitalRoutePoints != null && widget.hospitalRoutePoints!.length > 1) ...[
                  Polyline(
                    points: widget.hospitalRoutePoints!,
                    strokeWidth: 8.5,
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  ),
                  Polyline(
                    points: widget.hospitalRoutePoints!,
                    strokeWidth: 5.0,
                    color: const Color(0xFF059669),
                  ),
                ],

                // Ambulance Dispatch Route Underlay (Emergency Siren Red Ribbon)
                if (widget.routePoints != null && widget.routePoints!.length > 1) ...[
                  Polyline(
                    points: widget.routePoints!,
                    strokeWidth: 9.0,
                    color: AppColors.primaryRed.withValues(alpha: 0.35),
                  ),
                  Polyline(
                    points: widget.routePoints!,
                    strokeWidth: 5.5,
                    color: AppColors.primaryRed,
                  ),
                ],
              ],
            ),

            // Markers Layer
            MarkerLayer(markers: markers),
          ],
        ),

        // 3. Floating Quick Zoom Controls & Recenter Button
        Positioned(
          right: 14,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapControlButton(
                icon: Icons.my_location_rounded,
                onTap: _recenter,
                tooltip: 'Recenter on Pickup',
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.add_rounded,
                onTap: _zoomIn,
                tooltip: 'Zoom In',
              ),
              const SizedBox(height: 4),
              _buildMapControlButton(
                icon: Icons.remove_rounded,
                onTap: _zoomOut,
                tooltip: 'Zoom Out',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildUserPinMarker() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer live pulsing radar accuracy ring
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryRed.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.primaryRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
          // Inner solid circle with white border and GPS center icon
          Container(
            width: 28,
            height: 28,
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
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAmbulanceMarker() {
    return Transform.rotate(
      angle: (widget.driverHeading * math.pi) / 180,
      child: Container(
        width: 46,
        height: 46,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: const Color(0xFF059669), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_hospital_rounded, color: Color(0xFF059669), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
