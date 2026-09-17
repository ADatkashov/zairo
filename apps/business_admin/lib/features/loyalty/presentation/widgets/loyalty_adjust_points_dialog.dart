import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../providers/loyalty_admin_providers.dart';

/// A manual points correction is sensitive and auditable (backend records
/// it as an ADJUSTMENT ledger entry naming the acting owner) -- this dialog
/// enforces exactly what the backend requires (a non-zero delta, a
/// non-blank, owner-typed reason -- never a default/placeholder) and adds a
/// second confirm step before the write actually happens, rather than
/// submitting the moment the form validates.
///
/// Returns `true` via Navigator.pop once the adjustment succeeded; the
/// caller invalidates [invalidateLoyaltyCustomerData] in response.
Future<bool?> showLoyaltyAdjustPointsDialog(
  BuildContext context, {
  required String providerId,
  required String userId,
  required int currentBalance,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AdjustPointsDialog(providerId: providerId, userId: userId, currentBalance: currentBalance),
  );
}

class _AdjustPointsDialog extends ConsumerStatefulWidget {
  final String providerId;
  final String userId;
  final int currentBalance;

  const _AdjustPointsDialog({required this.providerId, required this.userId, required this.currentBalance});

  @override
  ConsumerState<_AdjustPointsDialog> createState() => _AdjustPointsDialogState();
}

class _AdjustPointsDialogState extends ConsumerState<_AdjustPointsDialog> {
  final _deltaController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _confirming = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _deltaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int? get _delta => int.tryParse(_deltaController.text.trim());
  String get _reason => _reasonController.text.trim();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: _confirming ? l10n.loyaltyAdjustPointsConfirmTitle : l10n.loyaltyAdjustPointsDialogTitle,
      content: _confirming ? _buildConfirmContent(l10n) : _buildFormContent(l10n),
      actions: _confirming ? _confirmActions(l10n) : _formActions(l10n),
    );
  }

  Widget _buildFormContent(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.loyaltyAdjustPointsCurrentBalanceLabel(widget.currentBalance),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textTertiary),
        ),
        const SizedBox(height: FactorySpacing.space3),
        FactoryTextField(
          controller: _deltaController,
          label: l10n.loyaltyAdjustPointsDeltaLabel,
          hint: l10n.loyaltyAdjustPointsDeltaHint,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
        ),
        const SizedBox(height: FactorySpacing.space3),
        FactoryTextField(
          controller: _reasonController,
          label: l10n.loyaltyAdjustPointsReasonLabel,
          hint: l10n.loyaltyAdjustPointsReasonHint,
          maxLines: 3,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space2),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }

  Widget _buildConfirmContent(AppLocalizations l10n) {
    final delta = _delta!;
    final projected = widget.currentBalance + delta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          delta > 0
              ? l10n.loyaltyAdjustPointsConfirmCredit(delta)
              : l10n.loyaltyAdjustPointsConfirmDebit(delta.abs()),
        ),
        const SizedBox(height: FactorySpacing.space2),
        Text(
          l10n.loyaltyAdjustPointsConfirmProjectedBalance(projected),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: FactorySpacing.space2),
        Text(
          '${l10n.loyaltyAdjustPointsReasonLabel}: $_reason',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.factoryColors.textSecondary),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space2),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }

  List<Widget> _formActions(AppLocalizations l10n) => [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FactoryButton(
          label: l10n.loyaltyAdjustPointsContinueButton,
          onPressed: _validateAndContinue,
        ),
      ];

  List<Widget> _confirmActions(AppLocalizations l10n) => [
        FactoryButton(
          label: l10n.loyaltyAdjustPointsBackButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => setState(() => _confirming = false),
        ),
        FactoryButton(
          label: l10n.loyaltyAdjustPointsConfirmButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ];

  void _validateAndContinue() {
    final l10n = AppLocalizations.of(context)!;
    final delta = _delta;
    if (delta == null || delta == 0) {
      setState(() => _error = l10n.loyaltyAdjustPointsDeltaError);
      return;
    }
    if (_reason.isEmpty) {
      setState(() => _error = l10n.loyaltyAdjustPointsReasonError);
      return;
    }
    setState(() {
      _error = null;
      _confirming = true;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).adjustPoints(
            widget.providerId,
            widget.userId,
            delta: _delta!,
            reason: _reason,
          );
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
