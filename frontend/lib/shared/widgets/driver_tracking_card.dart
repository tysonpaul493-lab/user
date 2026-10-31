import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/driver_model.dart';

class DriverTrackingCard extends StatelessWidget {
  final DriverModel driver;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const DriverTrackingCard({
    super.key,
    required this.driver,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Driver Avatar with Online Indicator
          Stack(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                  color: const Color(0xFFE5E7EB),
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Driver Name and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Red bold driver name (matching reference image)
                Text(
                  driver.name,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  driver.title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        driver.ambulanceNumber,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                    Text(
                      '${driver.rating}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Circular Red Gradient Action Buttons (Matching reference image)
          Row(
            children: [
              // Call Button
              _buildGradientIconButton(
                icon: Icons.call_rounded,
                onTap: onCall,
                tooltip: 'Call Driver',
              ),
              const SizedBox(width: 10),

              // Message/Chat Button
              _buildGradientIconButton(
                icon: Icons.chat_bubble_rounded,
                onTap: onChat,
                tooltip: 'Message Driver',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradientIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.buttonGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
