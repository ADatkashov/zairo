import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_reward.dart';
import '../providers/loyalty_admin_providers.dart';
import '../widgets/loyalty_reward_card.dart';

/// Add-or-edit: pass [existing] to edit that reward in place instead of
/// creating a new one. Returns `true` via Navigator.pop on success -- the
/// caller (LoyaltyRewardsScreen) invalidates [loyaltyRewardsProvider] in
/// response, same pattern as `salon`'s AddServiceDialog.
///
/// The visible fields adapt to [LoyaltyRewardType]: only the fields the
/// backend actually validates for the selected type are shown, so the
/// owner can't fill in a discount amount for a reward the backend will
/// reject for having one.
class LoyaltyRewardFormScreen extends ConsumerStatefulWidget {
  final String providerId;
  final LoyaltyReward? existing;

  const LoyaltyRewardFormScreen({super.key, required this.providerId, this.existing});

  @override
  ConsumerState<LoyaltyRewardFormScreen> createState() => _LoyaltyRewardFormScreenState();
}

class _LoyaltyRewardFormScreenState extends ConsumerState<LoyaltyRewardFormScreen> {
  late LoyaltyRewardType _type;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsCostController;
  late final TextEditingController _discountAmountController;
  late final TextEditingController _discountCurrencyController;
  late final TextEditingController _discountPercentageController;
  late final TextEditingController _maxRedemptionsController;
  late final TextEditingController _termsController;
  String? _serviceId;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _type = r?.type ?? LoyaltyRewardType.fixedDiscount;
    _nameController = TextEditingController(text: r?.name ?? '');
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _pointsCostController = TextEditingController(text: r?.pointsCost.toString() ?? '');
    _discountAmountController = TextEditingController(text: r?.discountAmount?.toString() ?? '');
    _discountCurrencyController = TextEditingController(text: r?.discountCurrency ?? 'KZT');
    _discountPercentageController = TextEditingController(text: r?.discountPercentage?.toString() ?? '');
    _maxRedemptionsController = TextEditingController(text: r?.maxRedemptions?.toString() ?? '');
    _termsController = TextEditingController(text: r?.terms ?? '');
    _serviceId = r?.serviceId;
    _startsAt = r?.startsAt?.toLocal();
    _endsAt = r?.endsAt?.toLocal();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsCostController.dispose();
    _discountAmountController.dispose();
    _discountCurrencyController.dispose();
    _discountPercentageController.dispose();
    _maxRedemptionsController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: _isEditing ? l10n.loyaltyRewardEditTitle : l10n.loyaltyRewardAddTitle),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          FactoryTextField(controller: _nameController, enabled: !_isSubmitting, label: l10n.loyaltyRewardNameLabel),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyRewardDescriptionLabel,
            maxLines: 2,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _pointsCostController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            label: l10n.loyaltyRewardPointsCostFieldLabel,
          ),
          const SizedBox(height: FactorySpacing.space4),
          Text(l10n.loyaltyRewardTypeLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: FactorySpacing.space2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in LoyaltyRewardType.values)
                FactoryChip(
                  label: loyaltyRewardTypeLabel(l10n, type),
                  selected: _type == type,
                  onTap: _isSubmitting ? null : () => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space4),
          ..._typeSpecificFields(l10n),
          const SizedBox(height: FactorySpacing.space4),
          FactoryTextField(
            controller: _maxRedemptionsController,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.number,
            label: '${l10n.loyaltyRewardMaxRedemptionsFieldLabel} (${l10n.loyaltySettingsOptionalSuffix})',
          ),
          const SizedBox(height: FactorySpacing.space3),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.loyaltyRewardStartsAtLabel),
                  subtitle: Text(
                    _startsAt == null ? l10n.loyaltyRewardNoDateSet : DateFormat.yMMMd(locale).format(_startsAt!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : () => _pickDate(isStart: true),
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.loyaltyRewardEndsAtLabel),
                  subtitle: Text(
                    _endsAt == null ? l10n.loyaltyRewardNoDateSet : DateFormat.yMMMd(locale).format(_endsAt!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _isSubmitting ? null : () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _termsController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyRewardTermsLabel,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: FactorySpacing.space3),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: FactorySpacing.space5),
          FactoryButton(
            label: _isEditing ? l10n.saveButton : l10n.createButton,
            expand: true,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: FactorySpacing.space4),
        ],
      ),
    );
  }

  List<Widget> _typeSpecificFields(AppLocalizations l10n) {
    switch (_type) {
      case LoyaltyRewardType.fixedDiscount:
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: FactoryTextField(
                  controller: _discountAmountController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  label: l10n.loyaltyRewardDiscountAmountLabel,
                ),
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: FactoryTextField(
                  controller: _discountCurrencyController,
                  enabled: !_isSubmitting,
                  label: l10n.loyaltyRewardDiscountCurrencyLabel,
                ),
              ),
            ],
          ),
        ];
      case LoyaltyRewardType.percentageDiscount:
        return [
          FactoryTextField(
            controller: _discountPercentageController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            label: l10n.loyaltyRewardDiscountPercentageLabel,
          ),
        ];
      case LoyaltyRewardType.freeService:
        return [_ServicePicker(providerId: widget.providerId, value: _serviceId, onChanged: (v) => setState(() => _serviceId = v))];
      case LoyaltyRewardType.custom:
        return [
          Text(
            l10n.loyaltyRewardCustomTypeHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
          ),
        ];
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startsAt : _endsAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final pointsCost = int.tryParse(_pointsCostController.text.trim());
    if (name.isEmpty || pointsCost == null || pointsCost <= 0) {
      setState(() => _error = l10n.loyaltyRewardValidationErrorBasic);
      return;
    }

    double? discountAmount;
    String? discountCurrency;
    double? discountPercentage;
    String? serviceId;

    switch (_type) {
      case LoyaltyRewardType.fixedDiscount:
        discountAmount = double.tryParse(_discountAmountController.text.trim());
        discountCurrency = _discountCurrencyController.text.trim();
        if (discountAmount == null || discountAmount <= 0 || discountCurrency.length != 3) {
          setState(() => _error = l10n.loyaltyRewardValidationErrorFixedDiscount);
          return;
        }
      case LoyaltyRewardType.percentageDiscount:
        discountPercentage = double.tryParse(_discountPercentageController.text.trim());
        if (discountPercentage == null || discountPercentage <= 0 || discountPercentage > 100) {
          setState(() => _error = l10n.loyaltyRewardValidationErrorPercentageDiscount);
          return;
        }
      case LoyaltyRewardType.freeService:
        serviceId = _serviceId;
        if (serviceId == null) {
          setState(() => _error = l10n.loyaltyRewardValidationErrorFreeService);
          return;
        }
      case LoyaltyRewardType.custom:
        break;
    }

    final draft = LoyaltyReward(
      id: widget.existing?.id,
      name: name,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      type: _type,
      pointsCost: pointsCost,
      discountAmount: discountAmount,
      discountCurrency: discountCurrency?.toUpperCase(),
      discountPercentage: discountPercentage,
      serviceId: serviceId,
      maxRedemptions: int.tryParse(_maxRedemptionsController.text.trim()),
      startsAt: _startsAt,
      endsAt: _endsAt,
      terms: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final api = ref.read(loyaltyAdminApiProvider);
      if (_isEditing) {
        await api.updateReward(widget.providerId, widget.existing!.id!, draft);
      } else {
        await api.createReward(widget.providerId, draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

/// Sources from the same `providerServicesProvider` this app's
/// salon/services feature already uses to let an owner pick one of their
/// own services -- reused here rather than a bespoke service lookup, per
/// the free-service reward needing exactly that same picker.
class _ServicePicker extends ConsumerWidget {
  final String providerId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _ServicePicker({required this.providerId, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final servicesAsync = ref.watch(providerServicesProvider((providerId, true)));

    return servicesAsync.when(
      data: (services) {
        final hasValue = services.any((s) => s.id == value);
        if (services.isEmpty) {
          return Text(
            l10n.loyaltyRewardNoServicesAvailable,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: hasValue ? value : null,
          decoration: InputDecoration(labelText: l10n.loyaltyRewardServiceLabel),
          items: [for (final service in services) DropdownMenuItem(value: service.id, child: Text(service.title))],
          onChanged: onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(l10n.errorLoyaltyRewardsLoadFailed(error.toString())),
    );
  }
}
