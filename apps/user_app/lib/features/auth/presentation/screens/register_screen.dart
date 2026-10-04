import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../auth_navigation.dart';
import '../providers/auth_providers.dart';

/// Always registers as CUSTOMER — provider-owner accounts are a
/// Business Admin app concern (Factory Blueprint §11), not this app.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        popAuthFlow(context);
      }
    });

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.registerTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              FactoryTextField(
                controller: _displayNameController,
                label: l10n.registerNameLabel,
                validator: (value) => (value == null || value.isEmpty) ? l10n.validationNameRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _emailController,
                label: l10n.emailLabel,
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    (value == null || !value.contains('@')) ? l10n.validationEmailInvalid : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _phoneController,
                label: l10n.registerPhoneLabel,
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.isEmpty) ? l10n.validationPhoneRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                obscureText: true,
                validator: (value) =>
                    (value == null || value.length < 8) ? l10n.validationPasswordMinLength : null,
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
                label: l10n.registerTitle,
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
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
    ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
  }
}
