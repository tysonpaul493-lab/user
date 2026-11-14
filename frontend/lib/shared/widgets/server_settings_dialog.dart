import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/providers/booking_provider.dart';

/// Shows the Dispatch Server Connection dialog so standalone APKs can connect
/// over Wi-Fi LAN IP or USB loopback for both REST API and live tracking WebSockets.
Future<void> showUserServerSettingsDialog(BuildContext context, WidgetRef ref) async {
  final storage = ref.read(storageServiceProvider);
  final stored = storage.getServerHost();
  final controller = TextEditingController(
    text: (stored != null && stored.isNotEmpty) ? stored : AppConstants.effectiveHost,
  );

  bool isTesting = false;
  bool? isHealthy;
  String? statusText;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: AppColors.primaryRed, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispatch Server Connection',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your dispatch computer IP address when testing across phones on the same Wi-Fi (or keep 127.0.0.1 over USB cable).',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Server Host / LAN IP',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    hintText: 'e.g. 192.168.1.10 or 127.0.0.1',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryRed),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Active API: ${AppConstants.defaultLocalBaseUrl}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
                if (statusText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isHealthy == true ? AppColors.successBg : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isHealthy == true ? AppColors.success : AppColors.primaryRed)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isHealthy == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isHealthy == true ? AppColors.success : AppColors.primaryRed,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText!,
                            style: TextStyle(
                              color: isHealthy == true ? AppColors.success : AppColors.primaryRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      AppConstants.setServerHost(null);
                      await storage.setServerHost(null);
                      ref.read(apiClientProvider).refreshBaseUrl();
                      ref.read(reverbServiceProvider).reconnectIfActive();
                      controller.text = AppConstants.effectiveHost;
                      setState(() {
                        isHealthy = null;
                        statusText = 'Reset to automatic host (${AppConstants.effectiveHost}).';
                      });
                    },
              child: const Text(
                'Reset Auto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setState(() {
                        isTesting = true;
                        statusText = null;
                      });
                      final raw = controller.text.trim();
                      AppConstants.setServerHost(raw);
                      await storage.setServerHost(
                        AppConstants.hasCustomServerHost ? AppConstants.effectiveHost : null,
                      );
                      final api = ref.read(apiClientProvider);
                      api.refreshBaseUrl();
                      ref.read(reverbServiceProvider).reconnectIfActive();
                      final ok = await api.checkHealth();
                      if (!ctx.mounted) return;
                      setState(() {
                        isTesting = false;
                        isHealthy = ok;
                        statusText = ok
                            ? 'Connected to Dispatch Server (${AppConstants.effectiveHost})'
                            : 'Saved host (${AppConstants.effectiveHost}), but server did not respond on port 8000.';
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
              child: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save & Test',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}

