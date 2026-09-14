import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_milestone.dart';
import '../providers/loyalty_admin_providers.dart';

/// "Reach N visits, get M points" -- an editable ladder, full-replace on
/// save (the backend takes the whole list every time, no per-row id on the
/// way in). Simpler than Settings/Rewards since there's no owner-facing
/// nuance beyond the three fields per rung; lower priority than the rest of
/// this feature per the build brief, so this stays a plain add/edit/remove
/// list rather than drag-to-reorder or per-row save.
class LoyaltyMilestonesScreen extends ConsumerWidget {
  final String providerId;

  const LoyaltyMilestonesScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final milestonesAsync = ref.watch(loyaltyMilestonesProvider(providerId));

    return milestonesAsync.when(
      data: (milestones) => _MilestonesForm(providerId: providerId, initial: milestones),
      loading: () => const FactoryLoadingState(),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorLoyaltyMilestonesLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(loyaltyMilestonesProvider(providerId)),
          ),
        ),
      ),
    );
  }
}

class _MilestoneDraft {
  final TextEditingController visitsController;
  final TextEditingController pointsController;
  final TextEditingController labelController;

  _MilestoneDraft({String visits = '', String points = '', String label = ''})
      : visitsController = TextEditingController(text: visits),
        pointsController = TextEditingController(text: points),
        labelController = TextEditingController(text: label);

  void dispose() {
    visitsController.dispose();
    pointsController.dispose();
    labelController.dispose();
  }
}

class _MilestonesForm extends ConsumerStatefulWidget {
  final String providerId;
  final List<LoyaltyMilestone> initial;

  const _MilestonesForm({required this.providerId, required this.initial});

  @override
  ConsumerState<_MilestonesForm> createState() => _MilestonesFormState();
}

class _MilestonesFormState extends ConsumerState<_MilestonesForm> {
  late List<_MilestoneDraft> _drafts;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initial
        .map((m) => _MilestoneDraft(visits: '${m.visitsRequired}', points: '${m.pointsAwarded}', label: m.label ?? ''))
        .toList();
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
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
          l10n.loyaltyMilestonesSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: FactorySpacing.space4),
        if (_drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
            child: Text(
              l10n.loyaltyMilestonesEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
            ),
          )
        else
          for (var i = 0; i < _drafts.length; i++) ...[
            _MilestoneRow(
              draft: _drafts[i],
              enabled: !_isSubmitting,
              onRemove: () => setState(() {
                _drafts[i].dispose();
                _drafts.removeAt(i);
              }),
            ),
            const SizedBox(height: FactorySpacing.space3),
          ],
        FactoryButton(
          label: l10n.loyaltyMilestoneAddButton,
          variant: FactoryButtonVariant.secondary,
          icon: Icons.add,
          onPressed: _isSubmitting ? null : () => setState(() => _drafts.add(_MilestoneDraft())),
        ),
        if (_error != null) ...[
          const SizedBox(height: FactorySpacing.space3),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: FactorySpacing.space5),
        FactoryButton(
          label: l10n.saveButton,
          expand: true,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final milestones = <LoyaltyMilestone>[];
    for (final d in _drafts) {
      final visits = int.tryParse(d.visitsController.text.trim());
      final points = int.tryParse(d.pointsController.text.trim());
      if (visits == null || visits <= 0 || points == null || points <= 0) {
        setState(() => _error = l10n.loyaltyMilestoneValidationError);
        return;
      }
      final label = d.labelController.text.trim();
      milestones.add(LoyaltyMilestone(visitsRequired: visits, pointsAwarded: points, label: label.isEmpty ? null : label));
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).replaceMilestones(widget.providerId, milestones);
      if (!mounted) return;
      invalidateLoyaltyMilestones(ref, widget.providerId);
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loyaltyMilestonesSavedMessage)));
    } catch (e) {
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

class _MilestoneRow extends StatelessWidget {
  final _MilestoneDraft draft;
  final bool enabled;
  final VoidCallback onRemove;

  const _MilestoneRow({required this.draft, required this.enabled, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FactoryTextField(
                  controller: draft.visitsController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  label: l10n.loyaltyMilestoneVisitsLabel,
                ),
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: FactoryTextField(
                  controller: draft.pointsController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  label: l10n.loyaltyMilestonePointsLabel,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: enabled ? onRemove : null,
                tooltip: l10n.loyaltyMilestoneRemoveButton,
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: draft.labelController,
            enabled: enabled,
            label: '${l10n.loyaltyMilestoneLabelLabel} (${l10n.loyaltySettingsOptionalSuffix})',
          ),
        ],
      ),
    );
  }
}
