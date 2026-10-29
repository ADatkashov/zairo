import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../booking/data/models/book_again_suggestion.dart';
import '../../../booking/presentation/providers/booking_providers.dart';
import '../../../discovery/presentation/providers/discovery_providers.dart';

/// What the round "+" opens: the few things people do most, each a single tap to
/// the right place. Not a menu of the app's sections (those are the tabs): every row
/// here gets the person to a booking faster than the tabs can.
Future<void> showQuickActionsSheet(BuildContext context) {
  return showFactoryBottomSheet<void>(
    context: context,
    builder: (_) => const QuickActionsSheet(),
  );
}

class QuickActionsSheet extends ConsumerWidget {
  const QuickActionsSheet({super.key});

  /// The customer's most recent completed visit, to repeat; null for a guest or without history. Best-effort: a
  /// failure is the same as "none", the row just is not shown.
  BookAgainSuggestion? _lastVisit(WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return null;
    final suggestions =
        ref.watch(bookAgainSuggestionsProvider(user.id)).value ??
        const <BookAgainSuggestion>[];
    return suggestions.isEmpty ? null : suggestions.first;
  }

  /// Closes the sheet, then goes: the router is taken first, the sheet's own context is gone afterwards.
  void _go(BuildContext context, void Function(GoRouter router) navigate) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    navigate(router);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastVisit = _lastVisit(ref);
    return Padding(
      // The sheet gives its content the full width; the rows breathe at the sides like the rest of the app.
      padding: const EdgeInsets.fromLTRB(
        FactorySpacing.space4,
        0,
        FactorySpacing.space4,
        FactorySpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.navQuickActions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: FactorySpacing.space3),
          _ActionRow(
            icon: Symbols.search_rounded,
            title: l10n.navFindService,
            subtitle: l10n.quickFindSubtitle,
            onTap: () => _go(
              context,
              (router) => router.go(AppRoutes.search(focus: true)),
            ),
          ),
          if (lastVisit != null)
            _ActionRow(
              icon: Symbols.history_rounded,
              title: l10n.homeBookAgainTitle,
              subtitle: l10n.quickBookAgainSubtitle(
                lastVisit.serviceTitle,
                lastVisit.providerName,
              ),
              // Straight to the booking steps with the same service picked: only a time is left to choose.
              onTap: () => _go(
                context,
                (router) => router.push(
                  AppRoutes.provider(
                    lastVisit.providerId,
                    book: true,
                    serviceId: lastVisit.serviceId,
                  ),
                  extra: lastVisit.toProviderSearchResult(),
                ),
              ),
            ),
          _ActionRow(
            icon: Symbols.event_available_rounded,
            title: l10n.quickTodayTitle,
            subtitle: l10n.quickTodaySubtitle,
            onTap: () => _go(
              context,
              (router) => router.go(AppRoutes.search(availableOnly: true)),
            ),
          ),
          _ActionRow(
            icon: Symbols.near_me_rounded,
            title: l10n.quickNearbyTitle,
            subtitle: l10n.quickNearbySubtitle,
            onTap: () => _go(
              context,
              (router) =>
                  router.go(AppRoutes.search(sort: DiscoverySort.distance)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: FactoryRadius.mdRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space3),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: FactoryRadius.mdRadius,
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(width: FactorySpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(color: colors.text),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
