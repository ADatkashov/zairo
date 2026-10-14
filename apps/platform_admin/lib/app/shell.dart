import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/labels.dart';
import '../core/widgets/common.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/dashboard/data/dashboard_api.dart';
import '../l10n/app_localizations.dart';
import '../features/businesses/presentation/businesses_screen.dart';
import 'command_palette.dart';
import 'nav.dart';
import 'routes.dart';

/// Sign-out with a confirmation — shared by the sidebar menu, the More screen
/// and Settings so a mis-tap never ends the session silently.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await confirmAction(
    context,
    title: l10n.signOutTitle,
    message: l10n.signOutMessage,
    confirmLabel: l10n.signOut,
  );
  if (!confirmed) return;
  await ref.read(sessionControllerProvider.notifier).logout();
  // The router redirects to the login screen as soon as the session is gone.
}

/// The signed-in frame, picked by width: a sidebar on desktop, an icon rail
/// on tablet and a bottom bar on a phone. The areas themselves are the
/// router's branches (see `buildRouter`).
class ConsoleShell extends ConsumerWidget {
  const ConsoleShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// What needs a person's attention, shown as a count on the sidebar item.
  Map<int, int> _badges(WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider).value;
    if (metrics == null) return const {};
    return {
      consoleBranchPaths.indexOf(ConsoleRoutes.businesses): metrics.businessesPending,
      consoleBranchPaths.indexOf(ConsoleRoutes.finance): metrics.paymentsRefundFailed,
    };
  }

  void _goBranch(int branch) =>
      navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final permissions = ref.watch(permissionsProvider);
    final badges = _badges(ref);

    final frame = switch (FactoryBreakpoints.of(context)) {
      FactoryScreenSize.mobile => _phone(context, l10n, badges),
      FactoryScreenSize.tablet => _sidebar(context, ref, l10n, permissions.canManageStaff, badges, compact: true),
      FactoryScreenSize.desktop => _sidebar(context, ref, l10n, permissions.canManageStaff, badges, compact: false),
    };

    // Ctrl/Cmd+K opens quick search from anywhere in the console. The Focus
    // gives the shortcut a place to live before anything else is focused.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _openPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _openPalette(context),
      },
      child: Focus(autofocus: true, child: frame),
    );
  }

  Future<void> _openPalette(BuildContext context) async {
    final router = GoRouter.of(context);
    final choice = await showCommandPalette(context);
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case PagePick(:final path):
        router.go(path);
      case BusinessPick(:final id):
        router.go(ConsoleRoutes.businesses);
        showBusinessDetails(context, id);
    }
  }

  Widget _sidebar(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool showStaff,
    Map<int, int> badges, {
    required bool compact,
  }) {
    final items = [
      for (final path in consoleBranchPaths)
        if (path != ConsoleRoutes.more && (path != ConsoleRoutes.staff || showStaff)) navItemFor(l10n, path),
    ];
    // "More" is phone-only; if the window grew while it was open, show the
    // dashboard instead of an area the sidebar doesn't list.
    final current = navigationShell.currentIndex;
    final selected = items.indexWhere((item) => item.branch == current);
    if (selected == -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) navigationShell.goBranch(0);
      });
    }

    return Scaffold(
      body: Row(
        children: [
          ConsoleSidebar(
            items: items,
            selected: selected,
            badges: badges,
            compact: compact,
            onSearch: () => _openPalette(context),
            onSelect: (index) => _goBranch(items[index].branch),
          ),
          VerticalDivider(width: 1, color: context.factoryColors.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _phone(BuildContext context, AppLocalizations l10n, Map<int, int> badges) {
    final current = navigationShell.currentIndex;
    // Cities / Ads / Activity / Staff / Settings are reached through "More", so
    // while one of them is open the More tab stays highlighted.
    final selectedTab = phoneTabBranches.contains(current)
        ? phoneTabBranches.indexOf(current)
        : phoneTabBranches.length - 1;

    // Back returns one level: an area opened from "More" goes back to "More",
    // any other area goes back to the dashboard, and only from the dashboard
    // does it leave the app.
    return FactoryFanBackScope(
      canPop: current == 0,
      onBack: () =>
          navigationShell.goBranch(moreBranches.contains(current) ? consoleBranchPaths.indexOf(ConsoleRoutes.more) : 0),
      builder: (context, setFanOpen) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: FactoryBottomNavigation(
          selectedIndex: selectedTab,
          onFanOpenChanged: setFanOpen,
          onDestinationSelected: (tab) => _goBranch(phoneTabBranches[tab]),
          // "+": shortcuts to the areas that no longer have a tab of their
          // own (they are also listed under "More").
          centerAction: FactoryNavAction(
            icon: Icons.add_rounded,
            label: l10n.navQuickActions,
            quickActions: [
              for (final path in [ConsoleRoutes.catalog, ConsoleRoutes.cities, ConsoleRoutes.activity])
                FactoryNavQuickAction(
                  icon: navItemFor(l10n, path).selectedIcon,
                  label: navItemFor(l10n, path).label,
                  onTap: () => _goBranch(consoleBranchPaths.indexOf(path)),
                ),
            ],
          ),
          destinations: [
            for (final branch in phoneTabBranches)
              FactoryNavDestination(
                icon: navItemFor(l10n, consoleBranchPaths[branch]).selectedIcon,
                label: navItemFor(l10n, consoleBranchPaths[branch]).label,
                badgeCount: badges[branch] ?? 0,
              ),
          ],
        ),
      ),
    );
  }
}

/// The branded sidebar (a 72px icon-only rail when [compact], used at tablet
/// width): wordmark, the destinations with a rounded active pill, and the
/// signed-in person with a menu.
class ConsoleSidebar extends ConsumerWidget {
  const ConsoleSidebar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.badges = const {},
    this.compact = false,
    this.onSearch,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final Map<int, int> badges;
  final bool compact;

  /// Opens quick search; null hides the entry.
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider).value;

    return Container(
      width: compact ? 72 : 232,
      color: colors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? FactorySpacing.space2 : FactorySpacing.space3,
        vertical: FactorySpacing.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, FactorySpacing.space5),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const FactoryLogomark(size: 26),
                if (!compact) ...[
                  const SizedBox(width: FactorySpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZAIRO',
                          style: textTheme.headlineSmall?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        Text(l10n.sidebarTagline, style: textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSearch != null)
            Padding(
              padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
              child: compact
                  ? IconButton(tooltip: l10n.cmdOpenTooltip, icon: const Icon(Icons.search_rounded), onPressed: onSearch)
                  : Material(
                      color: colors.surfaceAlt,
                      borderRadius: FactoryRadius.mdRadius,
                      child: InkWell(
                        borderRadius: FactoryRadius.mdRadius,
                        onTap: onSearch,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: colors.textTertiary),
                                const SizedBox(width: FactorySpacing.space2),
                                Expanded(
                                  child: Text(
                                    l10n.cmdOpenTooltip,
                                    style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                                  ),
                                ),
                                Text(
                                  'Ctrl K',
                                  style: FactoryTypography.mono(size: 11, weight: FontWeight.w500, color: colors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _SidebarItem(
                    item: items[i],
                    selected: i == selected,
                    compact: compact,
                    badge: badges[items[i].branch] ?? 0,
                    onTap: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
          if (session != null)
            PopupMenuButton<String>(
              tooltip: session.admin.displayName,
              position: PopupMenuPosition.over,
              onSelected: (value) {
                if (value == 'settings') {
                  context.go(ConsoleRoutes.settings);
                } else {
                  confirmAndSignOut(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(l10n.navSettings),
                  ),
                ),
                PopupMenuItem(
                  value: 'signout',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.signOut),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: FactorySpacing.space2),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    FactoryAvatar(
                      initials: initialsFor(session.admin.displayName),
                      size: 34,
                      image: session.admin.avatarUrl != null ? NetworkImage(session.admin.avatarUrl!) : null,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: FactorySpacing.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              session.admin.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge,
                            ),
                            Text(
                              roleLabel(l10n, session.admin.role),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.unfold_more_rounded, size: 18, color: colors.textTertiary),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.compact,
    required this.badge,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool compact;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? colors.primary : colors.textSecondary;

    final tile = Material(
      color: selected ? colors.primaryTint : Colors.transparent,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: FactoryRadius.mdRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : FactorySpacing.space3, vertical: 11),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Badge(
                isLabelVisible: badge > 0 && compact,
                label: Text(badge > 9 ? '9+' : '$badge'),
                backgroundColor: colors.error,
                textColor: colors.bg,
                child: Icon(selected ? item.selectedIcon : item.icon, size: 20, color: color),
              ),
              if (!compact) ...[
                const SizedBox(width: FactorySpacing.space3),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
                if (badge > 0) Badge(label: Text(badge > 99 ? '99+' : '$badge'), backgroundColor: colors.error, textColor: colors.bg),
              ],
            ],
          ),
        ),
      ),
    );
    // The rail has no room for labels: they become the tooltip.
    return compact ? Tooltip(message: item.label, child: tile) : tile;
  }
}
