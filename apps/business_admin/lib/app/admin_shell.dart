import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../features/billing/presentation/screens/billing_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../l10n/app_localizations.dart';

/// The desktop answer to this app's mobile linear push-navigation
/// (see AuthGate's comment on why there's no router/shell there) — the
/// design system's Responsive Navigation row calls for a sidebar on
/// Business/Platform Admin at desktop width, so this only renders at
/// [FactoryScreenSize.desktop]; below that, [ResponsiveOwnerHome] falls
/// straight through to [DashboardScreen] unchanged, same as before this
/// existed.
///
/// Each destination keeps its own Scaffold/AppBar exactly as it already
/// does when reached by push on mobile — this composes them side-by-side
/// rather than stripping their chrome, so nothing about DashboardScreen,
/// BillingScreen or SettingsScreen had to change to gain a desktop shell.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            backgroundColor: colors.surface,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront_rounded),
                label: Text(l10n.navDashboard),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                label: Text(l10n.billingScreenTitle),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: Text(l10n.settingsButtonTooltip),
              ),
            ],
          ),
          VerticalDivider(width: 1, color: colors.border),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [DashboardScreen(), BillingScreen(), SettingsScreen()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks [AdminShell] at desktop width, [DashboardScreen] below it —
/// the single place that branches on [FactoryBreakpoints], so AuthGate
/// itself stays a plain role switch.
class ResponsiveOwnerHome extends StatelessWidget {
  const ResponsiveOwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return FactoryBreakpoints.of(context) == FactoryScreenSize.desktop
        ? const AdminShell()
        : const DashboardScreen();
  }
}
