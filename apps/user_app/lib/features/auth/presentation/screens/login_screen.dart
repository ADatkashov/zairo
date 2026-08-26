import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.loginTitle),
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
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(
                    _errorText(l10n, authState.error!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FactoryButton(
                label: l10n.loginTitle,
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
              const SizedBox(height: FactorySpacing.space2),
              FactoryButton(
                label: l10n.loginNoAccount,
                variant: FactoryButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
              ),
              FactoryButton(
                label: l10n.loginForgotPassword,
                variant: FactoryButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, Object error) {
    if (error is AuthException) return error.localizedMessage(l10n);
    return l10n.errorAuthGeneric(error.toString());
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}
