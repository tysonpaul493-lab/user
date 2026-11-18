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
  String? _lastFittedRouteSignature;
  DateTime? _lastUserInteraction;
  final ValueNotifier<double> _rotationNotifier = ValueNotifier<double>(0.0);

  static bool _isValidLatLng(LatLng? p) =>
      p != null &&
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      !(p.latitude == 0.0 && p.longitude == 0.0);

  @override
  void initState() {
    super.initState();
    _effectiveMapController = widget.mapController ?? MapController();
  }

  @override
  void dispose() {
    _rotationNotifier.dispose();
    super.dispose();
  }

  String _routeFitSignature() {
    final ambLen = widget.routePoints?.length ?? 0;
    final ambEnd = ambLen > 0 ? widget.routePoints!.last : null;
    final hospLen = widget.hospitalRoutePoints?.length ?? 0;
    final hospEnd = hospLen > 0 ? widget.hospitalRoutePoints!.last : null;
    return '$ambLen:${ambEnd?.latitude.toStringAsFixed(3)},${ambEnd?.longitude.toStringAsFixed(3)}|'
        '$hospLen:${hospEnd?.latitude.toStringAsFixed(3)},${hospEnd?.longitude.toStringAsFixed(3)}|'
        '${widget.hospitalPosition?.latitude.toStringAsFixed(3)},${widget.hospitalPosition?.longitude.toStringAsFixed(3)}';
  }

  void _fitActiveBoundsIfNeeded({bool force = false}) {
    if (!_isMapReady) return;
    if (!force) {
      final now = DateTime.now();
      if (_lastUserInteraction != null && now.difference(_lastUserInteraction!).inSeconds < 10) {
        return; // Preserve user's manual zoom level
      }
    }
    final sig = _routeFitSignature();
    final hasRoutes = (widget.routePoints != null && widget.routePoints!.length >= 2) ||
        (widget.hospitalRoutePoints != null && widget.hospitalRoutePoints!.length >= 2);
    if (!force && !hasRoutes) return;
    if (!force && _lastFittedRouteSignature == sig) return;

    final points = <LatLng>[
      if (widget.routePoints != null) ...widget.routePoints!.where(_isValidLatLng),
      if (widget.hospitalRoutePoints != null) ...widget.hospitalRoutePoints!.where(_isValidLatLng),
      if (_isValidLatLng(widget.userPosition)) widget.userPosition!,
      if (_isValidLatLng(widget.driverPosition)) widget.driverPosition!,
      if (_isValidLatLng(widget.hospitalPosition)) widget.hospitalPosition!,
    ];

    if (points.length >= 2) {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _effectiveMapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(48, 120, 48, 190),
            maxZoom: 16.5,
          ),
        );
        _lastFittedRouteSignature = sig;
        return;
      } catch (_) {}
    }

    if (force) {
      try {
        final target = _isValidLatLng(widget.userPosition)
            ? widget.userPosition!
            : widget.center;
        _effectiveMapController.moveAndRotate(target, 15.5, 0.0);
        _rotationNotifier.value = 0.0;
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant CustomMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isMapReady) return;

    final now = DateTime.now();
    final recentlyInteracted = _lastUserInteraction != null &&
        now.difference(_lastUserInteraction!).inSeconds < 10;

    // Never override camera if the user is zooming or panning
    if (recentlyInteracted) {
      return;
    }

    final hasRoute = (widget.routePoints != null && widget.routePoints!.length >= 2) ||
        (widget.hospitalRoutePoints != null && widget.hospitalRoutePoints!.length >= 2);

    if (hasRoute) {
      _fitActiveBoundsIfNeeded();
      return;
    }

    final latDelta = (widget.center.latitude - oldWidget.center.latitude).abs();
    final lngDelta = (widget.center.longitude - oldWidget.center.longitude).abs();
    if (latDelta > 0.0002 || lngDelta > 0.0002) {
      try {
        final camera = _effectiveMapController.camera;
        _effectiveMapController.move(widget.center, camera.zoom);
      } catch (_) {}
    }
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    _lastUserInteraction = DateTime.now();
    try {
      final camera = _effectiveMapController.camera;
      final targetZoom = (camera.zoom + 1.0).clamp(3.5, 19.5);
      _effectiveMapController.move(camera.center, targetZoom);
    } catch (_) {}
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    _lastUserInteraction = DateTime.now();
    try {
      final camera = _effectiveMapController.camera;
      final targetZoom = (camera.zoom - 1.0).clamp(3.5, 19.5);
      _effectiveMapController.move(camera.center, targetZoom);
    } catch (_) {}
  }

  void _resetRotation() {
    if (!_isMapReady) return;
    try {
      _effectiveMapController.rotate(0.0);
      _rotationNotifier.value = 0.0;
    } catch (_) {}
  }

  void _recenter() {
    _lastUserInteraction = null;
    _fitActiveBoundsIfNeeded(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    // 1. User Pickup Pin Marker
    final effectiveUserPos = _isValidLatLng(widget.userPosition)
        ? widget.userPosition!
        : widget.center;
    if (_isValidLatLng(effectiveUserPos)) {
      markers.add(
        Marker(
          point: effectiveUserPos,
          width: 58,
          height: 58,
          child: _buildUserPinMarker(),
        ),
      );
    }

    // 2. Destination Hospital Marker (Always visible with clear hospital badge)
    if (_isValidLatLng(widget.hospitalPosition)) {
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
    if (_isValidLatLng(widget.driverPosition)) {
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
            minZoom: 3.5,
            maxZoom: 19.5,
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fitActiveBoundsIfNeeded();
                });
              }
            },
            onTap: (_, pos) {
              widget.onMapCoordinateTap?.call(pos);
              widget.onMapTap?.call();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture) {
                _lastUserInteraction = DateTime.now();
                widget.onPositionChanged?.call(camera.center);
              }
              if ((_rotationNotifier.value - camera.rotation).abs() > 0.2) {
                _rotationNotifier.value = camera.rotation;
              }
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.doubleTapDragZoom |
                  InteractiveFlag.scrollWheelZoom |
                  InteractiveFlag.pinchMove,
              pinchZoomThreshold: 0.08,
              pinchMoveThreshold: 8.0,
              scrollWheelVelocity: 0.005,
              enableMultiFingerGestureRace: false,
            ),
          ),
          children: [
            // Standard OpenStreetMap daylight roadmap tile layer with native memory caching
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.liferoute.emergency',
              maxZoom: 19.5,
              maxNativeZoom: 18,
              keepBuffer: 3,
              panBuffer: 1,
              tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 60)),
              evictErrorTileStrategy: EvictErrorTileStrategy.none,
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

        // 3. Floating Quick Recenter, Compass & Smooth Zoom Controls
        Positioned(
          right: 14,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom In (+)
              _buildMapControlButton(
                icon: Icons.add_rounded,
                onTap: _zoomIn,
                tooltip: 'Zoom In',
              ),
              const SizedBox(height: 8),

              // Zoom Out (-)
              _buildMapControlButton(
                icon: Icons.remove_rounded,
                onTap: _zoomOut,
                tooltip: 'Zoom Out',
              ),
              const SizedBox(height: 8),

              ValueListenableBuilder<double>(
                valueListenable: _rotationNotifier,
                builder: (context, rotation, child) {
                  if (rotation.abs() <= 0.05) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildMapControlButton(
                      icon: Icons.navigation_rounded,
                      onTap: _resetRotation,
                      tooltip: 'Reset North',
                      iconColor: AppColors.primaryRed,
                      rotationAngle: -rotation * (math.pi / 180.0),
                    ),
                  );
                },
              ),
              _buildMapControlButton(
                icon: Icons.my_location_rounded,
                onTap: _recenter,
                tooltip: 'Recenter on Pickup',
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
    Color? iconColor,
    double? rotationAngle,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 42,
        height: 42,
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
            child: Center(
              child: rotationAngle != null && rotationAngle != 0.0
                  ? Transform.rotate(
                      angle: rotationAngle,
                      child: Icon(icon, size: 20, color: iconColor ?? AppColors.textPrimary),
                    )
                  : Icon(icon, size: 20, color: iconColor ?? AppColors.textPrimary),
            ),
          ),
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
