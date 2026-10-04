import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import 'phone_otp_password_screen.dart';
import 'phone_password_screen.dart';

/// The phone-number form on the login screen, where phone is the default
/// sign-in method: an existing account with a password just asks for it (no
/// SMS); SMS is only for first registration, or for an account that has no
/// password yet.
class PhoneLoginForm extends ConsumerStatefulWidget {
  const PhoneLoginForm({super.key});

  @override
  ConsumerState<PhoneLoginForm> createState() => _PhoneLoginFormState();
}

class _PhoneLoginFormState extends ConsumerState<PhoneLoginForm> {
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.phoneLoginInstructions),
          const SizedBox(height: FactorySpacing.space4),
          FactoryTextField(
            controller: _phoneController,
            label: l10n.registerPhoneLabel,
            hint: '+7 700 123 45 67',
            keyboardType: TextInputType.phone,
            validator: (value) =>
                (value == null || value.trim().length < 8) ? l10n.validationPhoneRequired : null,
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
      final controller = ref.read(authControllerProvider.notifier);
      final status = await controller.phoneStatus(phone);
      if (!mounted) return;
      if (status.registered && status.hasPassword) {
        setState(() => _isSubmitting = false);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PhonePasswordScreen(phone: phone)),
        );
        return;
      }
      await controller.requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhoneOtpPasswordScreen(phone: phone, isNewAccount: !status.registered),
        ),
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
