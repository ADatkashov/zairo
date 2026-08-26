import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/moderation/presentation/screens/moderation_screen.dart';
import 'admin_shell.dart';

/// The app's root widget: swaps between LoginScreen and the logged-in view
/// as authControllerProvider resolves. Still no go_router — mobile/tablet
/// flows stay linear (login -> one screen at a time via Navigator.push),
/// unlike the consumer app's tabbed navigation. Desktop width is the one
/// exception: ResponsiveOwnerHome switches an owner to AdminShell's
/// persistent sidebar there (see admin_shell.dart) — that's a widget-level
/// branch on FactoryBreakpoints, not a router, so this file's own shape
/// doesn't change. ADMIN is a separate role from PROVIDER_OWNER (see
/// UserRole on the backend) with no salons of its own to manage — it gets
/// ModerationScreen instead, never the owner home, at any width.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        return user.role == 'ADMIN' ? const ModerationScreen() : const ResponsiveOwnerHome();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
