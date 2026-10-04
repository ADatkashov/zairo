import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/loyalty_admin_exception.dart';
import '../providers/loyalty_admin_providers.dart';

/// Largest gift a single greeting may carry -- mirrors the backend's
/// LoyaltyGreetingService.MAX_BONUS_POINTS, which is what actually enforces it.
const loyaltyGreetingMaxPoints = 1000;

/// The owner's "greet by hand" action: an optional personal text and an
/// optional gift of points. Both fields may stay empty -- an empty text sends
/// the default greeting. Returns `true` via Navigator.pop once it was sent.
Future<bool?> showLoyaltyGreetingDialog(
  BuildContext context, {
  required String providerId,
  required String userId,
  required String? displayName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _GreetingDialog(providerId: providerId, userId: userId, displayName: displayName),
  );
}

class _GreetingDialog extends ConsumerStatefulWidget {
  final String providerId;
  final String userId;
  final String? displayName;

  const _GreetingDialog({required this.providerId, required this.userId, required this.displayName});

  @override
  ConsumerState<_GreetingDialog> createState() => _GreetingDialogState();
}

class _GreetingDialogState extends ConsumerState<_GreetingDialog> {
  final _messageController = TextEditingController();
  final _pointsController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.loyaltyGreetingDialogTitle(widget.displayName ?? '—'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FactoryTextField(
            controller: _messageController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyGreetingMessageLabel,
            hint: l10n.loyaltyGreetingMessageHint,
            maxLines: 4,
          ),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(
            controller: _pointsController,
            enabled: !_isSubmitting,
            label: l10n.loyaltyGreetingPointsLabel,
            hint: l10n.loyaltyGreetingPointsHint(loyaltyGreetingMaxPoints),
            keyboardType: TextInputType.number,
          ),
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
          label: l10n.loyaltyGreetingSendButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final pointsText = _pointsController.text.trim();
    final points = pointsText.isEmpty ? 0 : int.tryParse(pointsText);
    if (points == null || points < 0 || points > loyaltyGreetingMaxPoints) {
      setState(() => _error = l10n.loyaltyGreetingPointsError(loyaltyGreetingMaxPoints));
      return;
    }
    final message = _messageController.text.trim();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyAdminApiProvider).sendGreeting(
            widget.providerId,
            widget.userId,
            message: message.isEmpty ? null : message,
            bonusPoints: points == 0 ? null : points,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is LoyaltyAdminException ? e.localizedMessage(l10n) : l10n.errorLoyaltyActionFailed(e.toString());
        _isSubmitting = false;
      });
    }
  }
}
