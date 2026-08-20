import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/moderation/presentation/screens/moderation_screen.dart';

/// The app's root widget: swaps between LoginScreen and the logged-in view
/// as authControllerProvider resolves. No router/shell — this app's flows
/// are linear (login -> one screen at a time), unlike the consumer app's
/// tabbed navigation, so a router would add structure this app doesn't
/// need. ADMIN is a separate role from PROVIDER_OWNER (see UserRole on the
/// backend) with no salons of its own to manage — it gets ModerationScreen
/// instead of DashboardScreen, never both.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        return user.role == 'ADMIN' ? const ModerationScreen() : const DashboardScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
