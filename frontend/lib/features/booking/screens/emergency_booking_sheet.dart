import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../../hospitals/providers/hospital_provider.dart';
import '../../hospitals/screens/hospital_finder_screen.dart';
import 'searching_ambulance_screen.dart';

class EmergencyBookingSheet extends ConsumerStatefulWidget {
  const EmergencyBookingSheet({super.key});

  @override
  ConsumerState<EmergencyBookingSheet> createState() =>
      _EmergencyBookingSheetState();
}

class EmergencyCategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final String fare;
  final String notes;

  const EmergencyCategoryItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.fare,
    required this.notes,
  });
}

class _EmergencyBookingSheetState extends ConsumerState<EmergencyBookingSheet> {
  String _selectedCategory = 'Cardiac / Heart';
  final _patientNameController = TextEditingController();
  final _notesController = TextEditingController();

  static const List<EmergencyCategoryItem> _categories = [
    EmergencyCategoryItem(
      name: 'Cardiac / Heart',
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444),
      fare: '₹2,500 (ALS)',
      notes: 'Requires high-flow oxygen, continuous ECG monitor, defibrillator & cardiac resuscitation kit.',
    ),
    EmergencyCategoryItem(
      name: 'Accident / Trauma',
      icon: Icons.warning_rounded,
      color: Color(0xFFF59E0B),
      fare: '₹1,800 (ALS)',
      notes: 'Requires spinal board, cervical collar, trauma dressings & rapid blood transfusion kit.',
    ),
    EmergencyCategoryItem(
      name: 'Breathing Difficulty',
      icon: Icons.air_rounded,
      color: Color(0xFF3B82F6),
      fare: '₹1,800 (ALS)',
      notes: 'Requires high-flow oxygen mask, nebulizer & CPAP/ventilator life support.',
    ),
    EmergencyCategoryItem(
      name: 'Pregnancy / Maternity',
      icon: Icons.pregnant_woman_rounded,
      color: Color(0xFFEC4899),
      fare: '₹1,500 (BLS)',
      notes: 'Requires sterile obstetric delivery kit, neonatal suction & incubator standby.',
    ),
    EmergencyCategoryItem(
      name: 'Stroke / Neurological',
      icon: Icons.psychology_rounded,
      color: Color(0xFF8B5CF6),
      fare: '₹2,200 (ALS)',
      notes: 'Requires stroke thrombolysis protocol, blood glucose kit & rapid CT referral.',
    ),
    EmergencyCategoryItem(
      name: 'Pediatric / Child',
      icon: Icons.child_care_rounded,
      color: Color(0xFF06B6D4),
      fare: '₹1,400 (BLS)',
      notes: 'Requires pediatric life-support stretcher, infant airway tools & pediatric paramedic.',
    ),
    EmergencyCategoryItem(
      name: 'Severe Burn Injury',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEA580C),
      fare: '₹2,000 (ALS)',
      notes: 'Requires sterile burn trauma dressing sheets, IV fluid resuscitation & pain management.',
    ),
    EmergencyCategoryItem(
      name: 'Poisoning / Snakebite',
      icon: Icons.science_rounded,
      color: Color(0xFF0D9488),
      fare: '₹1,900 (ALS)',
      notes: 'Requires polyvalent anti-venom kit, gastric lavage equipment & toxicology antidotes.',
    ),
    EmergencyCategoryItem(
      name: 'Senior / Geriatric',
      icon: Icons.elderly_rounded,
      color: Color(0xFF6366F1),
      fare: '₹1,200 (BLS)',
      notes: 'Requires hydraulic roll-in stretcher, cardiac monitor & wheelchair ramp transfer.',
    ),
    EmergencyCategoryItem(
      name: 'General Emergency',
      icon: Icons.medical_services_rounded,
      color: Color(0xFF10B981),
      fare: '₹1,200 (BLS)',
      notes: 'Requires rapid BLS paramedic assessment, vitals monitor & first-aid support.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Automatically fill assistance notes based on the initial category
    _notesController.text = _categories.first.notes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hospitalProvider.notifier).setCategory(_selectedCategory);
    });
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final hospitalState = ref.watch(hospitalProvider);
    final authState = ref.watch(authProvider);
    final locale = authState.selectedLocale;
    final selectedHospital = hospitalState.selectedDestinationHospital;
    final nearestHospital = hospitalState.filteredHospitals.isNotEmpty
        ? hospitalState.filteredHospitals.first
        : (hospitalState.hospitals.isNotEmpty ? hospitalState.hospitals.first : null);

    final userLat = bookingState.currentLat;
    final userLng = bookingState.currentLng;
    final rawDest = selectedHospital ?? nearestHospital;
    final destDistKm = (rawDest != null && userLat != 0.0 && userLng != 0.0)
        ? LocationService.calculateDrivingDistanceKm(userLat, userLng, rawDest.lat, rawDest.lng)
        : (rawDest?.distanceKm ?? 0.0);
    final destEta = (destDistKm * 2.4).ceil().clamp(2, 60);
    final destHospital = rawDest?.copyWith(
      distanceKm: double.parse(destDistKm.toStringAsFixed(1)),
      estimatedDriveTime: '$destEta min',
    );

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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

            // Emergency Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
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
                        AppLocalizations.tr(
                          'dispatchEmergencyAmbulance',
                          locale,
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppLocalizations.tr('dispatchSub', locale),
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
            const SizedBox(height: 18),

            // Pickup Location summary with Full Address
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.tr('pickupAddress', locale),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bookingState.currentFullAddress.isNotEmpty
                              ? bookingState.currentFullAddress
                              : bookingState.currentAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ⚡ 1-TAP INSTANT DISPATCH BUTTON (Zero-Delay Panic Mode)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.38),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchingAmbulanceScreen(
                          category: _selectedCategory,
                          landmark: 'GPS Pinpoint Location',
                          notes: _notesController.text.isNotEmpty
                              ? _notesController.text
                              : 'Instant Emergency Dispatch requested',
                          destinationHospital: destHospital,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on_rounded, color: Colors.yellowAccent, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'ASSURANCE • ZERO-DELAY IMMEDIATE DISPATCH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: AppColors.primaryRed,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '1-TAP INSTANT DISPATCH',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destHospital != null
                                        ? 'To: ${destHospital.name} (${destHospital.distanceKm} km • ${destHospital.estimatedDriveTime})'
                                        : 'Alert nearest 108/ALS ambulance to your live GPS',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GO',
                                    style: TextStyle(
                                      color: AppColors.primaryRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.primaryRed,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: Divider(color: AppColors.borderLight)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR CUSTOMIZE DETAILS BELOW',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.borderLight)),
              ],
            ),
            const SizedBox(height: 12),

            // Emergency Categories (Quick Chips with 10 options)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emergency Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_categories.length} Types Available',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        children: [
                          Icon(
                            cat.icon,
                            size: 15,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          const SizedBox(width: 6),
                          Text(cat.name),
                        ],
                      ),
                      selectedColor: AppColors.primaryRed,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryRed
                              : AppColors.border,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat.name;
                            // Automatically fill assistance notes based on the chosen emergency category
                            _notesController.text = cat.notes;
                          });
                          ref.read(hospitalProvider.notifier).setCategory(cat.name);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Optional Destination Hospital (Clickable to view surrounding hospitals)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      color: AppColors.primaryRed,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Destination Hospital',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (selectedHospital != null)
                  GestureDetector(
                    onTap: () => ref
                        .read(hospitalProvider.notifier)
                        .selectHospital(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Optional',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final b = ref.read(bookingProvider);
                  ref
                      .read(hospitalProvider.notifier)
                      .fetchNearbyHospitals(
                        lat: b.currentLat,
                        lng: b.currentLng,
                        category: _selectedCategory,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HospitalFinderScreen(
                        isSelectionMode: true,
                        category: _selectedCategory,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedHospital != null
                        ? const Color(0xFFF0FDF4)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedHospital != null
                          ? AppColors.success
                          : AppColors.border,
                      width: selectedHospital != null ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: selectedHospital != null
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedHospital.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${destHospital?.distanceKm ?? selectedHospital.distanceKm} km away • ${destHospital?.estimatedDriveTime ?? selectedHospital.estimatedDriveTime} ETA',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              color: AppColors.textMuted,
                              size: 18,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_hospital_rounded,
                                color: AppColors.primaryRed,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nearestHospital != null
                                        ? 'Default ($_selectedCategory): ${nearestHospital.name}'
                                        : 'Choose Destination Hospital',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    destHospital != null
                                        ? '${destHospital.distanceKm} km • ${destHospital.estimatedDriveTime} • Tap to change'
                                        : 'Tap to select from surrounding emergency centers',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppColors.primaryRed,
                              size: 14,
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Paramedic Assistance Notes Header with Auto-fill Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.primaryRed,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.tr('assistanceNotes', locale),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        AppLocalizations.tr('autoFilled', locale),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(
                hintText:
                    'Special assistance notes or paramedic equipment needed...',
                prefixIcon: Icon(
                  Icons.note_alt_outlined,
                  size: 20,
                  color: AppColors.primaryRed,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Red Gradient Action Button to Confirm Dispatch
            Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.redGlowShadow,
              ),
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // close sheet

                  // Open searching screen with the category-matched destination hospital
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SearchingAmbulanceScreen(
                        category: _selectedCategory,
                        landmark: 'GPS Pinpoint Location',
                        notes: _notesController.text,
                        destinationHospital: destHospital,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.tr('dispatchNow', locale),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
