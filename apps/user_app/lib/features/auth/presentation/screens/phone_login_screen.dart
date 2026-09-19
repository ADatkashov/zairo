import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import 'otp_screen.dart';

/// Screen 1 of the phone flow (task spec §11): "+7 ___ ___ __ __" ->
/// Continue -> requests an OTP -> pushes [OtpScreen] for screen 2. [linking]
/// distinguishes "sign in/register with a phone" (root LoginScreen) from
/// "add phone to my existing account" (Settings > Security) — both share
/// this exact same UI, only what happens after a successful verification
/// differs (see OtpScreen).
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key, this.linking = false});

  final bool linking;

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '+7 ');
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.phoneLoginTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(l10n.phoneLoginInstructions),
              const SizedBox(height: FactorySpacing.space4),
              FactoryTextField(
                controller: _phoneController,
                label: l10n.registerPhoneLabel,
                hint: '+7 700 123 45 67',
                keyboardType: TextInputType.phone,
                validator: (value) => (value == null || value.trim().length < 8)
                    ? l10n.validationPhoneRequired
                    : null,
              ),
              const SizedBox(height: FactorySpacing.space5),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FactoryButton(
                label: l10n.phoneLoginContinueButton,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
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
    final phone = _phoneController.text.trim();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone, linking: widget.linking)),
      );
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
