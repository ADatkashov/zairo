import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import '../widgets/enable_biometric_prompt.dart';
import '../widgets/sms_mock_hint.dart';

/// Screen 2 of the phone flow (task spec §11): "Enter the 6-digit code" +
/// resend countdown. [linking] false = sign in/register (pops to root, same
/// as LoginScreen); true = adding a phone to the already-signed-in caller
/// (pops back to the caller with a snackbar, same shape as any other
/// Settings action).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.linking = false});

  final String phone;
  final bool linking;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
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
    setState(() {
      _isResending = true;
      _error = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(authControllerProvider.notifier).requestPhoneOtp(widget.phone);
      if (!mounted) return;
      _startCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.localizedMessage(l10n));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.errorAuthGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    if (widget.linking) {
      try {
        await ref.read(authControllerProvider.notifier).linkPhone(phone: widget.phone, code: code);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.identityLinkedMessage)));
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
      return;
    }

    await ref.read(authControllerProvider.notifier).verifyPhoneOtp(phone: widget.phone, code: code);
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _isSubmitting = false);
    }
  }
}
