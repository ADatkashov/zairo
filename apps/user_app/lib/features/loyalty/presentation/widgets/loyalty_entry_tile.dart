import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../providers/loyalty_providers.dart';
import '../screens/business_loyalty_screen.dart';

/// Provider detail screen's entry point into that business's own loyalty
/// program -- same login gate pattern as FavoriteButton/the Book button
/// (tapping while logged out opens LoginScreen instead of a dead tap), and
/// once logged in, a live points-balance preview fetched the same way that
/// screen already fetches several other provider-scoped lists (masters,
/// mechanics, staff, vehicles).
class LoyaltyEntryTile extends ConsumerWidget {
  final String providerId;
  final String providerName;

  const LoyaltyEntryTile({super.key, required this.providerId, required this.providerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final currentUser = ref.watch(authControllerProvider).value;

    final Widget subtitle;
    if (currentUser == null) {
      subtitle = Text(
        l10n.loyaltyEntryTileSubtitleLoggedOut,
        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      );
    } else {
      final detailAsync = ref.watch(loyaltyBusinessDetailProvider(providerId));
      final balance = detailAsync.value?.pointsBalance ?? 0;
      subtitle = Text(
        balance > 0 ? l10n.loyaltyEntryTileSubtitleBalance(balance) : l10n.loyaltyEntryTileSubtitleDefault,
        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      );
    }

    return FactorySelectableTile(
      title: l10n.loyaltyEntryTileTitle,
      subtitle: subtitle,
      leading: Icon(Symbols.redeem_rounded, color: colors.textSecondary),
      trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
      onTap: () {
        if (currentUser == null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessLoyaltyScreen(providerId: providerId, providerName: providerName),
          ),
        );
      },
    );
  }
}
