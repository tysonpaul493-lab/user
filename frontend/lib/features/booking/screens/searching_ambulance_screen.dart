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

  const SearchingAmbulanceScreen({
    super.key,
    required this.category,
    required this.landmark,
    required this.notes,
    this.destinationHospital,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Reference Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Radar Center
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radar rings
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) {
                            return Container(
                              width: 220 * _radarController.value,
                              height: 220 * _radarController.value,
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
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.redGlowShadow,
                          ),
                          child: const Icon(
                            Icons.emergency_share_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Locating Nearest Ambulance...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connecting with certified rapid-response paramedics and GPS tracking units in your sector.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Bottom Cancel & Help options
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.emergency_rounded, color: AppColors.primaryRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency: ${widget.category}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        if (widget.destinationHospital != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.local_hospital_rounded, color: AppColors.primaryRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Destination: ${widget.destinationHospital!.name} (${widget.destinationHospital!.distanceKm} km • ${widget.destinationHospital!.estimatedDriveTime})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.my_location_rounded, color: AppColors.textSecondary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pickup: ${bookingState.currentAddress}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => _confirmCancel(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Cancel Request',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
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
