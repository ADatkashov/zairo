import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/schedule_entry.dart';
import '../providers/staff_owner_providers.dart';

/// Wraps an agenda row of a "no-show": tapping offers "The customer did come" — a no-show marked by mistake can be
/// corrected to a normal completion (a completed visit cannot be taken back, its payout and points already exist).
class NoShowCorrection extends ConsumerWidget {
  const NoShowCorrection({super.key, required this.item, required this.onCorrected, required this.child});

  final AgendaItem item;
  final VoidCallback onCorrected;
  final Widget child;

  Future<void> _correct(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: l10n.noShowCorrectionTitle,
      message: l10n.noShowCorrectionMessage,
      actions: [
        Builder(
          builder: (c) => FactoryButton(
            label: l10n.noShowCorrectionKeep,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(c).pop(false),
          ),
        ),
        Builder(
          builder: (c) => FactoryButton(
            label: l10n.noShowCorrectionConfirm,
            onPressed: () => Navigator.of(c).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(staffOwnerApiProvider).markAttended(item.providerId, item.entry.bookingId);
      onCorrected();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noShowCorrectionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(onTap: () => _correct(context, ref), child: child);
  }
}
