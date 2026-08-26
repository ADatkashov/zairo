import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/register_screen.dart';
import '../../../auto/presentation/screens/vehicles_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: FactoryAppBar(
        title: l10n.profileTitle,
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
      body: authState.when(
        data: (user) => user == null
            ? const _LoggedOutView()
            : _LoggedInView(userId: user.id, displayName: user.displayName, email: user.email),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
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
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryEmptyState(
              icon: Icons.person_outline,
              title: l10n.profileLoggedOutTitle,
              message: l10n.profileLoggedOutPrompt,
              actionLabel: l10n.loginTitle,
              onAction: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
            FactoryButton(
              label: l10n.profileCreateAccount,
              variant: FactoryButtonVariant.text,
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
          ],
        ),
      ),
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
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        const SizedBox(height: FactorySpacing.space4),
        Center(
          child: FactoryAvatar(initials: initialsFor(displayName), size: FactoryAvatarSize.xl),
        ),
        const SizedBox(height: FactorySpacing.space3),
        Center(child: Text(displayName, style: textTheme.headlineSmall, textAlign: TextAlign.center)),
        const SizedBox(height: FactorySpacing.space1),
        Center(
          child: Text(email, style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary)),
        ),
        const SizedBox(height: FactorySpacing.space8),
        FactorySelectableTile(
          title: l10n.myVehiclesButton,
          leading: Icon(Icons.directions_car_outlined, color: colors.textSecondary),
          trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VehiclesScreen(userId: userId)),
          ),
        ),
        const SizedBox(height: FactorySpacing.space6),
        FactoryButton(
          label: l10n.profileLogOut,
          variant: FactoryButtonVariant.secondary,
          expand: true,
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}
