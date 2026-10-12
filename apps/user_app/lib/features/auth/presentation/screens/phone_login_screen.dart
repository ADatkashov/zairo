import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../auth_navigation.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_step_header.dart';
import 'otp_screen.dart';
import 'phone_otp_password_screen.dart';
import 'phone_password_screen.dart';

/// Screen 1 of the phone flow (task spec §11): "+7 ___ ___ __ __" ->
/// Continue -> requests an OTP -> pushes [OtpScreen] for screen 2. [linking]
/// distinguishes "sign in/register with a phone" (root LoginScreen) from
/// "add phone to my existing account" (Settings > Security) — both share
/// this exact same UI, only what happens after a successful verification
/// differs (see OtpScreen).
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key, this.linking = false});

  final bool linking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: FactoryAppBar(title: l10n.phoneLoginTitle),
      body: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        child: ListView(
          children: [
            const AuthStepHeader(step: 1),
            PhoneLoginForm(linking: linking),
          ],
        ),
      ),
    );
  }
}

/// The phone-number form itself (instructions, field, Continue). Shared by
/// [PhoneLoginScreen] and the root LoginScreen, where it is the default
/// sign-in method. A [Column], not a ListView, so it can sit inside either.
class PhoneLoginForm extends ConsumerStatefulWidget {
  const PhoneLoginForm({super.key, this.linking = false});

  final bool linking;

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
            inputFormatters: const [KzPhoneInputFormatter()],
            validator: (value) => isCompleteKzPhone(value) ? null : l10n.validationPhoneRequired,
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
      if (widget.linking) {
        // Adding a phone to the signed-in account: always SMS-verified.
        await controller.requestPhoneOtp(phone);
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        await pushAuthScreen(context, OtpScreen(phone: phone, linking: true));
        return;
      }
      // Sign-in: an existing account with a password just asks for it (no
      // SMS). SMS is only for first registration, or for an account that
      // has no password yet.
      final status = await controller.phoneStatus(phone);
      if (!mounted) return;
      if (status.registered && status.hasPassword) {
        setState(() => _isSubmitting = false);
        await pushAuthScreen(context, PhonePasswordScreen(phone: phone));
        return;
      }
      await controller.requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await pushAuthScreen(context, PhoneOtpPasswordScreen(phone: phone, isNewAccount: !status.registered));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.localizedMessage(l10n);
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.errorAuthGeneric;
        _isSubmitting = false;
      });
    }
  }
}
