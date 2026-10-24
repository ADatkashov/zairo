import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../../data/apple_sign_in_service.dart';
import '../../data/google_sign_in_service.dart';
import '../auth_navigation.dart';
import '../providers/auth_providers.dart';
import '../widgets/enable_biometric_prompt.dart';
import '../widgets/social_login_button.dart';
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

  /// Set only while a provider button (Google/Apple) is mid-flow — kept
  /// separate from [authControllerProvider]'s own loading state because
  /// GoogleSignInService/AppleSignInService's native UI runs *before*
  /// authControllerProvider ever enters loading (it only starts once a
  /// credential comes back), so relying on authState.isLoading alone would
  /// leave the button not visibly busy while the native picker is open.
  bool _isProviderSigningIn = false;

  /// Phone is the default sign-in method; the email/password form only
  /// shows after the user picks the email button.
  bool _showEmailForm = false;

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
    final showGoogle = ref.watch(googleSignInEnabledProvider);
    final showApple = ref.watch(appleSignInAvailableProvider).value ?? false;
    final emailEnabled = ref.watch(emailSignInEnabledProvider);
    final showEmailForm = emailEnabled && _showEmailForm;
    // Nothing but the phone form left: no "or" divider, no row of alternative buttons.
    final hasAlternatives = emailEnabled || showGoogle || showApple;

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
              const FactoryAuthBrand(),
              const SizedBox(height: FactorySpacing.space4),
              if (showEmailForm) ...[
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
              ] else
                const PhoneLoginForm(),
              if (hasAlternatives) ...[
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
                const SizedBox(height: FactorySpacing.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showGoogle) ...[
                      SocialLoginButton(
                        tooltip: l10n.loginContinueWithGoogle,
                        caption: 'Google',
                        isLoading: _isProviderSigningIn,
                        onPressed: isLoading ? null : _signInWithGoogle,
                        child: const GoogleLogo(),
                      ),
                      const SizedBox(width: FactorySpacing.space4),
                    ],
                    if (showApple) ...[
                      SocialLoginButton(
                        tooltip: l10n.loginContinueWithApple,
                        caption: 'Apple',
                        onPressed: isLoading ? null : _signInWithApple,
                        child: const AppleLogo(),
                      ),
                      const SizedBox(width: FactorySpacing.space4),
                    ],
                    if (emailEnabled)
                      SocialLoginButton(
                        tooltip: showEmailForm ? l10n.loginContinueWithPhone : l10n.loginContinueWithEmail,
                        caption: showEmailForm ? l10n.loginMethodPhone : l10n.emailLabel,
                        onPressed: isLoading ? null : () => setState(() => _showEmailForm = !_showEmailForm),
                        child: Icon(showEmailForm ? Icons.phone_outlined : Icons.mail_outline, size: 26),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: FactorySpacing.space5),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(
                    _errorText(l10n, authState.error!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (showEmailForm)
                FactoryButton(
                  label: l10n.loginTitle,
                  isLoading: authState.isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
              const SizedBox(height: FactorySpacing.space2),
              // The phone form signs in and registers alike, so the e-mail registration page is only for e-mail builds.
              if (emailEnabled)
                FactoryButton(
                  label: l10n.loginNoAccount,
                  variant: FactoryButtonVariant.text,
                  onPressed: isLoading
                      ? null
                      : () => pushAuthScreen(context, const RegisterScreen()),
                ),
              if (showEmailForm)
                FactoryButton(
                  label: l10n.loginForgotPassword,
                  variant: FactoryButtonVariant.text,
                  onPressed: isLoading
                      ? null
                      : () => pushAuthScreen(context, const ForgotPasswordScreen()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorText(AppLocalizations l10n, Object error) {
    if (error is AuthException) return error.localizedMessage(l10n);
    return l10n.errorAuthGeneric;
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
      await _offerLinkIfRequired('GOOGLE', idToken);
    } finally {
      if (mounted) setState(() => _isProviderSigningIn = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isProviderSigningIn = true);
    try {
      final result = await ref.read(appleSignInServiceProvider).signIn();
      if (result == null) return; // Canceled — nothing to show.
      await ref
          .read(authControllerProvider.notifier)
          .loginWithApple(result.identityToken, displayName: result.displayName);
      await _offerLinkIfRequired('APPLE', result.identityToken);
    } finally {
      if (mounted) setState(() => _isProviderSigningIn = false);
    }
  }

  /// The provider's verified email already belongs to an account that was
  /// registered with a typed-in email + password: ask for that password
  /// before connecting, so nobody can take over an account just by knowing
  /// (or pre-registering) its email.
  Future<void> _offerLinkIfRequired(String provider, String token) async {
    final error = ref.read(authControllerProvider).error;
    if (error is! AuthException || error.key != AuthErrorKey.accountLinkRequired || !mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _LinkAccountDialog(),
    );
    if (password == null || !mounted) return;
    await ref
        .read(authControllerProvider.notifier)
        .linkProviderWithPassword(provider: provider, token: token, password: password);
  }

  Future<void> _finishLogin() async {
    if (mounted) {
      await maybeOfferEnableBiometric(context, ref);
    }
    if (!mounted) return;
    // Add a small delay to ensure dialog is fully processed before navigation
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    popAuthFlow(context);
  }
}

class _LinkAccountDialog extends StatefulWidget {
  const _LinkAccountDialog();

  @override
  State<_LinkAccountDialog> createState() => _LinkAccountDialogState();
}

class _LinkAccountDialogState extends State<_LinkAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.linkAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.linkAccountBody),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(controller: _controller, label: l10n.passwordLabel, obscureText: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.linkAccountCancel)),
        TextButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) Navigator.of(context).pop(_controller.text);
          },
          child: Text(l10n.linkAccountConfirm),
        ),
      ],
    );
  }
}
