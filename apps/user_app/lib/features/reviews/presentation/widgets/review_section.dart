import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final reviewAsync = ref.watch(reviewForBookingProvider(bookingId));
    final colors = context.factoryColors;

    return reviewAsync.when(
      data: (review) {
        if (review == null) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openLeaveReviewDialog(context, ref),
              icon: const Icon(Icons.star_outline),
              label: const Text('Leave a review'),
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
                    i < review.rating ? Icons.star : Icons.star_border,
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
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
      error: (error, stackTrace) => Text('Could not load review: $error'),
    );
  }

  Future<void> _openLeaveReviewDialog(BuildContext context, WidgetRef ref) async {
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
    final colors = context.factoryColors;
    return AlertDialog(
      title: const Text('Leave a review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: _isSubmitting ? null : () => setState(() => _rating = i + 1),
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: colors.accent,
                ),
              ),
            ),
          ),
          TextField(
            controller: _commentController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(hintText: 'Comment (optional)'),
            maxLines: 3,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_rating > 0 && !_isSubmitting) ? _submit : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
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
      await ref.read(reviewsApiProvider).createReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewException catch (e) {
      setState(() {
        _error = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to submit review: $e';
        _isSubmitting = false;
      });
    }
  }
}
