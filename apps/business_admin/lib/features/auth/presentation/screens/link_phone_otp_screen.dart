import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import '../widgets/sms_mock_hint.dart';

/// Step 2 of adding a phone to the signed-in account: the 6-digit SMS code (with
/// a resend countdown). On success it pops back to Settings > Security.
class LinkPhoneOtpScreen extends ConsumerStatefulWidget {
  const LinkPhoneOtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<LinkPhoneOtpScreen> createState() => _LinkPhoneOtpScreenState();
}

class _LinkPhoneOtpScreenState extends ConsumerState<LinkPhoneOtpScreen> {
  static const _resendCooldown = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _error;
  Timer? _timer;
  int _secondsLeft = _resendCooldown.inSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsLeft = _resendCooldown.inSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  String _message(AppLocalizations l10n, Object error) =>
      error is AuthException ? error.localizedMessage(l10n) : l10n.errorAuthGeneric(error.toString());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.otpTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(l10n.otpInstructions(widget.phone)),
              const SizedBox(height: FactorySpacing.space4),
              const SmsMockHint(),
              FactoryTextField(
                controller: _codeController,
                label: l10n.otpCodeLabel,
                keyboardType: TextInputType.number,
                validator: (value) =>
                    (value == null || value.trim().length != 6) ? l10n.validationOtpCodeRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryButton(
                label: _secondsLeft > 0 ? l10n.otpResendCountdown(_secondsLeft) : l10n.otpResendButton,
                variant: FactoryButtonVariant.text,
                isLoading: _isResending,
                onPressed: (_secondsLeft > 0 || _isResending) ? null : _resend,
              ),
              const SizedBox(height: FactorySpacing.space3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FactoryButton(
                label: l10n.otpVerifyButton,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestPhoneOtp(widget.phone);
      if (!mounted) return;
      _startCountdown();
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
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .linkPhone(phone: widget.phone, code: _codeController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.identityLinkedMessage)));
      // Back to Settings > Security: this screen and the phone-entry screen below it.
      Navigator.of(context)
        ..pop()
        ..pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(l10n, e);
        _isSubmitting = false;
      });
    }
  }
}
