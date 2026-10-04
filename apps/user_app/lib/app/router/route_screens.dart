import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/widgets/logged_out_gate.dart';
import '../../features/auto/presentation/screens/vehicles_screen.dart';
import '../../features/booking/presentation/screens/provider_detail_screen.dart';
import '../../features/discovery/presentation/providers/discovery_providers.dart';
import '../../l10n/app_localizations.dart';

/// Target of `/provider/:id` when the route was opened without the provider
/// object in `extra` — a deep link, a refreshed browser tab, a shared URL.
/// Looks the provider up in the same "everything" search Home already runs
/// (there is no single-provider search endpoint yet), so it is usually served
/// from cache.
class ProviderDetailRoute extends ConsumerWidget {
  const ProviderDetailRoute({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    const query = DiscoveryQuery();
    final resultsAsync = ref.watch(searchResultsProvider(query));

    return resultsAsync.when(
      data: (results) {
        for (final result in results) {
          if (result.id == providerId) {
            return ProviderDetailScreen(provider: result);
          }
        }
        return _RouteMessage(
          child: FactoryEmptyState(
            icon: Symbols.storefront_rounded,
            title: l10n.providerNotFoundTitle,
            message: l10n.providerNotFoundMessage,
          ),
        );
      },
      loading: () => const _RouteMessage(child: FactoryLoadingState()),
      error: (error, stackTrace) => _RouteMessage(
        child: FactoryErrorState(
          message: l10n.errorHomeFeedLoadFailed,
          onRetry: () => ref.invalidate(searchResultsProvider(query)),
        ),
      ),
    );
  }
}

/// Target of `/vehicles`: [VehiclesScreen] needs the signed-in user's id, which
/// a URL can't carry, so it is resolved here.
class VehiclesRoute extends ConsumerWidget {
  const VehiclesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) => user == null
          ? _RouteMessage(
              title: l10n.vehiclesScreenTitle,
              child: LoggedOutGate(
                icon: Symbols.directions_car_rounded,
                message: l10n.profileLoggedOutPrompt,
              ),
            )
          : VehiclesScreen(userId: user.id),
      loading: () => const _RouteMessage(child: FactoryLoadingState()),
      error: (error, stackTrace) => _RouteMessage(
        child: FactoryErrorState(
          message: l10n.errorProfileGeneric(error.toString()),
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      ),
    );
  }
}

/// A bare screen with a back button around a loading / empty / error state.
class _RouteMessage extends StatelessWidget {
  const _RouteMessage({required this.child, this.title = ''});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.factoryColors.bg,
      appBar: FactoryAppBar(title: title.isEmpty ? null : title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: child,
        ),
      ),
    );
  }
}
