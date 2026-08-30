import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/platform_admin_providers.dart';
import 'platform_admin_taxonomy_screen.dart';

/// Reached from LoginScreen's "Platform Admin" text button — a separate
/// login for platform staff (see PlatformAdminApi's own doc comment), not
/// wired into AuthGate at all. On success this pushes straight to the
/// taxonomy screen rather than swapping any app-level root, since platform
/// staff aren't a first-class role in this app's normal owner/moderator
/// flow.
class PlatformAdminLoginScreen extends ConsumerStatefulWidget {
  const PlatformAdminLoginScreen({super.key});

  @override
  ConsumerState<PlatformAdminLoginScreen> createState() => _PlatformAdminLoginScreenState();
}

class _PlatformAdminLoginScreenState extends ConsumerState<PlatformAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionState = ref.watch(platformAdminControllerProvider);
    final isLoading = sessionState.isLoading;

    ref.listen(platformAdminControllerProvider, (previous, next) {
      final session = next.valueOrNull;
      if (session != null && (previous?.valueOrNull == null)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlatformAdminTaxonomyScreen()),
        );
      }
    });

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.platformAdminLoginTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Center(child: FactoryLogomark(size: 56)),
              const SizedBox(height: FactorySpacing.space6),
              FactoryTextField(
                controller: _emailController,
                label: l10n.emailLabel,
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    (value == null || !value.contains('@')) ? l10n.validationEmailInvalid : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                obscureText: true,
                validator: (value) =>
                    (value == null || value.isEmpty) ? l10n.validationPasswordRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space5),
              if (sessionState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(
                    l10n.errorAuthGeneric(sessionState.error.toString()),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FactoryButton(
                label: l10n.loginSubmit,
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(platformAdminControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}
