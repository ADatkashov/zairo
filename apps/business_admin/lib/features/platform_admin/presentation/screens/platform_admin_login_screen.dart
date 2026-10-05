import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/platform_admin_providers.dart';
import 'platform_admin_console_screen.dart';

/// Reached from LoginScreen's "Platform Admin" text button — a separate
/// login for platform staff (see PlatformAdminApi's own doc comment), not
/// wired into AuthGate at all. Once a staff session exists this screen shows
/// the console in its place, so going back to this route later (the session
/// lives in memory until it is signed out) lands straight in the console
/// instead of asking for the password again.
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
    if (sessionState.value != null) return const PlatformAdminConsoleScreen();

    final isLoading = sessionState.isLoading;
    return Scaffold(
      appBar: FactoryAppBar(title: l10n.platformAdminLoginTitle),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: ListView(
                  children: [
                    const Center(child: FactoryLogomark(size: 56)),
                    const SizedBox(height: FactorySpacing.space4),
                    Text(
                      l10n.paLoginSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.factoryColors.textSecondary),
                    ),
                    const SizedBox(height: FactorySpacing.space6),
                    FactoryTextField(
                      controller: _emailController,
                      label: l10n.emailLabel,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || !value.contains('@')) ? l10n.validationEmailInvalid : null,
                    ),
                    const SizedBox(height: FactorySpacing.space3),
                    FactoryTextField(
                      controller: _passwordController,
                      label: l10n.passwordLabel,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => isLoading ? null : _submit(),
                      validator: (value) => (value == null || value.isEmpty) ? l10n.validationPasswordRequired : null,
                    ),
                    const SizedBox(height: FactorySpacing.space5),
                    if (sessionState.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                        child: Text(
                          _errorText(l10n, sessionState.error),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    FactoryButton(label: l10n.loginSubmit, isLoading: isLoading, onPressed: isLoading ? null : _submit),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, Object? error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return l10n.paLoginInvalid;
    }
    return l10n.paLoginFailed;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(platformAdminControllerProvider.notifier)
        .login(email: _emailController.text.trim(), password: _passwordController.text);
  }
}
