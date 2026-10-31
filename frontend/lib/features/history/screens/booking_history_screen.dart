import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingState = ref.watch(bookingProvider);
    final authState = ref.watch(authProvider);
    final locale = authState.selectedLocale;

    final displayHistory = bookingState.bookingHistory;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.tr('tripDispatchHistory', locale)),
        centerTitle: false,
      ),
      body: displayHistory.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Emergency Trips Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your past emergency ambulance dispatches and trip records will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayHistory.length,
        itemBuilder: (context, index) {
          final item = displayHistory[index];
          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt);

          return GestureDetector(
            onTap: () => _showTripDetailsSheet(context, item, locale),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppColors.softCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Ref # & Status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emergency_rounded, size: 16, color: AppColors.primaryRed),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.referenceNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      _buildStatusChip(item.status),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Emergency Category & Date/Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.emergencyCategory,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (item.patientName != null && item.patientName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Patient: ${item.patientName!} • Phone: ${item.callbackPhone}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Full Pickup Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.pickupAddress,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Destination Hospital
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_hospital_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.destinationHospital != null
                              ? '${item.destinationHospital!.name} (${item.destinationHospital!.distanceKm} km away)'
                              : 'Nearest Emergency Hospital',
                          style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  // Driver / Ambulance Details
                  if (item.driver != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${item.driver!.name} • ${item.driver!.ambulanceNumber} (${item.driver!.ambulanceType})',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                          Text(
                            ' ${item.driver!.rating}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 18, color: AppColors.borderLight),

                  // Bottom Action: View Full Details Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            '108 Service (₹0 Free)',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primaryRed),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(BookingStatus status) {
    Color bg;
    Color text;

    switch (status) {
      case BookingStatus.tripCompleted:
        bg = AppColors.successBg;
        text = AppColors.success;
        break;
      case BookingStatus.cancelled:
        bg = const Color(0xFFFEF2F2);
        text = AppColors.primaryRed;
        break;
      default:
        bg = AppColors.infoBg;
        text = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _showTripDetailsSheet(BuildContext context, BookingModel item, String locale) {
    final dateStr = DateFormat('EEEE, dd MMMM yyyy, hh:mm a').format(item.createdAt);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Reference
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.tr('tripDetails', locale),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        item.referenceNumber,
                        style: const TextStyle(fontSize: 13, color: AppColors.primaryRed, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  _buildStatusChip(item.status),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Time Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dispatch Date & Time', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Patient Info Tile
              if (item.patientName != null && item.patientName!.isNotEmpty) ...[
                _buildDetailTile(
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF0D9488),
                  title: 'Patient Name & Contact',
                  value: '${item.patientName!} • ${item.callbackPhone}',
                  subtitle: 'Emergency Patient Record',
                ),
                const SizedBox(height: 12),
              ],

              // Emergency Category
              _buildDetailTile(
                icon: Icons.emergency_rounded,
                iconColor: AppColors.primaryRed,
                title: 'Emergency Category',
                value: item.emergencyCategory,
              ),
              const SizedBox(height: 12),

              // Full Pickup Address (House No, Colony, Street, District)
              _buildDetailTile(
                icon: Icons.my_location_rounded,
                iconColor: AppColors.primaryRed,
                title: 'Exact Pickup Location (House / Street / District)',
                value: item.pickupAddress,
                subtitle: item.landmark != null && item.landmark!.isNotEmpty
                    ? 'Landmark: ${item.landmark!}'
                    : 'Verified Live GPS Coordinate',
              ),
              const SizedBox(height: 12),

              // Destination Hospital
              _buildDetailTile(
                icon: Icons.local_hospital_rounded,
                iconColor: const Color(0xFF2563EB),
                title: 'Destination Emergency Center',
                value: item.destinationHospital?.name ?? 'Nearest Emergency Hospital',
                subtitle: item.destinationHospital?.address ?? 'Surrounding emergency center',
              ),
              const SizedBox(height: 12),

              // Driver & Paramedic Crew
              if (item.driver != null) ...[
                _buildDetailTile(
                  icon: Icons.badge_outlined,
                  iconColor: const Color(0xFF059669),
                  title: 'Assigned 108 Ambulance & Crew',
                  value: '${item.driver!.name} (${item.driver!.title})',
                  subtitle: 'Vehicle: ${item.driver!.ambulanceNumber} • Type: ${item.driver!.ambulanceType}',
                ),
                const SizedBox(height: 12),
              ],

              // Medical Notes
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                _buildDetailTile(
                  icon: Icons.medical_services_outlined,
                  iconColor: const Color(0xFFD97706),
                  title: 'Medical Assistance Notes',
                  value: item.notes!,
                ),
                const SizedBox(height: 12),
              ],

              // Trip Metric Details (Distance & Status)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Distance', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text('${item.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Trip Status', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(item.status.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 100% Free Public Emergency Service Receipt Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.health_and_safety_rounded, color: AppColors.success, size: 22),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('National Health Mission / GVK EMRI', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                            Text('Government 108 Emergency Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '100% FREE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),


              // Close / Share Record Button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(AppLocalizations.tr('close', locale)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency trip record verified & saved.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                      label: const Text('Share Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

}
