import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/auth_exception.dart';
import '../providers/auth_providers.dart';
import 'link_phone_otp_screen.dart';

/// Step 1 of adding a phone number to the signed-in account (Settings >
/// Security > Linked accounts): the number, then an SMS code on the next screen.
class LinkPhoneScreen extends ConsumerStatefulWidget {
  const LinkPhoneScreen({super.key});

  @override
  ConsumerState<LinkPhoneScreen> createState() => _LinkPhoneScreenState();
}

class _LinkPhoneScreenState extends ConsumerState<LinkPhoneScreen> {
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
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkPhoneOtpScreen(phone: phone)));
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
