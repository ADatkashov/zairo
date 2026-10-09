import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';

/// The empty state every owner-scoped screen (inbox, campaigns, loyalty,
/// automation) shows before the owner has created a business. Those screens
/// each rendered the same bare grey sentence; this gives them one consistent
/// illustrated state — the shared title plus the screen's own [message].
class NoBusinessState extends StatelessWidget {
  const NoBusinessState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryEmptyState(
      icon: Symbols.storefront_rounded,
      title: l10n.noBusinessesYetTitle,
      message: message,
    );
  }
}
