import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/preferences.dart';
import '../../../app/shell.dart';
import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/platform_role.dart';
import '../../auth/data/platform_session.dart';
import '../../auth/presentation/session_controller.dart';

/// The signed-in person's own page: who they are and what their role can do,
/// their photo, the app's language and theme, where the console is pointed,
/// and sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionControllerProvider).value;
    final locale = ref.watch(localeControllerProvider).value;
    final themeMode = ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;

    return AreaScaffold(
      title: l10n.navSettings,
      body: session == null
          ? const SizedBox.shrink()
          : ContentFrame(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  _ProfileCard(session: session),
                  const SizedBox(height: FactorySpacing.space5),
                  FactorySectionHeader(title: l10n.settingsPermissionsTitle),
                  const SizedBox(height: FactorySpacing.space2),
                  _Permissions(permissions: session.permissions),
                  const SizedBox(height: FactorySpacing.space5),
                  FactorySectionHeader(title: l10n.settingsLanguage),
                  const SizedBox(height: FactorySpacing.space2),
                  Wrap(
                    spacing: FactorySpacing.space2,
                    runSpacing: FactorySpacing.space2,
                    children: [
                      FactoryChip(
                        label: l10n.settingsSystem,
                        selected: locale == null,
                        onTap: () => ref.read(localeControllerProvider.notifier).setLocale(null),
                      ),
                      for (final (code, label) in const [('kk', 'Қазақша'), ('ru', 'Русский'), ('en', 'English')])
                        FactoryChip(
                          label: label,
                          selected: locale?.languageCode == code,
                          onTap: () => ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
                        ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space5),
                  FactorySectionHeader(title: l10n.settingsTheme),
                  const SizedBox(height: FactorySpacing.space2),
                  Wrap(
                    spacing: FactorySpacing.space2,
                    runSpacing: FactorySpacing.space2,
                    children: [
                      for (final (mode, label, icon) in [
                        (ThemeMode.system, l10n.settingsSystem, Icons.brightness_auto_outlined),
                        (ThemeMode.light, l10n.settingsLight, Icons.light_mode_outlined),
                        (ThemeMode.dark, l10n.settingsDark, Icons.dark_mode_outlined),
                      ])
                        FactoryChip(
                          label: label,
                          icon: icon,
                          selected: themeMode == mode,
                          onTap: () => ref.read(themeModeControllerProvider.notifier).setThemeMode(mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space5),
                  FactorySectionHeader(title: l10n.settingsAbout),
                  const SizedBox(height: FactorySpacing.space2),
                  FactoryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsServer, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                        SelectableText(ref.watch(networkConfigProvider).baseUrl, style: textTheme.bodyMedium),
                        if (session.expiresAt != null) ...[
                          const SizedBox(height: FactorySpacing.space3),
                          Text(
                            l10n.settingsSessionNote,
                            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: FactorySpacing.space6),
                  FactoryButton(
                    label: l10n.signOut,
                    icon: Icons.logout,
                    variant: FactoryButtonVariant.secondary,
                    expand: true,
                    onPressed: () => confirmAndSignOut(context, ref),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.session});

  final PlatformSession session;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _busy = false;

  Future<void> _changePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(authApiProvider).uploadImage(bytes, picked.name);
      await ref.read(sessionControllerProvider.notifier).updateAvatar(url);
      if (mounted) showSnack(context, l10n.settingsPhotoUpdated);
    } catch (error) {
      if (mounted) showSnack(context, describeError(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).updateAvatar(null);
    } catch (error) {
      if (mounted) showSnack(context, describeError(l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final admin = ref.watch(sessionControllerProvider).value!.admin;
    final textTheme = Theme.of(context).textTheme;
    return FactoryCard(
      child: Row(
        children: [
          FactoryAvatar(
            initials: initialsFor(admin.displayName),
            size: 64,
            image: admin.avatarUrl != null ? NetworkImage(admin.avatarUrl!) : null,
          ),
          const SizedBox(width: FactorySpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin.displayName, style: textTheme.titleMedium),
                Text(admin.email, style: textTheme.bodySmall),
                const SizedBox(height: FactorySpacing.space2),
                ToneBadge(label: roleLabel(l10n, admin.role)),
                const SizedBox(height: FactorySpacing.space2),
                Wrap(
                  spacing: FactorySpacing.space2,
                  children: [
                    FactoryButton(
                      label: l10n.settingsChangePhoto,
                      icon: Icons.photo_camera_outlined,
                      variant: FactoryButtonVariant.secondary,
                      isLoading: _busy,
                      onPressed: _busy ? null : _changePhoto,
                    ),
                    if (admin.avatarUrl != null)
                      FactoryButton(
                        label: l10n.settingsRemovePhoto,
                        variant: FactoryButtonVariant.text,
                        onPressed: _busy ? null : _removePhoto,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A checklist of what the role can and can't do, so nobody has to find out by
/// hitting a missing button.
class _Permissions extends StatelessWidget {
  const _Permissions({required this.permissions});

  final PlatformPermissions permissions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final rows = [
      (l10n.permViewEverything, true),
      (l10n.permModerate, permissions.canModerateBusinesses),
      (l10n.permCatalog, permissions.canEditCatalog),
      (l10n.permCities, permissions.canEditCities),
      (l10n.permPayouts, permissions.canSettlePayouts),
      (l10n.permStaff, permissions.canManageStaff),
    ];
    return FactoryCard(
      child: Column(
        children: [
          for (final (label, allowed) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    allowed ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: allowed ? colors.success : colors.textTertiary,
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: allowed ? colors.text : colors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
