import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/common.dart';
import '../features/auth/presentation/session_controller.dart';
import '../l10n/app_localizations.dart';
import 'nav.dart';
import 'routes.dart';
import 'shell.dart';

/// Phone-only: the areas that don't fit the bottom bar, plus sign-out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final permissions = ref.watch(permissionsProvider);
    final paths = [
      ConsoleRoutes.catalog,
      ConsoleRoutes.cities,
      ConsoleRoutes.ads,
      ConsoleRoutes.activity,
      if (permissions.canManageStaff) ConsoleRoutes.staff,
      ConsoleRoutes.settings,
    ];
    return AreaScaffold(
      title: l10n.navMore,
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            for (final path in paths)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                child: FactorySelectableTile(
                  leading: Icon(navItemFor(l10n, path).icon),
                  title: navItemFor(l10n, path).label,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(path),
                ),
              ),
            const SizedBox(height: FactorySpacing.space4),
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
