import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../platform_admin_labels.dart';
import '../providers/platform_admin_providers.dart';
import '../widgets/platform_admin_common.dart';
import '../widgets/platform_change_avatar_dialog.dart';
import 'platform_admin_activity_tab.dart';
import 'platform_admin_businesses_tab.dart';
import 'platform_admin_catalog_tab.dart';
import 'platform_admin_staff_tab.dart';

enum _ProfileAction { changePhoto, signOut }

/// The platform staff console: businesses to moderate, the master catalog
/// (categories -> services), the activity log and — for PLATFORM_ADMIN only —
/// the staff directory. An internal ops tool, but one a new colleague should
/// be able to use without a manual: everything is in the app's language and
/// described in words rather than codes.
class PlatformAdminConsoleScreen extends ConsumerWidget {
  const PlatformAdminConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(platformAdminControllerProvider).value;
    if (session == null) {
      // Signed out mid-session (e.g. in a second browser tab) — nothing
      // useful to show.
      return const SizedBox.shrink();
    }

    final pending =
        ref.watch(platformBusinessesProvider(session.accessToken)).value?.where((b) => b.status == 'PENDING').length ??
        0;

    final tabs = [
      Tab(
        iconMargin: EdgeInsets.zero,
        text: l10n.paTabBusinesses,
        icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.storefront_outlined)),
      ),
      Tab(icon: const Icon(Icons.category_outlined), text: l10n.paTabCatalog, iconMargin: EdgeInsets.zero),
      Tab(icon: const Icon(Icons.history_rounded), text: l10n.paTabActivity, iconMargin: EdgeInsets.zero),
      if (session.isPlatformAdmin)
        Tab(icon: const Icon(Icons.groups_outlined), text: l10n.paTabStaff, iconMargin: EdgeInsets.zero),
    ];
    final tabViews = [
      PlatformAdminBusinessesTab(session: session),
      PlatformAdminCatalogTab(platformToken: session.accessToken),
      PlatformAdminActivityTab(platformToken: session.accessToken),
      if (session.isPlatformAdmin) PlatformAdminStaffTab(session: session),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.paConsoleTitle),
          actions: [
            PopupMenuButton<_ProfileAction>(
              tooltip: session.displayName,
              offset: const Offset(0, 48),
              onSelected: (action) => _onAction(context, ref, action, hasAvatar: session.avatarUrl != null),
              itemBuilder: (context) => [
                PopupMenuItem<_ProfileAction>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName, style: Theme.of(context).textTheme.titleSmall),
                      Text(session.email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: FactorySpacing.space1),
                      FactoryBadge(label: platformRoleLabel(l10n, session.role)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _ProfileAction.changePhoto,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(l10n.paMenuChangePhoto),
                  ),
                ),
                PopupMenuItem(
                  value: _ProfileAction.signOut,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.logOutTooltip),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3),
                child: FactoryAvatar(
                  initials: initialsFor(session.displayName),
                  size: 34,
                  image: session.avatarUrl != null ? NetworkImage(session.avatarUrl!) : null,
                ),
              ),
            ),
          ],
          // Four short, icon-over-text tabs that all fit a phone's width.
          bottom: TabBar(
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: Theme.of(context).textTheme.labelMedium,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _ProfileAction action, {required bool hasAvatar}) async {
    switch (action) {
      case _ProfileAction.changePhoto:
        await showPlatformChangeAvatarDialog(context, hasCurrentAvatar: hasAvatar);
      case _ProfileAction.signOut:
        final l10n = AppLocalizations.of(context)!;
        final confirmed = await confirmPlatformAction(
          context,
          title: l10n.paSignOutTitle,
          message: l10n.paSignOutMessage,
          confirmLabel: l10n.logOutTooltip,
        );
        if (!confirmed || !context.mounted) return;
        ref.read(platformAdminControllerProvider.notifier).logout();
        // The console is hosted inside the staff login route (see
        // PlatformAdminLoginScreen), so this returns to the owner login.
        Navigator.of(context).pop();
    }
  }
}
