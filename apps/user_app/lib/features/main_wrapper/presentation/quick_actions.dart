import 'package:core_ui/core_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/router/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../booking/data/models/book_again_suggestion.dart';
import '../../booking/presentation/providers/booking_providers.dart';
import '../../discovery/presentation/providers/discovery_providers.dart';

/// The customer's most recent completed visit, to repeat; null for a guest or without history. Best-effort: a
/// failure is the same as "none".
BookAgainSuggestion? lastVisitOf(WidgetRef ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return null;
  final suggestions = ref.watch(bookAgainSuggestionsProvider(user.id)).value ?? const <BookAgainSuggestion>[];
  return suggestions.isEmpty ? null : suggestions.first;
}

/// What the round "+" fans out: exactly three things that reach a booking faster than the tabs do, left to right
/// with the main one on top in the middle. Never more than three (a fan of four would overlap its own labels).
///
/// - **Find a service** (top): Search with the keyboard up.
/// - **Free today**: Search narrowed to businesses with a free slot today.
/// - **Book again**, when there is a past visit: straight to the booking steps of that service, only a time left to
///   pick. Without history, **Near me** (Search, nearest first) takes its place.
List<FactoryNavQuickAction> quickActionsFor(BuildContext context, AppLocalizations l10n, BookAgainSuggestion? lastVisit) {
  return [
    FactoryNavQuickAction(
      icon: Symbols.event_available_rounded,
      label: l10n.quickTodayTitle,
      onTap: () => context.go(AppRoutes.search(availableOnly: true)),
    ),
    FactoryNavQuickAction(
      icon: Symbols.search_rounded,
      label: l10n.navFindService,
      onTap: () => context.go(AppRoutes.search(focus: true)),
    ),
    if (lastVisit != null)
      FactoryNavQuickAction(
        icon: Symbols.history_rounded,
        label: l10n.homeBookAgainTitle,
        onTap: () => context.push(
          AppRoutes.provider(lastVisit.providerId, book: true, serviceId: lastVisit.serviceId),
          extra: lastVisit.toProviderSearchResult(),
        ),
      )
    else
      FactoryNavQuickAction(
        icon: Symbols.near_me_rounded,
        label: l10n.quickNearbyTitle,
        onTap: () => context.go(AppRoutes.search(sort: DiscoverySort.distance)),
      ),
  ];
}
