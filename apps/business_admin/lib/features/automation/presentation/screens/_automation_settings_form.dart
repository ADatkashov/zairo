import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/automation_exception.dart';
import '../../data/models/automation_settings.dart';
import '../providers/automation_providers.dart';

/// Every field the backend's `PUT .../automation/settings` accepts, as one
/// full-replace form (every field is sent back on every save, per
/// [AutomationSettings.toUpdateJson]) -- same shape as
/// `loyalty`'s own `LoyaltySettingsScreen._SettingsForm`. `GET` auto-creates
/// an all-enabled draft on first call, so this never shows an empty state.
class AutomationSettingsForm extends ConsumerStatefulWidget {
  final String providerId;
  final AutomationSettings settings;

  const AutomationSettingsForm({super.key, required this.providerId, required this.settings});

  @override
  ConsumerState<AutomationSettingsForm> createState() => _AutomationSettingsFormState();
}

class _AutomationSettingsFormState extends ConsumerState<AutomationSettingsForm> {
  late bool _rebookEnabled;
  late bool _reactivationEnabled;
  late bool _smartFillEnabled;
  late final TextEditingController _rebookMinVisitsController;
  late final TextEditingController _rebookMinIntervalController;
  late final TextEditingController _rebookMaxIntervalController;
  late final TextEditingController _rebookFollowUpController;
  late final TextEditingController _reactivationScanMinController;
  late final TextEditingController _reactivationMultiplierController;
  late final TextEditingController _reactivationAbsoluteMaxController;
  late final TextEditingController _reactivationFollowUpController;
  late final TextEditingController _allowedHoursStartController;
  late final TextEditingController _allowedHoursEndController;
  late final TextEditingController _timezoneController;
  late final TextEditingController _cooldownController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _rebookEnabled = s.rebookEnabled;
    _reactivationEnabled = s.reactivationEnabled;
    _smartFillEnabled = s.smartFillEnabled;
    _rebookMinVisitsController = TextEditingController(text: s.rebookMinVisitsToEstablishInterval?.toString() ?? '');
    _rebookMinIntervalController = TextEditingController(text: s.rebookMinIntervalDays?.toString() ?? '');
    _rebookMaxIntervalController = TextEditingController(text: s.rebookMaxIntervalDays?.toString() ?? '');
    _rebookFollowUpController = TextEditingController(text: s.rebookFollowUpWindowDays?.toString() ?? '');
    _reactivationScanMinController =
        TextEditingController(text: s.reactivationScanMinInactivityDays?.toString() ?? '');
    _reactivationMultiplierController =
        TextEditingController(text: s.reactivationIntervalMultiplier?.toString() ?? '');
    _reactivationAbsoluteMaxController =
        TextEditingController(text: s.reactivationAbsoluteMaxInactivityDays?.toString() ?? '');
    _reactivationFollowUpController =
        TextEditingController(text: s.reactivationFollowUpWindowDays?.toString() ?? '');
    _allowedHoursStartController = TextEditingController(text: s.allowedHoursStart?.toString() ?? '');
    _allowedHoursEndController = TextEditingController(text: s.allowedHoursEnd?.toString() ?? '');
    _timezoneController = TextEditingController(text: s.timezone ?? '');
    _cooldownController = TextEditingController(text: s.cooldownDaysBetweenOffers?.toString() ?? '');
  }

  @override
  void dispose() {
    _rebookMinVisitsController.dispose();
    _rebookMinIntervalController.dispose();
    _rebookMaxIntervalController.dispose();
    _rebookFollowUpController.dispose();
    _reactivationScanMinController.dispose();
    _reactivationMultiplierController.dispose();
    _reactivationAbsoluteMaxController.dispose();
    _reactivationFollowUpController.dispose();
    _allowedHoursStartController.dispose();
    _allowedHoursEndController.dispose();
    _timezoneController.dispose();
    _cooldownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        Text(
          l10n.automationCenterIntro,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: FactorySpacing.space5),

        FactorySectionHeader(title: l10n.automationSectionSmartFill),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.automationSmartFillEnableTitle),
              subtitle: Text(l10n.automationSmartFillEnableSubtitle),
              value: _smartFillEnabled,
              onChanged: _isSubmitting ? null : (v) => setState(() => _smartFillEnabled = v),
            ),
          ),
        ),

        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.automationSectionRebook),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.automationRebookEnableTitle),
                  subtitle: Text(l10n.automationRebookEnableSubtitle),
                  value: _rebookEnabled,
                  onChanged: _isSubmitting ? null : (v) => setState(() => _rebookEnabled = v),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _rebookMinVisitsController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationRebookMinVisitsLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _rebookMinIntervalController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationRebookMinIntervalLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _rebookMaxIntervalController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationRebookMaxIntervalLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _rebookFollowUpController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationRebookFollowUpLabel,
              ),
            ],
          ),
        ),

        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.automationSectionReactivation),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.automationReactivationEnableTitle),
                  subtitle: Text(l10n.automationReactivationEnableSubtitle),
                  value: _reactivationEnabled,
                  onChanged: _isSubmitting ? null : (v) => setState(() => _reactivationEnabled = v),
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _reactivationScanMinController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationReactivationScanMinLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _reactivationMultiplierController,
                enabled: !_isSubmitting,
                optional: true,
                decimal: true,
                label: l10n.automationReactivationMultiplierLabel,
                hint: l10n.automationReactivationMultiplierHint,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _reactivationAbsoluteMaxController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationReactivationAbsoluteMaxLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _reactivationFollowUpController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationReactivationFollowUpLabel,
              ),
            ],
          ),
        ),

        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.automationSectionTiming),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _NumberField(
                      controller: _allowedHoursStartController,
                      enabled: !_isSubmitting,
                      optional: true,
                      label: l10n.automationAllowedHoursStartLabel,
                      hint: l10n.automationAllowedHoursHint,
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(
                    child: _NumberField(
                      controller: _allowedHoursEndController,
                      enabled: !_isSubmitting,
                      optional: true,
                      label: l10n.automationAllowedHoursEndLabel,
                      hint: l10n.automationAllowedHoursHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _timezoneController,
                enabled: !_isSubmitting,
                label: l10n.automationTimezoneLabel,
                hint: l10n.automationTimezoneHint,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _cooldownController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.automationCooldownLabel,
                hint: l10n.automationCooldownHint,
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: FactorySpacing.space4),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: FactorySpacing.space5),
        FactoryButton(
          label: l10n.saveButton,
          expand: true,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
        const SizedBox(height: FactorySpacing.space4),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    final allowedHoursStart = _intOrNull(_allowedHoursStartController.text);
    final allowedHoursEnd = _intOrNull(_allowedHoursEndController.text);
    if ((allowedHoursStart == null) != (allowedHoursEnd == null)) {
      setState(() => _error = l10n.automationAllowedHoursValidationError);
      return;
    }

    final updated = AutomationSettings(
      rebookEnabled: _rebookEnabled,
      reactivationEnabled: _reactivationEnabled,
      smartFillEnabled: _smartFillEnabled,
      rebookMinVisitsToEstablishInterval: _intOrNull(_rebookMinVisitsController.text),
      rebookMinIntervalDays: _intOrNull(_rebookMinIntervalController.text),
      rebookMaxIntervalDays: _intOrNull(_rebookMaxIntervalController.text),
      rebookFollowUpWindowDays: _intOrNull(_rebookFollowUpController.text),
      reactivationScanMinInactivityDays: _intOrNull(_reactivationScanMinController.text),
      reactivationIntervalMultiplier: _doubleOrNull(_reactivationMultiplierController.text),
      reactivationAbsoluteMaxInactivityDays: _intOrNull(_reactivationAbsoluteMaxController.text),
      reactivationFollowUpWindowDays: _intOrNull(_reactivationFollowUpController.text),
      allowedHoursStart: allowedHoursStart,
      allowedHoursEnd: allowedHoursEnd,
      timezone: _timezoneController.text.trim().isEmpty ? null : _timezoneController.text.trim(),
      cooldownDaysBetweenOffers: _intOrNull(_cooldownController.text),
    );

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(automationApiProvider).updateSettings(widget.providerId, updated);
      if (!mounted) return;
      ref.invalidate(automationSettingsProvider(widget.providerId));
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.automationSettingsSavedMessage)));
    } catch (e) {
      setState(() {
        _error = e is AutomationException ? e.localizedMessage(l10n) : l10n.errorAutomationActionFailed;
        _isSubmitting = false;
      });
    }
  }

  static int? _intOrNull(String text) => int.tryParse(text.trim());

  static double? _doubleOrNull(String text) => double.tryParse(text.trim());
}

/// A plain integer/decimal field where an empty value is a valid "use the
/// platform default", same [optional] convention as `loyalty`'s own
/// `LoyaltySettingsScreen._NumberField`.
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String? hint;
  final bool decimal;
  final bool optional;

  const _NumberField({
    required this.controller,
    required this.enabled,
    required this.label,
    this.hint,
    this.decimal = false,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryTextField(
      controller: controller,
      enabled: enabled,
      label: optional ? '$label (${l10n.loyaltySettingsOptionalSuffix})' : label,
      hint: hint,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    );
  }
}
