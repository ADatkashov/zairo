import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../billing/data/billing_exception.dart';
import '../../data/models/user_lookup.dart';
import '../providers/beauty_admin_providers.dart';

/// Returns true via Navigator.pop when a master was created.
///
/// A master is an existing registered person: the owner looks them up by phone
/// and adds them, and their name and photo come from their profile — nothing
/// about the person is typed in.
class AddMasterDialog extends ConsumerStatefulWidget {
  final String providerId;

  const AddMasterDialog({super.key, required this.providerId});

  @override
  ConsumerState<AddMasterDialog> createState() => _AddMasterDialogState();
}

class _AddMasterDialogState extends ConsumerState<AddMasterDialog> {
  final _phoneController = TextEditingController();
  UserLookup? _found;
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
    final found = _found;
    return FactoryDialog(
      title: l10n.addMasterDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactoryTextField(
            controller: _phoneController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.phone,
            label: l10n.masterPhoneLabel,
            onChanged: (_) {
              if (_found != null || _error != null) {
                setState(() {
                  _found = null;
                  _error = null;
                });
              }
            },
          ),
          const SizedBox(height: FactorySpacing.space2),
          Align(
            alignment: Alignment.centerRight,
            child: FactoryButton(
              label: l10n.findButton,
              variant: FactoryButtonVariant.text,
              onPressed: _isSubmitting ? null : _lookup,
            ),
          ),
          if (found != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: found.avatarUrl == null ? null : NetworkImage(found.avatarUrl!),
                child: found.avatarUrl == null ? Text(found.displayName.isEmpty ? '?' : found.displayName[0].toUpperCase()) : null,
              ),
              title: Text(found.displayName),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(
          label: l10n.addButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting || found == null ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _lookup() async {
    final l10n = AppLocalizations.of(context)!;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = l10n.validationMasterPhoneRequired);
      return;
    }
    setState(() => _error = null);
    try {
      final user = await ref.read(beautyAdminApiProvider).lookupUserByPhone(phone);
      if (!mounted) return;
      setState(() {
        _found = user;
        if (user == null) _error = l10n.masterUserNotFound;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.errorAddMasterFailed(e.toString()));
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final user = _found;
    if (user == null) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(beautyAdminApiProvider).createMasterFromUser(providerId: widget.providerId, userId: user.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is BillingException
            ? e.localizedMessage(l10n)
            : (e is DioException && e.response?.statusCode == 409)
                ? l10n.masterAlreadyAdded
                : l10n.errorAddMasterFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
