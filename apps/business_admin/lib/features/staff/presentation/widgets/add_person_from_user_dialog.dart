import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../billing/data/billing_exception.dart';
import '../../data/models/user_lookup.dart';
import '../../data/user_lookup_api.dart';

/// Shared "add a person" dialog for masters, mechanics, cleaners and generic
/// staff. A person is an existing registered user: the owner looks them up by
/// phone and adds them, and their name and photo come from their profile —
/// nothing about the person is typed in. [onAdd] performs the vertical's own
/// create-from-user call. Returns true via Navigator.pop once added. When nobody
/// is registered with the phone the owner can invite them: they join the
/// business automatically once they sign up with that number.
class AddPersonFromUserDialog extends ConsumerStatefulWidget {
  final String providerId;
  final String title;
  final Future<void> Function(String userId) onAdd;

  const AddPersonFromUserDialog({super.key, required this.providerId, required this.title, required this.onAdd});

  @override
  ConsumerState<AddPersonFromUserDialog> createState() => _AddPersonFromUserDialogState();
}

class _AddPersonFromUserDialogState extends ConsumerState<AddPersonFromUserDialog> {
  final _phoneController = TextEditingController();
  UserLookup? _found;
  bool _notFound = false;
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
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FactoryTextField(
            controller: _phoneController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.phone,
            label: l10n.masterPhoneLabel,
            onChanged: (_) {
              if (_found != null || _notFound || _error != null) {
                setState(() {
                  _found = null;
                  _notFound = false;
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
          if (_notFound) ...[
            Text(l10n.masterUserNotFound),
            const SizedBox(height: FactorySpacing.space2),
            Text(l10n.inviteExplanation, style: Theme.of(context).textTheme.bodySmall),
            Align(
              alignment: Alignment.centerRight,
              child: FactoryButton(
                label: l10n.inviteButton,
                variant: FactoryButtonVariant.secondary,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _invite,
              ),
            ),
          ],
          _PendingInvitations(providerId: widget.providerId),
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
      final user = await ref.read(userLookupApiProvider).lookupByPhone(phone);
      if (!mounted) return;
      setState(() {
        _found = user;
        _notFound = user == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.errorAddMasterFailed(e.toString()));
    }
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final invitation = await ref
          .read(invitationsApiProvider)
          .invite(providerId: widget.providerId, phone: _phoneController.text.trim());
      ref.invalidate(pendingInvitationsProvider(widget.providerId));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.inviteSent(invitation.phone))));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = (e is DioException && e.response?.statusCode == 409)
            ? l10n.inviteAlreadySent
            : l10n.errorAddMasterFailed(e.toString());
        _isSubmitting = false;
      });
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
      await widget.onAdd(user.id);
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

/// Open invitations for this business, each cancellable.
class _PendingInvitations extends ConsumerWidget {
  final String providerId;

  const _PendingInvitations({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invitations = ref.watch(pendingInvitationsProvider(providerId)).valueOrNull ?? const [];
    if (invitations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FactorySpacing.space3),
        Text(l10n.pendingInvitationsTitle, style: Theme.of(context).textTheme.labelLarge),
        for (final invitation in invitations)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(invitation.phone),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancelInvitationTooltip,
              onPressed: () async {
                await ref.read(invitationsApiProvider).cancel(invitation.id);
                ref.invalidate(pendingInvitationsProvider(providerId));
              },
            ),
          ),
      ],
    );
  }
}
