import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';

/// Two steps on one screen rather than two separate screens/routes: step 1
/// asks for the email and requests a code; step 2 (shown once the request
/// succeeds) asks for that code plus a new password. Kept as one screen
/// since there's nowhere else the "I have a code" step would be reached
/// from — no deep-linking/magic-link handling exists yet (no deployed URL
/// scheme to link into — see MockMapScreen for the same "no real
/// deployment yet" honesty elsewhere in this app), so the code is
/// delivered as a short string the user copies in by hand.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { enterEmail, enterCode }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  _Step _step = _Step.enterEmail;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _step == _Step.enterEmail ? _buildEmailStep(l10n) : _buildResetStep(l10n),
      ),
    );
  }

  Widget _buildEmailStep(AppLocalizations l10n) {
    return Form(
      key: _emailFormKey,
      child: ListView(
        children: [
          Text(l10n.forgotPasswordInstructions),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            validator: (value) => (value == null || !value.contains('@')) ? l10n.validationEmailInvalid : null,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submitEmail,
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.forgotPasswordSendCodeButton),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(AppLocalizations l10n) {
    return Form(
      key: _resetFormKey,
      child: ListView(
        children: [
          Text(l10n.forgotPasswordCodeSentMessage),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(labelText: l10n.resetCodeLabel),
            validator: (value) => (value == null || value.isEmpty) ? l10n.validationResetCodeRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.newPasswordLabel),
            validator: (value) =>
                (value == null || value.length < 8) ? l10n.validationPasswordMinLength : null,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submitReset,
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.forgotPasswordResetButton),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _Step.enterCode;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorAuthGeneric(e.toString());
        _isSubmitting = false;
      });
    }
  }

  Future<void> _submitReset() async {
    if (!_resetFormKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).resetPassword(
            token: _codeController.text.trim(),
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.forgotPasswordSuccessMessage)));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.localizedMessage(l10n);
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorAuthGeneric(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
