import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/platform_admin_account.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/staff_api.dart';

/// The staff directory — platform admins only. A role per person, an add
/// button, and an on/off action with a confirmation before anyone loses
/// access. A legend at the top says what each role can do.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(staffProvider);
    final me = ref.watch(sessionControllerProvider).value?.admin;
    Future<void> refresh() => ref.refresh(staffProvider.future);

    return AreaScaffold(
      title: l10n.navStaff,
      actions: [IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh)],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.staffAdd),
        onPressed: () async {
          final created = await showDialog<String>(context: context, builder: (_) => const _CreateStaffDialog());
          if (created == null || !context.mounted) return;
          ref.invalidate(staffProvider);
          showSnack(context, l10n.staffAdded(created));
        },
      ),
      body: AsyncView<List<PlatformAdminAccount>>(
        value: async,
        onRetry: () => ref.invalidate(staffProvider),
        builder: (accounts) => ContentFrame(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space4,
                FactorySpacing.space4,
                96,
              ),
              children: [
                _RoleLegend(accounts: accounts),
                const SizedBox(height: FactorySpacing.space4),
                for (final account in accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                    child: _StaffTile(account: account, isMe: account.email == me?.email),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleLegend extends StatelessWidget {
  const _RoleLegend({required this.accounts});

  /// Active people per role are counted from these.
  final List<PlatformAdminAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactorySectionHeader(title: l10n.staffRolesTitle),
          const SizedBox(height: FactorySpacing.space2),
          for (final role in const ['PLATFORM_ADMIN', 'PLATFORM_MODERATOR', 'PLATFORM_SUPPORT'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: roleLabel(l10n, role),
                            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' — ${roleDescription(l10n, role)}',
                            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                  // How many active people hold the role.
                  Icon(Icons.person_outline_rounded, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    '${accounts.where((a) => a.active && a.role == role).length}',
                    style: FactoryTypography.mono(size: 13, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.account, required this.isMe});

  final PlatformAdminAccount account;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: initialsFor(account.displayName),
        image: account.avatarUrl != null ? NetworkImage(account.avatarUrl!) : null,
      ),
      title: account.displayName,
      titleColor: account.active ? null : Theme.of(context).disabledColor,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(account.email),
          Text(roleLabel(l10n, account.role)),
          // Under the text rather than beside it, so it fits a phone's width.
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space1),
              child: FactoryButton(
                label: account.active ? l10n.staffDeactivate : l10n.staffReactivate,
                variant: account.active ? FactoryButtonVariant.textDanger : FactoryButtonVariant.text,
                onPressed: () => _toggle(context, ref),
              ),
            ),
        ],
      ),
      trailing: isMe
          ? ToneBadge(label: l10n.staffYou)
          : account.active
          ? ToneBadge(label: l10n.statusActive, tone: Tone.good)
          : ToneBadge(label: l10n.staffDeactivated),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(staffApiProvider);
    String? reason;
    if (account.active) {
      reason = await promptText(
        context,
        title: l10n.staffDeactivateTitle(account.displayName),
        message: l10n.staffDeactivateMessage,
        fieldLabel: l10n.reasonOptional,
        confirmLabel: l10n.staffDeactivate,
        destructive: true,
      );
      if (reason == null || !context.mounted) return;
    }
    try {
      final cleanReason = (reason == null || reason.isEmpty) ? null : reason;
      if (account.active) {
        await api.deactivate(account.id, reason: cleanReason);
      } else {
        await api.reactivate(account.id);
      }
      ref.invalidate(staffProvider);
      if (context.mounted) {
        showSnack(
          context,
          account.active
              ? l10n.staffWasDeactivated(account.displayName)
              : l10n.staffWasReactivated(account.displayName),
        );
      }
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }
}

class _CreateStaffDialog extends ConsumerStatefulWidget {
  const _CreateStaffDialog();

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
    for (final controller in [_displayName, _email, _password, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const gap = SizedBox(height: FactorySpacing.space3);
    return FactoryDialog(
      title: l10n.staffAddTitle,
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _displayName,
                  enabled: !_isSubmitting,
                  label: l10n.fieldFullName,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
                ),
                gap,
                FactoryTextField(
                  controller: _email,
                  enabled: !_isSubmitting,
                  label: l10n.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@')) ? l10n.emailInvalid : null,
                ),
                gap,
                FactoryTextField(
                  controller: _password,
                  enabled: !_isSubmitting,
                  label: l10n.fieldTempPassword,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 8) ? l10n.fieldPasswordShort : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space1),
                    child: Text(l10n.fieldPasswordHelper, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
                gap,
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.fieldRole),
                  items: [
                    for (final role in const ['PLATFORM_ADMIN', 'PLATFORM_MODERATOR', 'PLATFORM_SUPPORT'])
                      DropdownMenuItem(
                        value: role,
                        child: Text(
                          '${roleLabel(l10n, role)} — ${roleDescription(l10n, role)}',
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
                FactoryTextField(controller: _reason, enabled: !_isSubmitting, label: l10n.reasonOptionalLog),
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
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(label: l10n.create, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
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
          .read(staffApiProvider)
          .create(
            email: _email.text.trim(),
            password: _password.text.trim(),
            displayName: name,
            role: _role,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(name);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = isConflict(error) ? l10n.staffEmailTaken : describeError(l10n, error);
        _isSubmitting = false;
      });
    }
  }
}
