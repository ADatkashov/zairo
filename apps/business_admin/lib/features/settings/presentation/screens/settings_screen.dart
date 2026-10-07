import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/locale/locale_controller.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../billing/presentation/screens/billing_screen.dart';
import '../../../staff/presentation/providers/staff_cabinet_link_providers.dart';
import '../../../staff/presentation/staff_cabinet_launcher.dart';
import 'security_settings_screen.dart';

/// Mirrors apps/user_app's identical SettingsScreen — same layout, same
/// providers, same behavior — just wired to this app's own l10n/providers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeControllerProvider).value;
    // Settings is also reachable from the login screen; Security and Subscription only make sense signed in.
    final signedIn = ref.watch(authControllerProvider).value != null;
    // Non-null only for an owner who is also staff somewhere (see StaffCabinetLinkApi).
    final staffPending = signedIn ? ref.watch(staffCabinetLinkProvider).value : null;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.settingsTitle),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          FactorySettingsGroup(
            children: [
              SwitchListTile(
                secondary: const FactoryIconBadge(icon: Icons.dark_mode_outlined),
                title: Text(l10n.darkModeTitle),
                subtitle: Text(
                  l10n.darkModeSubtitle(_themeModeLabel(l10n, themeMode)),
                ),
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref
                      .read(themeModeControllerProvider.notifier)
                      .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              ListTile(
                leading: const FactoryIconBadge(icon: Icons.language),
                title: Text(l10n.languageSectionTitle),
                subtitle: Text(_languageLabel(l10n, locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openLanguagePicker(context, ref, l10n, locale),
              ),
            ],
          ),
          if (signedIn) ...[
            const SizedBox(height: FactorySpacing.space4),
            FactorySettingsGroup(
              children: [
                ListTile(
                  leading: const FactoryIconBadge(icon: Icons.shield_outlined),
                  title: Text(l10n.securityTitle),
                  subtitle: Text(l10n.securitySectionSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SecuritySettingsScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const FactoryIconBadge(icon: Icons.workspace_premium_outlined),
                  title: Text(l10n.billingSettingsRowTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BillingScreen()),
                  ),
                ),
              ],
            ),
            if (staffPending != null) ...[
              const SizedBox(height: FactorySpacing.space4),
              FactorySettingsGroup(
                children: [
                  ListTile(
                    leading: const FactoryIconBadge(icon: Icons.badge_outlined),
                    title: Text(l10n.staffCabinetLinkTitle),
                    subtitle: Text(l10n.staffCabinetLinkSubtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (staffPending > 0) ...[
                          FactoryBadge(label: '$staffPending', variant: FactoryBadgeVariant.limited),
                          const SizedBox(width: FactorySpacing.space2),
                        ],
                        const Icon(Icons.open_in_new),
                      ],
                    ),
                    onTap: () => openStaffCabinet(context),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Locale? current,
  ) async {
    void select(BuildContext dialogContext, Locale? locale) {
      ref.read(localeControllerProvider.notifier).setLocale(locale);
      Navigator.of(dialogContext).pop();
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.languageSectionTitle),
        children: [
          _LanguageOption(
            label: l10n.languageSystemDefault,
            selected: current == null,
            onTap: () => select(dialogContext, null),
          ),
          // Each language names itself in its own script, never translated
          // into whichever language happens to be active right now — the
          // standard convention for a language picker.
          _LanguageOption(
            label: 'English',
            selected: current?.languageCode == 'en',
            onTap: () => select(dialogContext, const Locale('en')),
          ),
          _LanguageOption(
            label: 'Русский',
            selected: current?.languageCode == 'ru',
            onTap: () => select(dialogContext, const Locale('ru')),
          ),
          _LanguageOption(
            label: 'Қазақша',
            selected: current?.languageCode == 'kk',
            onTap: () => select(dialogContext, const Locale('kk')),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check, size: 18),
        ],
      ),
    );
  }
}

String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.themeModeSystem,
  ThemeMode.light => l10n.themeModeLight,
  ThemeMode.dark => l10n.themeModeDark,
};

String _languageLabel(AppLocalizations l10n, Locale? locale) =>
    switch (locale?.languageCode) {
      null => l10n.languageSystemDefault,
      'ru' => 'Русский',
      'kk' => 'Қазақша',
      'en' => 'English',
      final code => code,
    };
