import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/messaging/presentation/providers/message_seen_provider.dart';
import '../l10n/app_localizations.dart';
import 'admin_shell.dart';

/// Tracks how many full screens are pushed on top of one branch's root, so the
/// shell can hide its bottom bar on a detail screen (which has its own
/// actions) and show it again on the way back.
///
/// It keeps the actual routes rather than a counter: a counter drifted when a
/// push and a pop landed in the same frame (and counted dialogs, menus and
/// sheets that open on this navigator), leaving the bottom bar hidden on the
/// root screen until the app was restarted.
class BranchDepthObserver extends NavigatorObserver {
  final Set<Route<dynamic>> _pages = {};

  /// 0 while the branch shows its root screen.
  final ValueNotifier<int> depth = ValueNotifier(0);

  // Notifications fire in the middle of a navigator update; defer the rebuild.
  void _publish() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (depth.value != _pages.length) depth.value = _pages.length;
      });

  void _add(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Dialogs, popup menus and bottom sheets are not screens.
    if (previousRoute != null && route is PageRoute) _pages.add(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _add(route, previousRoute);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _pages.remove(oldRoute);
    if (newRoute != null && navigator?.canPop() == true) _pages.add(newRoute);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _publish();
  }
}

/// The signed-in owner's frame, picked by width: a sidebar on desktop, an
/// icon rail on tablet and a bottom bar on a phone. The areas themselves are
/// the router's branches (see `buildAdminRouter`); every area keeps its own
/// Scaffold/AppBar, this only composes them with the navigation.
class OwnerShell extends ConsumerWidget {
  const OwnerShell({super.key, required this.navigationShell, required this.depthObservers});

  final StatefulNavigationShell navigationShell;
  final List<BranchDepthObserver> depthObservers;

  /// Phone tabs → router branches: two, the "+", two. The last tab is "More";
  /// Loyalty is reached through the "+" and "More".
  static const _phoneTabBranches = [0, 1, 2, 7];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ownerUserId = ref.watch(authControllerProvider).value?.id;
    final newMessages = ownerUserId == null ? 0 : ref.watch(newMessagesCountProvider(ownerUserId));

    return switch (FactoryBreakpoints.of(context)) {
      FactoryScreenSize.mobile => _phone(context, l10n, newMessages),
      FactoryScreenSize.tablet => _sidebar(context, l10n, newMessages, compact: true),
      FactoryScreenSize.desktop => _sidebar(context, l10n, newMessages, compact: false),
    };
  }

  void _goBranch(int branch) =>
      navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);

  Widget _sidebar(BuildContext context, AppLocalizations l10n, int newMessages, {required bool compact}) {
    final colors = context.factoryColors;
    // Branch 7 ("More") is phone-only, so the sidebar never selects it.
    final selected = navigationShell.currentIndex.clamp(0, 6);
    final destinations = [
      AdminSidebarDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: l10n.navDashboard),
      AdminSidebarDestination(icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, label: l10n.messagingNavLabel, badgeCount: newMessages),
      AdminSidebarDestination(icon: Icons.campaign_outlined, selectedIcon: Icons.campaign_rounded, label: l10n.campaignCenterNavLabel),
      AdminSidebarDestination(icon: Icons.loyalty_outlined, selectedIcon: Icons.loyalty, label: l10n.loyaltyNavLabel),
      AdminSidebarDestination(icon: Icons.bolt_outlined, selectedIcon: Icons.bolt, label: l10n.automationCenterNavLabel),
      AdminSidebarDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: l10n.billingScreenTitle),
      AdminSidebarDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: l10n.settingsButtonTooltip),
    ];

    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(destinations: destinations, selectedIndex: selected, onSelect: _goBranch, compact: compact),
          VerticalDivider(width: 1, color: colors.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _phone(BuildContext context, AppLocalizations l10n, int newMessages) {
    final current = navigationShell.currentIndex;
    // Loyalty / Automation / Subscription / Settings are reached through "More", so
    // while one of them is open the More tab stays highlighted.
    final selectedTab = _phoneTabBranches.contains(current) ? _phoneTabBranches.indexOf(current) : _phoneTabBranches.length - 1;

    // Back from any other area returns to the Dashboard first; only from the
    // Dashboard does it leave the app.
    return PopScope(
      canPop: current == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: depthObservers[current].depth,
          builder: (context, depth, _) {
            if (depth > 0) return const SizedBox.shrink();
            return FactoryBottomNavigation(
              selectedIndex: selectedTab,
              onDestinationSelected: (tab) => _goBranch(_phoneTabBranches[tab]),
              destinations: [
                FactoryNavDestination(icon: Icons.dashboard_rounded, label: l10n.navDashboard),
                FactoryNavDestination(icon: Icons.forum_rounded, label: l10n.messagingNavLabel, badgeCount: newMessages),
                FactoryNavDestination(icon: Icons.campaign_rounded, label: l10n.campaignCenterNavLabel),
                FactoryNavDestination(icon: Icons.more_horiz_rounded, label: l10n.navMore),
              ],
            );
          },
        ),
      ),
    );
  }
}
