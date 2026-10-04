import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import '../widgets/sms_mock_hint.dart';

/// The only phone screens that involve an SMS code:
/// - [isNewAccount] true: first registration (as a business owner) — code, name, password.
/// - [isNewAccount] false: forgotten password (or an account that never had
///   one) — code and a new password; signs in right after.
class PhoneOtpPasswordScreen extends ConsumerStatefulWidget {
  const PhoneOtpPasswordScreen({super.key, required this.phone, required this.isNewAccount});

  final String phone;
  final bool isNewAccount;

  @override
  ConsumerState<PhoneOtpPasswordScreen> createState() => _PhoneOtpPasswordScreenState();
}

class _PhoneOtpPasswordScreenState extends ConsumerState<PhoneOtpPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FactoryAppBar(title: widget.isNewAccount ? l10n.registerTitle : l10n.phoneResetTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(widget.isNewAccount
                  ? l10n.phoneRegisterInstructions(widget.phone)
                  : l10n.phoneResetInstructions(widget.phone)),
              const SizedBox(height: FactorySpacing.space4),
              const SmsMockHint(),
              FactoryTextField(
                controller: _codeController,
                label: l10n.otpCodeLabel,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || value.trim().length != 6) ? l10n.validationOtpCodeRequired : null,
              ),
              if (widget.isNewAccount) ...[
                const SizedBox(height: FactorySpacing.space3),
                FactoryTextField(
                  controller: _nameController,
                  label: l10n.registerNameLabel,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? l10n.validationNameRequired : null,
                ),
              ],
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _passwordController,
                label: widget.isNewAccount ? l10n.passwordLabel : l10n.newPasswordLabel,
                obscureText: true,
                validator: (value) =>
                    (value == null || value.length < 8) ? l10n.validationPasswordMinLength : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryButton(
                label: l10n.otpResendButton,
                variant: FactoryButtonVariant.text,
                isLoading: _isResending,
                onPressed: (_isSubmitting || _isResending) ? null : _resend,
              ),
              const SizedBox(height: FactorySpacing.space3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FactoryButton(
                label: l10n.phoneLoginContinueButton,
                isLoading: _isSubmitting,
                onPressed: (_isSubmitting || _isResending) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _message(AppLocalizations l10n, Object error) =>
      error is AuthException ? error.localizedMessage(l10n) : l10n.errorAuthGeneric(error.toString());

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestPhoneOtp(widget.phone);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(l10n, e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(authControllerProvider.notifier);
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (widget.isNewAccount) {
        await controller.registerWithPhone(
          phone: widget.phone,
          code: code,
          displayName: _nameController.text.trim(),
          password: password,
        );
      } else {
        await controller.resetPasswordWithPhone(phone: widget.phone, code: code, newPassword: password);
        await controller.loginWithPhonePassword(phone: widget.phone, password: password);
      }
      // Signed in: AuthGate now shows the owner home beneath these screens.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(l10n, e);
        _isSubmitting = false;
      });
    }
  }
}
