import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../../data/models/loyalty_tier.dart';
import '../providers/loyalty_admin_providers.dart';

/// "Reach N lifetime points, you're in this tier" -- same editable,
/// full-replace-ladder shape as [LoyaltyMilestonesScreen], one rung simpler
/// (no optional label). Lower priority per the build brief.
class LoyaltyTiersScreen extends ConsumerWidget {
  final String providerId;

  const LoyaltyTiersScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tiersAsync = ref.watch(loyaltyTiersProvider(providerId));

    return tiersAsync.when(
      data: (tiers) => _TiersForm(providerId: providerId, initial: tiers),
      loading: () => const FactoryLoadingState(),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.errorLoyaltyTiersLoadFailed(error.toString()),
            onRetry: () => ref.invalidate(loyaltyTiersProvider(providerId)),
          ),
        ),
      ),
    );
  }
}

class _TierDraft {
  final TextEditingController nameController;
  final TextEditingController minPointsController;

  _TierDraft({String name = '', String minPoints = ''})
      : nameController = TextEditingController(text: name),
        minPointsController = TextEditingController(text: minPoints);

  void dispose() {
    nameController.dispose();
    minPointsController.dispose();
  }
}

class _TiersForm extends ConsumerStatefulWidget {
  final String providerId;
  final List<LoyaltyTier> initial;

  const _TiersForm({required this.providerId, required this.initial});

  @override
  ConsumerState<_TiersForm> createState() => _TiersFormState();
}

class _TiersFormState extends ConsumerState<_TiersForm> {
  late List<_TierDraft> _drafts;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initial.map((t) => _TierDraft(name: t.name, minPoints: '${t.minLifetimePoints}')).toList();
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
          l10n.loyaltyTiersSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: FactorySpacing.space4),
        if (_drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
            child: Text(
              l10n.loyaltyTiersEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
            ),
          )
        else
          for (var i = 0; i < _drafts.length; i++) ...[
            _TierRow(
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
          label: l10n.loyaltyTierAddButton,
          variant: FactoryButtonVariant.secondary,
          icon: Icons.add,
          onPressed: _isSubmitting ? null : () => setState(() => _drafts.add(_TierDraft())),
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
    final tiers = <LoyaltyTier>[];
    for (final d in _drafts) {
      final name = d.nameController.text.trim();
      final minPoints = int.tryParse(d.minPointsController.text.trim());
      if (name.isEmpty || minPoints == null || minPoints < 0) {
        setState(() => _error = l10n.loyaltyTierValidationError);
        return;
      }
      tiers.add(LoyaltyTier(name: name, minLifetimePoints: minPoints));
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).replaceTiers(widget.providerId, tiers);
      if (!mounted) return;
      invalidateLoyaltyTiers(ref, widget.providerId);
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loyaltyTiersSavedMessage)));
    } catch (e) {
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}

class _TierRow extends StatelessWidget {
  final _TierDraft draft;
  final bool enabled;
  final VoidCallback onRemove;

  const _TierRow({required this.draft, required this.enabled, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryCard(
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FactoryTextField(controller: draft.nameController, enabled: enabled, label: l10n.loyaltyTierNameLabel),
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: FactoryTextField(
              controller: draft.minPointsController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              label: l10n.loyaltyTierMinPointsLabel,
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: enabled ? onRemove : null, tooltip: l10n.loyaltyTierRemoveButton),
        ],
      ),
    );
  }
}
