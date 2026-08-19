import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../../booking/presentation/screens/my_bookings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: authState.when(
          data: (user) => user == null
              ? _LoggedOutView()
              : _LoggedInView(userId: user.id, displayName: user.displayName, email: user.email),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Something went wrong: $error'),
          ),
        ),
      ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person_outline, size: 100),
        const SizedBox(height: 16),
        const Text('Log in to book and review providers', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Log in'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final String userId;
  final String displayName;
  final String email;

  const _LoggedInView({required this.userId, required this.displayName, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person, size: 100),
        const SizedBox(height: 16),
        Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
        Text(email, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MyBookingsScreen(userId: userId)),
          ),
          child: const Text('My bookings'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Log out'),
        ),
      ],
    );
  }
}
