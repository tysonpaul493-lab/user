import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/booking_model.dart';
import '../../../models/hospital_model.dart';
import '../providers/booking_provider.dart';
import '../../tracking/screens/live_tracking_screen.dart';

class SearchingAmbulanceScreen extends ConsumerStatefulWidget {
  final String category;
  final String landmark;
  final String notes;
  final HospitalModel? destinationHospital;
  final String? patientName;
  final String? callbackPhone;

  const SearchingAmbulanceScreen({
    super.key,
    required this.category,
    required this.landmark,
    required this.notes,
    this.destinationHospital,
    this.patientName,
    this.callbackPhone,
  });

  @override
  ConsumerState<SearchingAmbulanceScreen> createState() => _SearchingAmbulanceScreenState();
}

class _SearchingAmbulanceScreenState extends ConsumerState<SearchingAmbulanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Trigger instant booking request
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingProvider.notifier).triggerInstantSos(
            patientName: widget.patientName,
            callbackPhone: widget.callbackPhone,
            category: widget.category,
            landmark: widget.landmark,
            notes: widget.notes,
            destinationHospital: widget.destinationHospital,
          );
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final booking = bookingState.activeBooking;

    // When driver is assigned, automatically navigate to Live Tracking Screen!
    ref.listen(bookingProvider, (previous, next) {
      final ab = next.activeBooking;
      if (ab != null &&
          ab.driver != null &&
          ab.status != BookingStatus.findingAmbulance) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Emergency Dispatch'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmCancel(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 620;
            final radarSize = isCompact ? 140.0 : 190.0;
            final innerCoreSize = isCompact ? 68.0 : 88.0;
            final innerIconSize = isCompact ? 32.0 : 42.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: isCompact ? 12.0 : 18.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Reference Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              booking?.referenceNumber ?? 'DISPATCHING...',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isCompact ? 12 : 20),

                      // Animated Radar Center
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: radarSize,
                            height: radarSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Radar rings
                                AnimatedBuilder(
                                  animation: _radarController,
                                  builder: (context, child) {
                                    return Container(
                                      width: radarSize * _radarController.value,
                                      height: radarSize * _radarController.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.primaryRed.withValues(
                                            alpha: (1.0 - _radarController.value).clamp(0.0, 0.8),
                                          ),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Inner pulsing core
                                Container(
                                  width: innerCoreSize,
                                  height: innerCoreSize,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.buttonGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: AppColors.redGlowShadow,
                                  ),
                                  child: Icon(
                                    Icons.emergency_share_rounded,
                                    color: Colors.white,
                                    size: innerIconSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isCompact ? 14 : 22),
                          Text(
                            'Locating Nearest Ambulance...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isCompact ? 19 : 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Connecting with certified rapid-response paramedics and GPS tracking units in your sector.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isCompact ? 12.5 : 13.5,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isCompact ? 14 : 20),

                      // Bottom Emergency Details Card & Cancel Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Details Container with spacious padding
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Emergency Category
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.emergency_rounded, color: AppColors.primaryRed, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'EMERGENCY CATEGORY',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            widget.category,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Row 2: Destination Hospital (if chosen)
                                if (widget.destinationHospital != null) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Divider(height: 1, color: AppColors.borderLight),
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF059669), size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'DESTINATION HOSPITAL',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              widget.destinationHospital!.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF064E3B),
                                                height: 1.25,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${widget.destinationHospital!.distanceKm} km • ${widget.destinationHospital!.estimatedDriveTime}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Row 3: Pickup Location
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1, color: AppColors.borderLight),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.my_location_rounded, color: AppColors.textSecondary, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'PICKUP LOCATION',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            bookingState.currentAddress.isNotEmpty
                                                ? bookingState.currentAddress
                                                : widget.landmark,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Cancel Request Button - Always 100% visible
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmCancel(context),
                              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.primaryRed),
                              label: const Text(
                                'Cancel Emergency Request',
                                style: TextStyle(
                                  color: AppColors.primaryRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Dispatch?'),
        content: const Text(
          'An ambulance may already be en route to your location. Are you sure you wish to cancel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay On Line'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(bookingProvider.notifier).cancelActiveBooking('User cancelled');
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }
}
