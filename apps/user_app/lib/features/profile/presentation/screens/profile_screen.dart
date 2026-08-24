import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsButtonTooltip,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: authState.when(
          data: (user) => user == null
              ? _LoggedOutView()
              : _LoggedInView(displayName: user.displayName, email: user.email),
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorProfileGeneric(error.toString()),
              onRetry: () => ref.invalidate(authControllerProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person_outline, size: 100),
        const SizedBox(height: 16),
        Text(l10n.profileLoggedOutPrompt, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: Text(l10n.loginTitle),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: Text(l10n.profileCreateAccount),
        ),
      ],
    );
  }
}

class _LoggedInView extends ConsumerWidget {
  final String displayName;
  final String email;

  const _LoggedInView({required this.displayName, required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person, size: 100),
        const SizedBox(height: 16),
        Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
        Text(email, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: Text(l10n.profileLogOut),
        ),
      ],
    );
  }
}
