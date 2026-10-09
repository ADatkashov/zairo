import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/auth_exception.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// The word the user must type -- fixed (not localized) because the backend
/// compares against exactly this.
const deleteAccountConfirmationWord = 'DELETE';

/// Irreversible account deletion: explains what goes and what stays, then asks
/// for the password (if the account has one) and a typed confirmation. The
/// server enforces every rule; this screen only mirrors them so the user gets
/// a clear message instead of a raw error.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _confirmed => _confirmController.text.trim() == deleteAccountConfirmationWord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.deleteAccountTitle),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          Text(l10n.deleteAccountWarning, style: textTheme.titleMedium?.copyWith(color: colors.error)),
          const SizedBox(height: FactorySpacing.space3),
          Text(l10n.deleteAccountWhatIsDeleted, style: textTheme.bodyMedium),
          const SizedBox(height: FactorySpacing.space3),
          Text(
            l10n.deleteAccountWhatStays,
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space5),
          FactoryTextField(
            controller: _passwordController,
            enabled: !_submitting,
            label: l10n.deleteAccountPasswordLabel,
            hint: l10n.deleteAccountPasswordHint,
            obscureText: true,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _confirmController,
            enabled: !_submitting,
            label: l10n.deleteAccountConfirmLabel(deleteAccountConfirmationWord),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space3),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: FactorySpacing.space5),
          FactoryButton(
            label: l10n.deleteAccountButton,
            isLoading: _submitting,
            onPressed: (_submitting || !_confirmed) ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final password = _passwordController.text;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(
            password: password.isEmpty ? null : password,
            confirmation: deleteAccountConfirmationWord,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountDone)));
      // Signed out: leave Settings and every screen above the tabs, back to Home.
      if (router != null) {
        router.go('/');
      } else {
        navigator.popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e) {
          DeleteAccountException(statusCode: 403) => l10n.deleteAccountWrongPassword,
          // 409: the server's own words say exactly what to do first.
          DeleteAccountException(statusCode: 409, :final serverMessage) when serverMessage != null => serverMessage,
          _ => l10n.errorAuthGeneric,
        };
      });
    }
  }
}
