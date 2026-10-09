import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/auth_exception.dart';
import '../../../auth/data/models/user_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Edits the customer's personal details: name, birthday (so businesses can
/// greet them and grant birthday bonuses), gender and the opt-in for
/// greetings/offers. Email is only editable while the account has none
/// (phone-only signup) — changing a login email later needs verification
/// that doesn't exist yet.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserSummary user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _genderFemale = 'FEMALE';
  static const _genderMale = 'MALE';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  DateTime? _birthDate;
  String? _gender;
  late bool _marketingConsent;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user.displayName);
    _emailController = TextEditingController(text: user.email ?? '');
    _birthDate = user.birthDate;
    _gender = user.gender;
    _marketingConsent = user.marketingConsent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailEditable => (widget.user.email ?? '').isEmpty;

  /// Anything differs from what the screen opened with.
  bool get _dirty {
    final user = widget.user;
    return _nameController.text.trim() != user.displayName ||
        _emailController.text.trim() != (user.email ?? '') ||
        _birthDate != user.birthDate ||
        _gender != user.gender ||
        _marketingConsent != user.marketingConsent;
  }

  /// Set once the profile has been saved, so leaving afterwards isn't blocked.
  bool _saved = false;

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final discard = await showFactoryDialog<bool>(
      context: context,
      title: l10n.discardChangesTitle,
      message: l10n.discardChangesMessage,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.discardChangesKeepEditing,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.discardChangesDiscard,
            variant: FactoryButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (discard == true && mounted) {
      setState(() => _saved = true);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final localeName = Localizations.localeOf(context).toString();

    // Rebuilds as the user types so `_dirty` stays current for PopScope.
    return ListenableBuilder(
      listenable: Listenable.merge([_nameController, _emailController]),
      builder: (context, child) => PopScope(
        canPop: _saved || _saving || !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: child!,
      ),
      child: Scaffold(
        appBar: FactoryAppBar(title: l10n.editProfileTitle),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              FactoryTextField(
                controller: _nameController,
                label: l10n.registerNameLabel,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty) ? l10n.validationNameRequired : null,
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _emailController,
                label: l10n.emailLabel,
                keyboardType: TextInputType.emailAddress,
                enabled: _emailEditable,
                validator: (value) {
                  if (!_emailEditable) return null;
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return text.contains('@') ? null : l10n.validationEmailInvalid;
                },
              ),
              const SizedBox(height: FactorySpacing.space5),
              Text(l10n.editProfileBirthdayLabel, style: textTheme.titleSmall),
              const SizedBox(height: FactorySpacing.space1),
              Text(l10n.editProfileBirthdayHint, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              const SizedBox(height: FactorySpacing.space2),
              FactorySelectableTile(
                title: _birthDate == null
                    ? l10n.editProfileBirthdayNotSet
                    : DateFormat.yMMMMd(localeName).format(_birthDate!),
                leading: Icon(Symbols.cake_rounded, color: colors.textSecondary),
                trailing: _birthDate == null
                    ? Icon(Symbols.chevron_right_rounded, color: colors.textTertiary)
                    : IconButton(
                        icon: const Icon(Symbols.close_rounded),
                        tooltip: l10n.editProfileBirthdayClear,
                        onPressed: _saving ? null : () => setState(() => _birthDate = null),
                      ),
                onTap: _saving ? null : _pickBirthDate,
              ),
              const SizedBox(height: FactorySpacing.space5),
              Text(l10n.editProfileGenderLabel, style: textTheme.titleSmall),
              const SizedBox(height: FactorySpacing.space2),
              Wrap(
                spacing: FactorySpacing.space2,
                runSpacing: FactorySpacing.space2,
                children: [
                  FactoryChip(
                    label: l10n.editProfileGenderFemale,
                    selected: _gender == _genderFemale,
                    onTap: () => setState(() => _gender = _genderFemale),
                  ),
                  FactoryChip(
                    label: l10n.editProfileGenderMale,
                    selected: _gender == _genderMale,
                    onTap: () => setState(() => _gender = _genderMale),
                  ),
                  FactoryChip(
                    label: l10n.editProfileGenderNotSpecified,
                    selected: _gender == null,
                    onTap: () => setState(() => _gender = null),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.space5),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.editProfileMarketingTitle),
                subtitle: Text(l10n.editProfileMarketingSubtitle),
                value: _marketingConsent,
                onChanged: _saving ? null : (value) => setState(() => _marketingConsent = value),
              ),
              const SizedBox(height: FactorySpacing.space5),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FactoryButton(label: l10n.editProfileSave, isLoading: _saving, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final user = widget.user;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            displayName: name,
            email: _emailEditable && email.isNotEmpty ? email : null,
            birthDate: _birthDate,
            clearBirthDate: _birthDate == null && user.birthDate != null,
            gender: _gender ?? 'NOT_SPECIFIED',
            marketingConsent: _marketingConsent,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.editProfileSaved)));
      setState(() => _saved = true);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is AuthException ? e.localizedMessage(l10n) : l10n.errorAuthGeneric;
      });
    }
  }
}
