import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../../data/facebook_sign_in_service.dart';
import '../../data/google_sign_in_service.dart';
import '../providers/auth_providers.dart';
import '../widgets/enable_biometric_prompt.dart';
import 'forgot_password_screen.dart';
import 'phone_login_screen.dart';
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

  /// Set only while a provider button (Google/Facebook) is mid-flow — kept
  /// separate from [authControllerProvider]'s own loading state because
  /// GoogleSignInService/FacebookSignInService's native UI runs *before*
  /// authControllerProvider ever enters loading (it only starts once a
  /// credential comes back), so relying on authState.isLoading alone would
  /// leave the button not visibly busy while the native picker is open.
  bool _isProviderSigningIn = false;

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
    final isLoading = authState.isLoading || _isProviderSigningIn;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _finishLogin();
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
              FactoryButton(
                label: l10n.loginContinueWithGoogle,
                variant: FactoryButtonVariant.secondary,
                expand: true,
                isLoading: _isProviderSigningIn,
                onPressed: isLoading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: FactorySpacing.space2),
              FactoryButton(
                label: l10n.loginContinueWithFacebook,
                variant: FactoryButtonVariant.secondary,
                expand: true,
                isLoading: _isProviderSigningIn,
                onPressed: isLoading ? null : _signInWithFacebook,
              ),
              const SizedBox(height: FactorySpacing.space2),
              FactoryButton(
                label: l10n.loginContinueWithPhone,
                variant: FactoryButtonVariant.secondary,
                expand: true,
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                        ),
              ),
              const SizedBox(height: FactorySpacing.space5),
              Row(
                children: [
                  Expanded(child: Divider(color: context.factoryColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3),
                    child: Text(l10n.loginOrDivider, style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Expanded(child: Divider(color: context.factoryColors.border)),
                ],
              ),
              const SizedBox(height: FactorySpacing.space5),
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
                isLoading: authState.isLoading,
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isProviderSigningIn = true);
    try {
      final idToken = await ref.read(googleSignInServiceProvider).signIn();
      if (idToken == null) return; // Canceled — nothing to show.
      await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
    } finally {
      if (mounted) setState(() => _isProviderSigningIn = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() => _isProviderSigningIn = true);
    try {
      final accessToken = await ref.read(facebookSignInServiceProvider).signIn();
      if (accessToken == null) return; // Canceled — nothing to show.
      await ref.read(authControllerProvider.notifier).loginWithFacebook(accessToken);
    } finally {
      if (mounted) setState(() => _isProviderSigningIn = false);
    }
  }

  Future<void> _finishLogin() async {
    if (mounted) {
      await maybeOfferEnableBiometric(context, ref);
    }
    if (!mounted) return;
    // Add a small delay to ensure dialog is fully processed before navigation
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
