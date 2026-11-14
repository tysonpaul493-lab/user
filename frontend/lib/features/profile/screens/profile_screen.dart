import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/emergency_contact_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../history/screens/booking_history_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final locale = authState.selectedLocale;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.tr('profileSettings', locale)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Summary Card with Edit Profile Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.softCardShadow,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name.trim().isNotEmpty == true
                                  ? user!.name
                                  : (user?.phone.trim().isNotEmpty == true
                                      ? user!.phone
                                      : 'Tap Edit Profile to add name'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (user?.phone != null && user!.phone.isNotEmpty)
                                  ? user.phone
                                  : 'Mobile number not set',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            if (user?.email != null && user!.email!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                user.email!,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (user?.bloodGroup != null && user!.bloodGroup!.isNotEmpty) ? 'Blood: ${user.bloodGroup}' : 'Blood: Not set',
                                    style: const TextStyle(
                                      color: AppColors.primaryRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (user?.isGuest == true) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Guest Mode',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user?.emergencyNotes != null && user!.emergencyNotes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Medical: ${user.emergencyNotes}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditProfileSheet(context, user, locale),
                      icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.primaryRed),
                      label: Text(
                        AppLocalizations.tr('editProfile', locale),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryRed),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryRed, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Language Selector Card (English / தமிழ் / हिंदी)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.softCardShadow,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.translate_rounded, color: AppColors.primaryRed, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        AppLocalizations.tr('languageSelection', locale),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _languageOption(
                          title: 'English',
                          code: 'en',
                          isSelected: authState.selectedLocale == 'en',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _languageOption(
                          title: 'தமிழ்',
                          code: 'ta',
                          isSelected: authState.selectedLocale == 'ta',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _languageOption(
                          title: 'हिंदी',
                          code: 'hi',
                          isSelected: authState.selectedLocale == 'hi',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trip History Button
            ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookingHistoryScreen()),
                );
              },
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded, color: AppColors.primaryRed),
              ),
              title: Text(
                AppLocalizations.tr('emergencyTripHistory', locale),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                AppLocalizations.tr('tripHistorySubtitle', locale),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
            const SizedBox(height: 20),

            // Emergency Contacts Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.softCardShadow,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.contact_phone_rounded, color: AppColors.primaryRed, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.tr('emergencyContacts', locale),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryRed),
                        onPressed: () => _showAddContactDialog(context, locale),
                      ),
                    ],
                  ),
                  Text(
                    AppLocalizations.tr('emergencyContactsDesc', locale),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (authState.emergencyContacts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.contact_phone_outlined, size: 32, color: AppColors.textMuted),
                          SizedBox(height: 8),
                          Text(
                            'No emergency contacts added yet',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap the + icon above to add family or doctor contacts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                  ...authState.emergencyContacts.map((contact) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: AppColors.primaryRed, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${contact.name} (${contact.relationship})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(contact.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () => ref.read(authProvider.notifier).removeEmergencyContact(contact.id),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button - Navigates unconditionally to LoginScreen
            OutlinedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(AppLocalizations.tr('logOut', locale)),
                    content: Text(AppLocalizations.tr('confirmLogout', locale)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(AppLocalizations.tr('cancel', locale)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                        child: Text(AppLocalizations.tr('logOut', locale), style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primaryRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                AppLocalizations.tr('logOut', locale),
                style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageOption({required String title, required String code, required bool isSelected}) {
    return GestureDetector(
      onTap: () => ref.read(authProvider.notifier).setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, UserModel? user, String locale) {
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final notesCtrl = TextEditingController(text: user?.emergencyNotes ?? '');
    String selectedBlood = user?.bloodGroup ?? 'O+';

    final bloodOptions = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.primaryRed, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.tr('editProfile', locale),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr('fullName', locale),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryRed),
                  ),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr('phoneNumber', locale),
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryRed),
                  ),
                ),
                const SizedBox(height: 12),

                // Email
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr('emailAddress', locale),
                    prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.primaryRed),
                  ),
                ),
                const SizedBox(height: 12),

                // Blood Group Dropdown
                DropdownButtonFormField<String>(
                  initialValue: bloodOptions.contains(selectedBlood) ? selectedBlood : 'O+',
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr('bloodGroup', locale),
                    prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.primaryRed),
                  ),
                  items: bloodOptions.map((bg) {
                    return DropdownMenuItem(value: bg, child: Text(bg));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => selectedBlood = val);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Medical Notes / Allergies
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr('medicalNotes', locale),
                    hintText: AppLocalizations.tr('medicalNotesHint', locale),
                    prefixIcon: const Icon(Icons.medical_information_outlined, color: AppColors.primaryRed),
                  ),
                ),
                const SizedBox(height: 20),

                // Save Button
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) return;

                      await ref.read(authProvider.notifier).updateProfile(
                            name: name,
                            phone: phone,
                            email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                            bloodGroup: selectedBlood,
                            emergencyNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.tr('profileUpdated', locale)),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      AppLocalizations.tr('saveProfile', locale),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, String locale) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.tr('addContact', locale)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
            const SizedBox(height: 10),
            TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship', hintText: 'e.g. Spouse, Parent, Doctor')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.tr('cancel', locale))),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                ref.read(authProvider.notifier).addEmergencyContact(
                      EmergencyContactModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        relationship: relCtrl.text.trim(),
                      ),
                    );
                Navigator.of(ctx).pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            child: Text(AppLocalizations.tr('save', locale), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
