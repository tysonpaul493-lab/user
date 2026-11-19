import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class HeaderLocationPill extends StatelessWidget {
  final String userName;
  final String userPhone;
  final String? liveLocationAddress;
  final VoidCallback onLocationTap;
  final VoidCallback onSettingsTap;

  const HeaderLocationPill({
    super.key,
    required this.userName,
    required this.userPhone,
    this.liveLocationAddress,
    required this.onLocationTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = userName.trim();
    final trimmedPhone = userPhone.trim();
    final displayName = trimmedName.isNotEmpty
        ? trimmedName
        : (trimmedPhone.isNotEmpty ? trimmedPhone : 'Tap to set name');
    final displayPhone = trimmedPhone.isNotEmpty ? trimmedPhone : 'Tap to add mobile';
    final initialSource = trimmedName.isNotEmpty ? trimmedName : displayName;
    final initial = initialSource.isNotEmpty ? initialSource[0].toUpperCase() : 'U';
    final displayAddress = (liveLocationAddress != null && liveLocationAddress!.trim().isNotEmpty)
        ? liveLocationAddress!.trim()
        : 'Resolving Live GPS Address...';

    return Row(
      children: [
        // User Profile Red Gradient Pill (Displays User Name & Live Location)
        Expanded(
          child: GestureDetector(
            onTap: onLocationTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: AppColors.headerPillGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Trust Logo Avatar Circle
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Opacity(
                          opacity: 0.0,
                          child: Text(
                            initial,
                            style: const TextStyle(fontSize: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // User Name (Prominent) & Phone/Location Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white70,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '$displayPhone • $displayAddress',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // GPS Refresh / Detail icon
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Premium Profile Icon on Top Right Corner
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              elevation: 3,
              child: InkWell(
                onTap: onSettingsTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.headerPillGradient,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
  }
}
