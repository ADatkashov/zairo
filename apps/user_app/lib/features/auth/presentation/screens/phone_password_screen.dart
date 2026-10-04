import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../auth_navigation.dart';
import '../providers/auth_providers.dart';
import '../widgets/enable_biometric_prompt.dart';
import 'phone_otp_password_screen.dart';

/// Step 2 of phone sign-in for a phone that already has an account: just
/// the password — no SMS. "Forgot password" is the only path that sends one.
class PhonePasswordScreen extends ConsumerStatefulWidget {
  const PhonePasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<PhonePasswordScreen> createState() => _PhonePasswordScreenState();
}

class _PhonePasswordScreenState extends ConsumerState<PhonePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSendingCode = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.phonePasswordTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(l10n.phonePasswordInstructions(widget.phone)),
              const SizedBox(height: FactorySpacing.space4),
              FactoryTextField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                obscureText: true,
                validator: (value) =>
                    (value == null || value.isEmpty) ? l10n.validationPasswordRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space5),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FactoryButton(
                label: l10n.loginTitle,
                isLoading: _isSubmitting,
                onPressed: (_isSubmitting || _isSendingCode) ? null : _submit,
              ),
              const SizedBox(height: FactorySpacing.space2),
              FactoryButton(
                label: l10n.phoneForgotPassword,
                variant: FactoryButtonVariant.text,
                isLoading: _isSendingCode,
                onPressed: (_isSubmitting || _isSendingCode) ? null : _forgotPassword,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .loginWithPhonePassword(phone: widget.phone, password: _passwordController.text);
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      final error = authState.error;
      setState(() {
        _error = error is AuthException ? error.localizedMessage(l10n) : l10n.errorAuthGeneric(error.toString());
        _isSubmitting = false;
      });
      return;
    }
    if (authState.value != null) {
      await maybeOfferEnableBiometric(context, ref);
      if (!mounted) return;
      popAuthFlow(context);
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSendingCode = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestPhoneOtp(widget.phone);
      if (!mounted) return;
      setState(() => _isSendingCode = false);
      await pushAuthScreen(context, PhoneOtpPasswordScreen(phone: widget.phone, isNewAccount: false));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.localizedMessage(l10n);
        _isSendingCode = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorAuthGeneric(e.toString());
        _isSendingCode = false;
      });
    }
  }
}
