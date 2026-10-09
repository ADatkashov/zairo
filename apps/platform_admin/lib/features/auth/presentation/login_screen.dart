import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../app/preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../data/session_storage.dart';
import 'session_controller.dart';

/// The only screen a signed-out person can reach. Staff accounts are created
/// by a platform admin (there is no self-registration), so this is just email
/// and password — plus the language, because someone may need to read it
/// before they can sign in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastEmail();
  }

  Future<void> _restoreLastEmail() async {
    String? last;
    try {
      last = await ref.read(sessionStorageProvider).readLastEmail();
    } catch (_) {
      return; // storage unavailable: just start with an empty field
    }
    if (!mounted || last == null || _email.text.isNotEmpty) return;
    _email.text = last;
    // The email is known, so the next thing to type is the password.
    _passwordFocus.requestFocus();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).login(email: _email.text.trim(), password: _password.text);
      // The router takes over as soon as the session exists.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _loginError(l10n, error);
      });
    }
  }

  String _loginError(AppLocalizations l10n, Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return l10n.loginInvalid;
      if (status == 429) return l10n.loginTooMany;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return l10n.errorNetwork;
        default:
          break;
      }
    }
    return l10n.loginFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final expired = ref.watch(sessionExpiredProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(FactorySpacing.space6),
              children: [
                const Align(alignment: Alignment.centerRight, child: _LanguagePicker()),
                const SizedBox(height: FactorySpacing.space6),
                FactoryAuthBrand(title: l10n.appTitle, subtitle: l10n.loginSubtitle),
                const SizedBox(height: FactorySpacing.space6),
                if (expired) ...[
                  _Notice(icon: Icons.timer_off_outlined, message: l10n.loginSessionExpired),
                  const SizedBox(height: FactorySpacing.space4),
                ],
                Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        FactoryTextField(
                          controller: _email,
                          label: l10n.email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isSubmitting,
                          validator: (v) => (v == null || !v.contains('@')) ? l10n.emailInvalid : null,
                        ),
                        const SizedBox(height: FactorySpacing.space3),
                        FactoryTextField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          label: l10n.password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          enabled: !_isSubmitting,
                          onSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty) ? l10n.passwordRequired : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: FactorySpacing.space4),
                  Text(
                    _error!,
                    style: TextStyle(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: FactorySpacing.space5),
                FactoryButton(label: l10n.signIn, isLoading: _isSubmitting, expand: true, onPressed: _submit),
                const SizedBox(height: FactorySpacing.space5),
                Text(
                  l10n.loginNoAccount,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      decoration: BoxDecoration(color: colors.accentTint, borderRadius: FactoryRadius.mdRadius),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.text),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.text)),
          ),
        ],
      ),
    );
  }
}

/// Three language chips; the choice is saved (see LocaleController).
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(localeControllerProvider).value?.languageCode ?? Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: FactorySpacing.space2,
      children: [
        for (final (code, label) in const [('kk', 'Қаз'), ('ru', 'Рус'), ('en', 'Eng')])
          FactoryChip(
            label: label,
            selected: current == code,
            onTap: () => ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
          ),
      ],
    );
  }
}
