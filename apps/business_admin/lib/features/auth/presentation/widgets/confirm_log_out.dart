import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Asks before signing the owner out — the log-out icon sits right next to
/// Settings in the AppBar, so a mis-tap used to end the session silently.
/// Resolves to true only when the owner confirms.
Future<bool> confirmLogOut(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showFactoryDialog<bool>(
    context: context,
    title: l10n.logOutConfirmTitle,
    message: l10n.logOutConfirmMessage,
    actions: [
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: l10n.logOutStayButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ),
      Builder(
        builder: (dialogContext) => FactoryButton(
          label: l10n.logOutTooltip,
          variant: FactoryButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ),
    ],
  );
  return confirmed == true;
}
