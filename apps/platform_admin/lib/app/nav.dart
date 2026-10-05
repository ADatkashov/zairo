import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'routes.dart';

/// One place in the console's navigation.
class NavItem {
  const NavItem({required this.branch, required this.icon, required this.selectedIcon, required this.label});

  /// Index into the shell's branches (see [consoleBranchPaths]).
  final int branch;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

NavItem navItemFor(AppLocalizations l10n, String path) {
  final branch = consoleBranchPaths.indexOf(path);
  return switch (path) {
    ConsoleRoutes.dashboard => NavItem(
      branch: branch,
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
      label: l10n.navDashboard,
    ),
    ConsoleRoutes.businesses => NavItem(
      branch: branch,
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      label: l10n.navBusinesses,
    ),
    ConsoleRoutes.catalog => NavItem(
      branch: branch,
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      label: l10n.navCatalog,
    ),
    ConsoleRoutes.cities => NavItem(
      branch: branch,
      icon: Icons.location_city_outlined,
      selectedIcon: Icons.location_city_rounded,
      label: l10n.navCities,
    ),
    ConsoleRoutes.finance => NavItem(
      branch: branch,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: l10n.navFinance,
    ),
    ConsoleRoutes.activity => NavItem(
      branch: branch,
      icon: Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      label: l10n.navActivity,
    ),
    ConsoleRoutes.staff => NavItem(
      branch: branch,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: l10n.navStaff,
    ),
    ConsoleRoutes.settings => NavItem(
      branch: branch,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: l10n.navSettings,
    ),
    _ => NavItem(
      branch: branch,
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
      label: l10n.navMore,
    ),
  };
}
