import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/platform_admin_account_summary.dart';
import '../../data/models/platform_admin_session.dart';
import '../platform_admin_labels.dart';
import '../providers/platform_admin_providers.dart';
import '../widgets/platform_admin_common.dart';

/// The staff directory — PLATFORM_ADMIN-only, the one role that can create or
/// deactivate another platform account. A role per person, an add button, and
/// an on/off action with a confirmation before anyone loses access.
class PlatformAdminStaffTab extends ConsumerWidget {
  const PlatformAdminStaffTab({super.key, required this.session});

  final PlatformAdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final token = session.accessToken;
    final adminsAsync = ref.watch(platformAdminsProvider(token));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: adminsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => PlatformLoadError(onRetry: () => ref.invalidate(platformAdminsProvider(token))),
        data: (admins) => PlatformContentFrame(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(platformAdminsProvider(token).future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              // Leave room so the add button never covers the last row.
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space4,
                FactorySpacing.space4,
                96,
              ),
              itemCount: admins.length,
              separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
              itemBuilder: (context, index) => _StaffTile(admin: admins[index], session: session),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.paStaffAddButton),
        onPressed: () async {
          final created = await showDialog<String>(
            context: context,
            builder: (_) => _CreateStaffDialog(platformToken: token),
          );
          if (created == null || !context.mounted) return;
          ref.invalidate(platformAdminsProvider(token));
          showPlatformSnack(context, l10n.paStaffAdded(created));
        },
      ),
    );
  }
}

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.admin, required this.session});

  final PlatformAdminAccountSummary admin;
  final PlatformAdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isYou = admin.email == session.email;
    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: initialsFor(admin.displayName),
        image: admin.avatarUrl != null ? NetworkImage(admin.avatarUrl!) : null,
      ),
      title: admin.displayName,
      titleColor: admin.active ? null : Theme.of(context).disabledColor,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(admin.email),
          Text(platformRoleLabel(l10n, admin.role)),
          // Under the text rather than beside it, so it fits a phone's width.
          if (!isYou)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space1),
              child: FactoryButton(
                label: admin.active ? l10n.paStaffDeactivate : l10n.paStaffReactivate,
                variant: admin.active ? FactoryButtonVariant.textDanger : FactoryButtonVariant.text,
                onPressed: () => _toggle(context, ref),
              ),
            ),
        ],
      ),
      trailing: isYou
          ? FactoryBadge(label: l10n.paStaffYou)
          : admin.active
          ? FactoryBadge(label: l10n.paStatusActive, variant: FactoryBadgeVariant.available)
          : FactoryBadge(label: l10n.paStaffDeactivated),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(platformAdminApiProvider);
    final token = session.accessToken;
    if (admin.active) {
      final confirmed = await confirmPlatformAction(
        context,
        title: l10n.paStaffDeactivateTitle(admin.displayName),
        message: l10n.paStaffDeactivateMessage,
        confirmLabel: l10n.paStaffDeactivate,
      );
      if (!confirmed || !context.mounted) return;
    }
    try {
      if (admin.active) {
        await api.deactivateAdmin(token, admin.id);
      } else {
        await api.reactivateAdmin(token, admin.id);
      }
      ref.invalidate(platformAdminsProvider(token));
      if (context.mounted) {
        showPlatformSnack(
          context,
          admin.active ? l10n.paStaffWasDeactivated(admin.displayName) : l10n.paStaffActivated(admin.displayName),
        );
      }
    } catch (_) {
      if (context.mounted) showPlatformSnack(context, l10n.paActionFailed);
    }
  }
}

class _CreateStaffDialog extends ConsumerStatefulWidget {
  const _CreateStaffDialog({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_CreateStaffDialog> createState() => _CreateStaffDialogState();
}

class _CreateStaffDialogState extends ConsumerState<_CreateStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _reason = TextEditingController();
  String _role = 'PLATFORM_SUPPORT';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const gap = SizedBox(height: FactorySpacing.space3);
    return FactoryDialog(
      title: l10n.paStaffAddTitle,
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _displayName,
                  enabled: !_isSubmitting,
                  label: l10n.paFieldFullName,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.paFieldRequired : null,
                ),
                gap,
                FactoryTextField(
                  controller: _email,
                  enabled: !_isSubmitting,
                  label: l10n.emailLabel,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@')) ? l10n.paFieldEmailInvalid : null,
                ),
                gap,
                FactoryTextField(
                  controller: _password,
                  enabled: !_isSubmitting,
                  label: l10n.paFieldTempPassword,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 8) ? l10n.paFieldPasswordShort : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: FactorySpacing.space1),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.paFieldPasswordHelper, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.paFieldRole),
                  items: [
                    for (final role in const ['PLATFORM_ADMIN', 'PLATFORM_MODERATOR', 'PLATFORM_SUPPORT'])
                      DropdownMenuItem(
                        value: role,
                        child: Text(
                          '${platformRoleLabel(l10n, role)} — ${platformRoleDescription(l10n, role)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _role = value);
                        },
                ),
                gap,
                FactoryTextField(controller: _reason, enabled: !_isSubmitting, label: l10n.paFieldReason),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space3),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final name = _displayName.text.trim();
    try {
      await ref
          .read(platformAdminApiProvider)
          .createAdmin(
            widget.platformToken,
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: name,
            role: _role,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(name);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.paActionFailed;
        _isSubmitting = false;
      });
    }
  }
}
