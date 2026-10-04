import 'package:flutter/material.dart';

/// Route name shared by every screen of the sign-in / registration chain
/// (Login → Register / Forgot password / Phone → OTP → Password).
const authFlowRouteName = 'auth-flow';

/// Pushes [screen] as a step of the auth chain. Always use this instead of a
/// bare `MaterialPageRoute` for auth screens, so [popAuthFlow] can find where
/// the chain starts.
Future<T?> pushAuthScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      settings: const RouteSettings(name: authFlowRouteName),
      builder: (_) => screen,
    ),
  );
}

/// Closes the whole auth chain after a successful sign-in and lands on the
/// screen that opened it (a provider card, Favorites, Profile, …) — not the
/// root of the current tab, which is what `popUntil((r) => r.isFirst)` did and
/// which dropped a guest's half-made booking on the floor.
///
/// The current screen is always popped, whether or not it was opened through
/// [pushAuthScreen]; earlier steps are popped only while they are auth steps.
/// A no-op when [context]'s screen is no longer the top route — e.g. Login's
/// own "signed in" listener firing after Register already closed the chain —
/// so a second call can never pop the screen the chain returned to.
void popAuthFlow(BuildContext context) {
  final navigator = Navigator.of(context);
  if (ModalRoute.of(context)?.isCurrent != true || !navigator.canPop()) return;
  navigator.pop();
  navigator.popUntil(
    (route) => route.isFirst || route.settings.name != authFlowRouteName,
  );
}
