import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../platform_admin/presentation/screens/platform_admin_login_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/apple_sign_in_service.dart';
import '../../data/auth_exception.dart';
import '../../data/google_sign_in_service.dart';
import '../providers/auth_providers.dart';
import '../widgets/social_login_button.dart';
import 'forgot_password_screen.dart';
import 'phone_login_form.dart';
import 'register_screen.dart';

/// Shown directly by AuthGate when logged out (not pushed on top of
/// anything) — once login succeeds, AuthGate itself swaps to the owner home,
/// so this screen doesn't need to pop anything.
///
/// Same sign-in methods as the consumer app: phone is the default (password
/// for an existing account, SMS only to register / reset), Google, Apple (iOS)
/// and email are round buttons below. New accounts created here are
/// PROVIDER_OWNER (see AuthApi).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Phone is the default; the email/password form shows after the person
  /// picks the email button — or when the last attempt was an email login that
  /// failed (AuthGate then re-creates this screen with that error in the state).
  late bool _showEmailForm;

  /// Set while a Google/Apple button is mid-flow. Those flows run entirely here
  /// (they throw instead of putting the controller into its loading state), so
  /// AuthGate does not swap this screen out from under the account-link dialog.
  bool _isProviderSigningIn = false;
  String? _providerError;

  @override
  void initState() {
    super.initState();
    _showEmailForm = ref.read(authControllerProvider).hasError;
  }

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
    final showApple = ref.watch(appleSignInAvailableProvider).value ?? false;

    return Scaffold(
      appBar: FactoryAppBar(
        title: l10n.loginAppBarTitle,
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
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Center(child: FactoryLogomark(size: 56)),
              const SizedBox(height: FactorySpacing.space6),
              if (_showEmailForm) ...[
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
                  SocialLoginButton(
                    tooltip: l10n.loginContinueWithGoogle,
                    isLoading: _isProviderSigningIn,
                    onPressed: isLoading ? null : _signInWithGoogle,
                    child: const GoogleLogo(),
                  ),
                  if (showApple) ...[
                    const SizedBox(width: FactorySpacing.space4),
                    SocialLoginButton(
                      tooltip: l10n.loginContinueWithApple,
                      onPressed: isLoading ? null : _signInWithApple,
                      child: const AppleLogo(),
                    ),
                  ],
                  const SizedBox(width: FactorySpacing.space4),
                  SocialLoginButton(
                    tooltip: _showEmailForm ? l10n.loginContinueWithPhone : l10n.loginContinueWithEmail,
                    onPressed: isLoading ? null : () => setState(() => _showEmailForm = !_showEmailForm),
                    child: Icon(_showEmailForm ? Icons.phone_outlined : Icons.mail_outline, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.space5),
              if (_providerError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_providerError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(
                    _errorText(l10n, authState.error!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_showEmailForm) ...[
                FactoryButton(
                  label: l10n.loginSubmit,
                  isLoading: authState.isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: FactorySpacing.space2),
              ],
              FactoryButton(
                label: l10n.loginNoAccount,
                variant: FactoryButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        ),
              ),
              if (_showEmailForm)
                FactoryButton(
                  label: l10n.loginForgotPassword,
                  variant: FactoryButtonVariant.text,
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          ),
                ),
              // A separate login for platform staff (see
              // PlatformAdminLoginScreen's own doc comment) — not part of
              // this app's regular owner/moderator auth, so it lives behind
              // a low-visibility text button rather than a prominent one.
              FactoryButton(
                label: l10n.platformAdminEntryButton,
                variant: FactoryButtonVariant.text,
                onPressed: isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlatformAdminLoginScreen()),
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
    await _runProviderSignIn(() async {
      final idToken = await ref.read(googleSignInServiceProvider).signIn();
      if (idToken == null) return null; // Canceled — nothing to show.
      return _ProviderCredential('GOOGLE', idToken, () => ref.read(authControllerProvider.notifier).loginWithGoogle(idToken));
    });
  }

  Future<void> _signInWithApple() async {
    await _runProviderSignIn(() async {
      final result = await ref.read(appleSignInServiceProvider).signIn();
      if (result == null) return null; // Canceled — nothing to show.
      return _ProviderCredential(
        'APPLE',
        result.identityToken,
        () => ref
            .read(authControllerProvider.notifier)
            .loginWithApple(result.identityToken, displayName: result.displayName),
      );
    });
  }

  Future<void> _runProviderSignIn(Future<_ProviderCredential?> Function() obtain) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProviderSigningIn = true;
      _providerError = null;
    });
    try {
      final credential = await obtain();
      if (credential == null) return;
      try {
        await credential.signIn();
      } on AuthException catch (e) {
        if (e.key != AuthErrorKey.accountLinkRequired) rethrow;
        await _confirmLinkWithPassword(credential);
      }
    } catch (e) {
      if (mounted) setState(() => _providerError = _errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _isProviderSigningIn = false);
    }
  }

  /// The provider's verified email already belongs to an account that was
  /// registered with a typed-in email + password: ask for that password before
  /// connecting, so nobody can take over an account just by knowing (or
  /// pre-registering) its email.
  Future<void> _confirmLinkWithPassword(_ProviderCredential credential) async {
    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _LinkAccountDialog(),
    );
    if (password == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .linkProviderWithPassword(provider: credential.provider, token: credential.token, password: password);
  }
}

class _ProviderCredential {
  _ProviderCredential(this.provider, this.token, this.signIn);

  final String provider;
  final String token;
  final Future<void> Function() signIn;
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
