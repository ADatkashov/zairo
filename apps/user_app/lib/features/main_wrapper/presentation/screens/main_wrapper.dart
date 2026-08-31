import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

class MainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: FactoryBottomNavigation(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          FactoryNavDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: l10n.navHome),
          FactoryNavDestination(icon: Icons.search_outlined, selectedIcon: Icons.search, label: l10n.navSearch),
          FactoryNavDestination(
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
            label: l10n.navBookings,
          ),
          FactoryNavDestination(icon: Icons.person_outline, selectedIcon: Icons.person, label: l10n.navProfile),
        ],
      ),
    );
  }
}
