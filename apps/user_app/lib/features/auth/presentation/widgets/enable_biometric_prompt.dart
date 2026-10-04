import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';

/// "Enable Face ID / Fingerprint?" — shown once, right after a successful
/// interactive login (password, Google, Facebook, or phone OTP; never
/// after a silent session restore), per task spec §12/§14. A no-op if
/// biometrics aren't available on this device (task spec §14's "graceful
/// fallback": never offer a toggle that can't work) or already enabled.
Future<void> maybeOfferEnableBiometric(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;

  final controller = ref.read(authControllerProvider.notifier);
  final available = await controller.isBiometricAvailable();
  if (!available) return;
  if (!context.mounted) return;

  final alreadyEnabled = await controller.isBiometricEnabled();
  if (alreadyEnabled) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  if (!context.mounted) return;

  // showDialog uses the root navigator, but this context sits inside a tab's
  // nested navigator — pop must target the root one or it closes the screen
  // underneath instead of the dialog.
  final accepted = await showFactoryDialog<bool>(
    context: context,
    title: l10n.biometricEnrollTitle,
    message: l10n.biometricEnrollMessage,
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(l10n.biometricEnrollNotNow),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: Text(l10n.biometricEnrollEnable),
      ),
    ],
  );

  if (accepted == true && context.mounted) {
    await controller.enableBiometric();
  }
}
