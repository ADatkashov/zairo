import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/locale/locale_controller.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final locale = ref.watch(localeControllerProvider).value;
    final isLoggedIn = ref.watch(authControllerProvider).value != null;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.settingsTitle),
      body: ListView(
        children: [
          SwitchListTile(
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
            title: Text(l10n.languageSectionTitle),
            subtitle: Text(_languageLabel(l10n, locale)),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => _openLanguagePicker(context, ref, l10n, locale),
          ),
          ListTile(
            title: Text(l10n.securityTitle),
            subtitle: Text(l10n.securitySectionSubtitle),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.securitySettings),
          ),
          if (isLoggedIn)
            ListTile(
              title: Text(
                l10n.deleteAccountTitle,
                style: TextStyle(color: context.factoryColors.coral),
              ),
              subtitle: Text(l10n.deleteAccountSubtitle),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.deleteAccount),
            ),
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
          if (selected) const Icon(Symbols.check_rounded, fill: 1, size: 18),
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
