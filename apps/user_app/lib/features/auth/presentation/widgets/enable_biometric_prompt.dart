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
  // Several screens of one sign-in chain (e.g. Login underneath OTP) all react
  // to the same "signed in" state change. Without this guard each of them
  // opened its own dialog and its own biometric prompt, and the second
  // prompt never resolved — the app looked frozen.
  if (_offerInFlight) return;
  _offerInFlight = true;
  try {
    await _offer(context, ref);
  } finally {
    _offerInFlight = false;
  }
}

bool _offerInFlight = false;

Future<void> _offer(BuildContext context, WidgetRef ref) async {
  // Resolved up front: the sign-in screen that called us may be removed from
  // the tree while the dialog is open, and looking a navigator up through a
  // dead context would throw inside the button handler, leaving the dialog
  // impossible to close.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
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
      TextButton(onPressed: () => rootNavigator.pop(false), child: Text(l10n.biometricEnrollNotNow)),
      FilledButton(onPressed: () => rootNavigator.pop(true), child: Text(l10n.biometricEnrollEnable)),
    ],
  );

  if (accepted == true) {
    await controller.enableBiometric();
  }
}
