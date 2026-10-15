import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workers/presentation/providers/workers_providers.dart';
import '../../data/review_exception.dart';
import '../providers/reviews_providers.dart';

/// Shown on a completed booking: the existing review if there is one,
/// otherwise a button to leave one. Bookings that aren't COMPLETED don't
/// get this section at all — the backend rejects a review before then
/// anyway (see reviews module's package-info: "no review without a
/// verified visit").
class ReviewSection extends ConsumerWidget {
  final String bookingId;

  const ReviewSection({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reviewAsync = ref.watch(reviewForBookingProvider(bookingId));
    final colors = context.factoryColors;

    return reviewAsync.when(
      data: (review) {
        if (review == null) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FactoryButton(
              icon: Symbols.star_rounded,
              label: l10n.reviewLeaveButton,
              variant: FactoryButtonVariant.text,
              onPressed: () => _openLeaveReviewDialog(context, ref),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: FactorySpacing.space2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Symbols.star_rounded,
                    fill: i < review.rating ? 1 : 0,
                    size: 18,
                    color: colors.accent,
                  ),
                ),
              ),
              if (review.comment != null && review.comment!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    review.comment!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stackTrace) => Text(l10n.errorReviewLoadFailed),
    );
  }

  Future<void> _openLeaveReviewDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveReviewDialog(bookingId: bookingId),
    );
    if (submitted == true) {
      ref.invalidate(reviewForBookingProvider(bookingId));
    }
  }
}

class _LeaveReviewDialog extends ConsumerStatefulWidget {
  final String bookingId;

  const _LeaveReviewDialog({required this.bookingId});

  @override
  ConsumerState<_LeaveReviewDialog> createState() => _LeaveReviewDialogState();
}

class _LeaveReviewDialogState extends ConsumerState<_LeaveReviewDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    // Best-effort: with no named person (or no answer) the prompt just doesn't name anyone.
    final worker = ref.watch(bookingWorkerProvider(widget.bookingId)).value;
    return FactoryDialog(
      title: l10n.reviewLeaveButton,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (worker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                child: Row(
                  children: [
                    FactoryAvatar(
                      initials: initialsFor(worker.displayName),
                      size: 36,
                      image: worker.photoUrl != null ? NetworkImage(worker.photoUrl!) : null,
                    ),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: Text(
                        l10n.reviewAboutWorker(worker.displayName),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              children: List.generate(
                5,
                (i) => IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _rating = i + 1),
                  tooltip: l10n.starRatingSemanticLabel(i + 1),
                  icon: Icon(
                    Symbols.star_rounded,
                    fill: i < _rating ? 1 : 0,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
            FactoryTextField(
              controller: _commentController,
              enabled: !_isSubmitting,
              label: l10n.reviewCommentHint,
              maxLines: 3,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.reviewCancel,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(
          label: l10n.reviewSubmit,
          isLoading: _isSubmitting,
          onPressed: (_rating > 0 && !_isSubmitting) ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final comment = _commentController.text.trim();
      await ref
          .read(reviewsApiProvider)
          .createReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewException catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = e.localizedMessage(l10n);
        _isSubmitting = false;
      });
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = l10n.errorReviewSubmitFailed;
        _isSubmitting = false;
      });
    }
  }
}
