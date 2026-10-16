import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/reviews_exception.dart';
import '../providers/reviews_providers.dart';

/// Asks why a review should be looked at and reports it to the platform. Returns true once the report went through,
/// null if the owner cancelled -- the caller then marks its row as waiting for the platform.
Future<bool?> showReviewReportDialog(BuildContext context, {required String reviewId}) {
  return showDialog<bool>(context: context, builder: (_) => _ReviewReportDialog(reviewId: reviewId));
}

class _ReviewReportDialog extends ConsumerStatefulWidget {
  final String reviewId;

  const _ReviewReportDialog({required this.reviewId});

  @override
  ConsumerState<_ReviewReportDialog> createState() => _ReviewReportDialogState();
}

class _ReviewReportDialogState extends ConsumerState<_ReviewReportDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = l10n.reviewReportEmptyError);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(reviewsApiProvider).reportReview(widget.reviewId, reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ReviewsException ? e.localizedMessage(l10n) : l10n.errorReviewsActionFailed;
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: l10n.reviewReportDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reviewReportDialogMessage),
          const SizedBox(height: FactorySpacing.space3),
          FactoryTextField(controller: _reasonController, label: l10n.reviewReportFieldLabel, maxLines: 3),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.reviewReportSubmitButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }
}
