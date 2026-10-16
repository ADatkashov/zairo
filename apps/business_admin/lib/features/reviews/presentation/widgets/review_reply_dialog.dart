import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/reviews_exception.dart';
import '../providers/reviews_providers.dart';

/// Returns the saved `(reply, repliedAt)` via Navigator.pop once the reply
/// succeeded, or null if the owner cancelled -- the caller patches its local
/// row with [ProviderReview.copyWithReply] rather than re-fetching the page.
Future<({String reply, DateTime repliedAt})?> showReviewReplyDialog(
  BuildContext context, {
  required String reviewId,
  String? existingReply,
}) {
  return showDialog<({String reply, DateTime repliedAt})>(
    context: context,
    builder: (_) => _ReviewReplyDialog(reviewId: reviewId, existingReply: existingReply),
  );
}

class _ReviewReplyDialog extends ConsumerStatefulWidget {
  final String reviewId;
  final String? existingReply;

  const _ReviewReplyDialog({required this.reviewId, this.existingReply});

  @override
  ConsumerState<_ReviewReplyDialog> createState() => _ReviewReplyDialogState();
}

class _ReviewReplyDialogState extends ConsumerState<_ReviewReplyDialog> {
  late final _replyController = TextEditingController(text: widget.existingReply);
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: widget.existingReply == null ? l10n.reviewReplyDialogTitle : l10n.reviewEditReplyDialogTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Most answers are the same few sentences: one tap puts one in the field, ready to edit.
          if (widget.existingReply == null) ...[
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space1,
              children: [
                for (final template in [l10n.reviewReplyQuickThanks, l10n.reviewReplyQuickWelcome, l10n.reviewReplyQuickSorry])
                  ActionChip(
                    label: Text(template, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onPressed: () => setState(() {
                      _replyController.text = template;
                      _replyController.selection = TextSelection.collapsed(offset: template.length);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: FactorySpacing.space3),
          ],
          FactoryTextField(
            controller: _replyController,
            label: l10n.reviewReplyFieldLabel,
            hint: l10n.reviewReplyFieldHint,
            maxLines: 4,
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.reviewReplySubmitButton,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final reply = _replyController.text.trim();
    if (reply.isEmpty) {
      setState(() => _error = l10n.reviewReplyEmptyError);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(reviewsApiProvider).replyToReview(widget.reviewId, reply);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      setState(() {
        _error = e is ReviewsException ? e.localizedMessage(l10n) : l10n.errorReviewsActionFailed;
        _isSubmitting = false;
      });
    }
  }
}
