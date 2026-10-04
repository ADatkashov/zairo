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
void popAuthFlow(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) => route.isFirst || route.settings.name != authFlowRouteName,
  );
}
