import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class RouteProgressBar extends StatefulWidget {
  final int etaMinutes;
  final double? distanceKm;
  final String? phaseLabel;
  final double progress; // 0.0 to 1.0

  const RouteProgressBar({
    super.key,
    required this.etaMinutes,
    this.distanceKm,
    this.phaseLabel,
    this.progress = 0.55,
  });

  @override
  State<RouteProgressBar> createState() => _RouteProgressBarState();
}

class _RouteProgressBarState extends State<RouteProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatDistanceKm(double? km) {
    if (km == null) return '';
    if (km <= 0.0) return '0 m';
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isArrived = widget.progress >= 0.98 || widget.etaMinutes <= 0;
    final distText = _formatDistanceKm(widget.distanceKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live ETA & Road KM Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArrived ? 'Ambulance Status' : (widget.phaseLabel ?? 'Arriving in'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (distText.isNotEmpty)
                  Text(
                    isArrived ? 'At destination' : '$distText remaining',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isArrived ? AppColors.success : AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isArrived ? 'Arrived!' : '${widget.etaMinutes} min',
                      style: TextStyle(
                        color: isArrived ? AppColors.success : AppColors.primaryRed,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!isArrived && distText.isNotEmpty)
                      Text(
                        distText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Animated Progress Track with moving ambulance icon synchronized to route progress
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final progressFactor = widget.progress.clamp(0.0, 1.0);
            final ambulanceX = (trackWidth - 42) * progressFactor;

            return SizedBox(
              height: 32,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Background Track
                  Container(
                    height: 5,
                    width: trackWidth,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Active Filled Red Line (Moving towards the end line simultaneously with ambulance)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    height: 5,
                    width: (trackWidth * progressFactor).clamp(4.0, trackWidth),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Destination User Dot on Right
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isArrived ? AppColors.success : AppColors.primaryRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Moving Ambulance Vehicle on the progress line
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    left: ambulanceX.clamp(0.0, trackWidth - 42),
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_animController.value * 2.0, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emergency_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 3),
                                // Strobe Emergency Light (Blue & Amber flashing)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _animController.value > 0.5 ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _animController.value > 0.5 ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
