import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';

/// The app's root widget: swaps between LoginScreen and DashboardScreen as
/// authControllerProvider resolves. No router/shell — this app's flows are
/// linear (login -> dashboard -> one salon at a time), unlike the consumer
/// app's tabbed navigation, so a router would add structure this app
/// doesn't need.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      data: (user) => user == null ? const LoginScreen() : const DashboardScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
