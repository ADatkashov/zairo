import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/router/tab_reselect.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../messaging/presentation/providers/message_seen_provider.dart';

class MainWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainWrapper({super.key, required this.navigationShell});

  @override
  ConsumerState<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends ConsumerState<MainWrapper> {
  /// The "+" fan is open. The bar closes it on Back by itself, so this
  /// wrapper must not also jump to Home for that same Back press.
  bool _fanOpen = false;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final newMessages = ref.watch(newMessagesCountProvider);

    // Android back from the root of Bookings/Search/Profile goes to Home
    // first and only exits the app from Home. Pushed screens inside a tab
    // are unaffected: the tab's own navigator pops them before this scope
    // is ever asked.
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_fanOpen) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: FactoryBottomNavigation(
          onFanOpenChanged: (open) => _fanOpen = open,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            // Tapping the tab you are on: back to its root *and* to the top.
            if (index == navigationShell.currentIndex) {
              ref.read(tabReselectProvider.notifier).reselect(index);
            }
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          // "+" fans out shortcuts that otherwise take two or three taps:
          // start a booking (pick a category, land in Search filtered to it),
          // messages and favorites (both live under Profile). An action, not
          // a tab, so the tab indexes below are unchanged.
          centerAction: FactoryNavAction(
            icon: Symbols.add_rounded,
            label: l10n.navNewBooking,
            quickActions: [
              FactoryNavQuickAction(
                icon: Symbols.event_available_rounded,
                label: l10n.navNewBooking,
                onTap: () async {
                  final code = await context.push<String>(AppRoutes.categories);
                  if (code != null && context.mounted) {
                    context.go(AppRoutes.search(category: code));
                  }
                },
              ),
              FactoryNavQuickAction(
                icon: Symbols.chat_bubble_rounded,
                label: l10n.messagesTitle,
                onTap: () => context.push(AppRoutes.messages),
              ),
              FactoryNavQuickAction(
                icon: Symbols.favorite_rounded,
                label: l10n.myFavoritesTitle,
                onTap: () => context.push(AppRoutes.favorites),
              ),
            ],
          ),
          // Icon names match BottomNav.dc.html's own `icon` field verbatim
          // (home/search/calendar_month/person) — "Записи" uses
          // calendar_month in the design board, not event_note.
          destinations: [
            FactoryNavDestination(
              icon: Symbols.home_rounded,
              label: l10n.navHome,
            ),
            FactoryNavDestination(
              icon: Symbols.search_rounded,
              label: l10n.navSearch,
            ),
            FactoryNavDestination(
              icon: Symbols.calendar_month_rounded,
              label: l10n.navBookings,
            ),
            FactoryNavDestination(
              icon: Symbols.person_rounded,
              label: l10n.navProfile,
              // Messages live under Profile; new ones show on the tab.
              badgeCount: newMessages,
            ),
          ],
        ),
      ),
    );
  }
}
