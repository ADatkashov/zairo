import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_settings.dart';
import '../providers/loyalty_admin_providers.dart';

/// The entry point an owner uses first ("Enable Loyalty") -- the enable
/// toggle plus every earning/redemption/expiration/cap field the backend's
/// `PUT .../loyalty/settings` accepts, as one full-replace form (every field
/// is sent back on every save, per [LoyaltySettings.toUpdateJson]). `GET`
/// auto-creates a disabled draft on first call, so this never shows an
/// empty state -- there's always a settings row to edit, even before the
/// owner has saved anything.
class LoyaltySettingsScreen extends ConsumerWidget {
  final String providerId;

  const LoyaltySettingsScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(loyaltySettingsProvider(providerId));

    return settingsAsync.when(
      data: (settings) => _SettingsForm(providerId: providerId, settings: settings),
      loading: () => const FactoryLoadingState(),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorLoyaltySettingsLoadFailed,
            onRetry: () => ref.invalidate(loyaltySettingsProvider(providerId)),
          ),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final String providerId;
  final LoyaltySettings settings;

  const _SettingsForm({required this.providerId, required this.settings});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _enabled;
  late bool _pointsExpireEnabled;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _fixedPointsController;
  late final TextEditingController _pointsPerUnitController;
  late final TextEditingController _firstBookingBonusController;
  late final TextEditingController _repeatVisitBonusController;
  late final TextEditingController _repeatVisitThresholdController;
  late final TextEditingController _reviewBonusController;
  late final TextEditingController _birthdayBonusController;
  late final TextEditingController _redemptionRateController;
  late final TextEditingController _minRedemptionController;
  late final TextEditingController _maxRedemptionPerBookingController;
  late final TextEditingController _expirationMonthsController;
  late final TextEditingController _dailyCapController;
  late final TextEditingController _monthlyCapController;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _enabled = s.enabled;
    _pointsExpireEnabled = s.pointsExpireEnabled;
    _nameController = TextEditingController(text: s.name);
    _descriptionController = TextEditingController(text: s.description ?? '');
    _fixedPointsController = TextEditingController(text: '${s.fixedPointsPerBooking}');
    _pointsPerUnitController = TextEditingController(text: _formatNum(s.pointsPerCurrencyUnit));
    _firstBookingBonusController = TextEditingController(text: '${s.firstBookingBonusPoints}');
    _repeatVisitBonusController = TextEditingController(text: '${s.repeatVisitBonusPoints}');
    _repeatVisitThresholdController = TextEditingController(text: '${s.repeatVisitThreshold}');
    _reviewBonusController = TextEditingController(text: '${s.reviewBonusPoints}');
    _birthdayBonusController = TextEditingController(text: '${s.birthdayBonusPoints}');
    _redemptionRateController =
        TextEditingController(text: s.pointsPerCurrencyUnitRedemption == null ? '' : _formatNum(s.pointsPerCurrencyUnitRedemption!));
    _minRedemptionController = TextEditingController(text: s.minRedemptionPoints?.toString() ?? '');
    _maxRedemptionPerBookingController = TextEditingController(text: s.maxRedemptionPointsPerBooking?.toString() ?? '');
    _expirationMonthsController = TextEditingController(text: s.pointsExpirationMonths?.toString() ?? '');
    _dailyCapController = TextEditingController(text: s.dailyEarningPointsCap?.toString() ?? '');
    _monthlyCapController = TextEditingController(text: s.monthlyEarningPointsCap?.toString() ?? '');
  }

  static String _formatNum(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fixedPointsController.dispose();
    _pointsPerUnitController.dispose();
    _firstBookingBonusController.dispose();
    _repeatVisitBonusController.dispose();
    _repeatVisitThresholdController.dispose();
    _reviewBonusController.dispose();
    _birthdayBonusController.dispose();
    _redemptionRateController.dispose();
    _minRedemptionController.dispose();
    _maxRedemptionPerBookingController.dispose();
    _expirationMonthsController.dispose();
    _dailyCapController.dispose();
    _monthlyCapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return ListView(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      children: [
        FactoryCard(
          child: Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.loyaltySettingsEnableTitle),
              subtitle: Text(l10n.loyaltySettingsEnableSubtitle),
              value: _enabled,
              onChanged: _isSubmitting ? null : (v) => setState(() => _enabled = v),
            ),
          ),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.loyaltySettingsSectionProgram),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              FactoryTextField(controller: _nameController, enabled: !_isSubmitting, label: l10n.loyaltySettingsNameLabel),
              const SizedBox(height: FactorySpacing.space3),
              FactoryTextField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsDescriptionLabel,
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.loyaltySettingsSectionEarning),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              _NumberField(
                controller: _fixedPointsController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsFixedPointsPerBookingLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _pointsPerUnitController,
                enabled: !_isSubmitting,
                decimal: true,
                label: l10n.loyaltySettingsPointsPerCurrencyUnitLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _firstBookingBonusController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsFirstBookingBonusLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _repeatVisitBonusController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsRepeatVisitBonusLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _repeatVisitThresholdController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsRepeatVisitThresholdLabel,
                hint: l10n.loyaltySettingsRepeatVisitThresholdHint,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _reviewBonusController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsReviewBonusLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _birthdayBonusController,
                enabled: !_isSubmitting,
                label: l10n.loyaltySettingsBirthdayBonusLabel,
                hint: l10n.loyaltySettingsBirthdayBonusHint,
              ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.loyaltySettingsSectionRedemption),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              _NumberField(
                controller: _redemptionRateController,
                enabled: !_isSubmitting,
                decimal: true,
                optional: true,
                label: l10n.loyaltySettingsRedemptionRateLabel,
                hint: l10n.loyaltySettingsRedemptionRateHint,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _minRedemptionController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.loyaltySettingsMinRedemptionLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _maxRedemptionPerBookingController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.loyaltySettingsMaxRedemptionPerBookingLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.loyaltySettingsSectionExpiration),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.loyaltySettingsExpireEnabledTitle),
                  value: _pointsExpireEnabled,
                  onChanged: _isSubmitting ? null : (v) => setState(() => _pointsExpireEnabled = v),
                ),
              ),
              if (_pointsExpireEnabled) ...[
                const SizedBox(height: FactorySpacing.space3),
                _NumberField(
                  controller: _expirationMonthsController,
                  enabled: !_isSubmitting,
                  label: l10n.loyaltySettingsExpirationMonthsLabel,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space5),
        FactorySectionHeader(title: l10n.loyaltySettingsSectionCaps),
        const SizedBox(height: FactorySpacing.space2),
        FactoryCard(
          child: Column(
            children: [
              _NumberField(
                controller: _dailyCapController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.loyaltySettingsDailyCapLabel,
              ),
              const SizedBox(height: FactorySpacing.space3),
              _NumberField(
                controller: _monthlyCapController,
                enabled: !_isSubmitting,
                optional: true,
                label: l10n.loyaltySettingsMonthlyCapLabel,
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
    final name = _nameController.text.trim();
    final fixedPoints = int.tryParse(_fixedPointsController.text.trim());
    final pointsPerUnit = double.tryParse(_pointsPerUnitController.text.trim());
    final firstBookingBonus = int.tryParse(_firstBookingBonusController.text.trim());
    final repeatVisitBonus = int.tryParse(_repeatVisitBonusController.text.trim());
    final repeatVisitThreshold = int.tryParse(_repeatVisitThresholdController.text.trim());
    final reviewBonus = int.tryParse(_reviewBonusController.text.trim());
    final birthdayBonus = int.tryParse(_birthdayBonusController.text.trim());

    if (name.isEmpty ||
        fixedPoints == null ||
        fixedPoints < 0 ||
        pointsPerUnit == null ||
        pointsPerUnit < 0 ||
        firstBookingBonus == null ||
        firstBookingBonus < 0 ||
        repeatVisitBonus == null ||
        repeatVisitBonus < 0 ||
        repeatVisitThreshold == null ||
        repeatVisitThreshold < 2 ||
        reviewBonus == null ||
        reviewBonus < 0 ||
        birthdayBonus == null ||
        birthdayBonus < 0) {
      setState(() => _error = l10n.loyaltySettingsValidationError);
      return;
    }
    if (_pointsExpireEnabled) {
      final months = int.tryParse(_expirationMonthsController.text.trim());
      if (months == null || months <= 0) {
        setState(() => _error = l10n.loyaltySettingsExpirationValidationError);
        return;
      }
    }

    final updated = LoyaltySettings(
      providerId: widget.providerId,
      enabled: _enabled,
      name: name,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      fixedPointsPerBooking: fixedPoints,
      pointsPerCurrencyUnit: pointsPerUnit,
      firstBookingBonusPoints: firstBookingBonus,
      repeatVisitBonusPoints: repeatVisitBonus,
      repeatVisitThreshold: repeatVisitThreshold,
      reviewBonusPoints: reviewBonus,
      pointsPerCurrencyUnitRedemption: double.tryParse(_redemptionRateController.text.trim()),
      minRedemptionPoints: int.tryParse(_minRedemptionController.text.trim()),
      maxRedemptionPointsPerBooking: int.tryParse(_maxRedemptionPerBookingController.text.trim()),
      pointsExpireEnabled: _pointsExpireEnabled,
      pointsExpirationMonths: _pointsExpireEnabled ? int.tryParse(_expirationMonthsController.text.trim()) : null,
      dailyEarningPointsCap: int.tryParse(_dailyCapController.text.trim()),
      monthlyEarningPointsCap: int.tryParse(_monthlyCapController.text.trim()),
      birthdayBonusPoints: birthdayBonus,
    );

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).updateSettings(widget.providerId, updated);
      if (!mounted) return;
      invalidateLoyaltySettings(ref, widget.providerId);
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loyaltySettingsSavedMessage)));
    } catch (e) {
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed;
        _isSubmitting = false;
      });
    }
  }
}

/// A plain integer/decimal field -- [optional] means an empty value is a
/// valid "not set" (mapped to `null` on save), rather than every numeric
/// field in this long form needing its own inline validator.
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
    return FactoryTextField(
      controller: controller,
      enabled: enabled,
      label: optional ? '$label (${AppLocalizations.of(context)!.loyaltySettingsOptionalSuffix})' : label,
      hint: hint,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    );
  }
}
