import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_navigation.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../providers/workers_providers.dart';

/// The heart on a master's page: puts them on (or takes them off) the customer's "My masters" list. A guest is sent to
/// log in instead of the tap silently doing nothing.
class FavoriteWorkerButton extends ConsumerStatefulWidget {
  const FavoriteWorkerButton({super.key, required this.workerId});

  final String workerId;

  @override
  ConsumerState<FavoriteWorkerButton> createState() => _FavoriteWorkerButtonState();
}

class _FavoriteWorkerButtonState extends ConsumerState<FavoriteWorkerButton> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).value;

    if (user == null) {
      return IconButton(
        icon: const Icon(Symbols.favorite_rounded),
        tooltip: l10n.favoriteMasterAddTooltip,
        onPressed: () => pushAuthScreen(context, const LoginScreen()),
      );
    }

    final favorited = ref.watch(isFavoriteWorkerProvider((userId: user.id, workerId: widget.workerId)));
    return favorited.when(
      data: (isFavorite) => IconButton(
        icon: Icon(Symbols.favorite_rounded, fill: isFavorite ? 1 : 0),
        color: isFavorite ? context.factoryColors.error : null,
        tooltip: isFavorite ? l10n.favoriteMasterRemoveTooltip : l10n.favoriteMasterAddTooltip,
        onPressed: _toggling ? null : () => _toggle(user.id, isFavorite),
      ),
      loading: () => IconButton(
        icon: const Icon(Symbols.favorite_rounded),
        tooltip: l10n.favoriteMasterAddTooltip,
        onPressed: null,
      ),
      error: (error, stackTrace) => IconButton(
        icon: const Icon(Symbols.favorite_rounded),
        tooltip: l10n.favoriteMasterAddTooltip,
        onPressed: null,
      ),
    );
  }

  Future<void> _toggle(String userId, bool currentlyFavorite) async {
    setState(() => _toggling = true);
    final api = ref.read(workersApiProvider);
    try {
      if (currentlyFavorite) {
        await api.removeFavoriteWorker(userId, widget.workerId);
      } else {
        await api.addFavoriteWorker(userId, widget.workerId);
      }
      ref.invalidate(isFavoriteWorkerProvider((userId: userId, workerId: widget.workerId)));
      ref.invalidate(myFavoriteWorkersProvider(userId));
    } catch (_) {
      // The heart stays as it was; say so rather than doing nothing.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.favoriteMasterFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }
}
