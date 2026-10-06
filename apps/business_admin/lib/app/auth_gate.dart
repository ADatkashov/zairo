import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/widgets/biometric_offer_host.dart';
import '../features/moderation/presentation/screens/moderation_screen.dart';

/// The outermost route's builder (see `buildAdminRouter`): swaps between
/// LoginScreen and the signed-in view as authControllerProvider resolves, while
/// leaving the URL alone — so a deep link opened while signed out is still
/// there once the owner has signed in.
///
/// Logged-out: the login screen replaces whatever [child] would show (the
/// login screen's own sub-screens are pushed on the root navigator above it).
/// ADMIN is a separate role from PROVIDER_OWNER (see UserRole on the backend)
/// with no salons of its own to manage — it gets ModerationScreen instead of
/// the owner area, at any width and for any URL. An owner gets [child]: the
/// owner shell and its areas.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  /// The router's navigator for the matched owner area.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        final home = user.role == 'ADMIN' ? const ModerationScreen() : child;
        return BiometricOfferHost(child: home);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
