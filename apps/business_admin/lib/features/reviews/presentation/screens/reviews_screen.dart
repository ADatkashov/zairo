import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/provider_review.dart';
import '../providers/reviews_providers.dart';
import '../widgets/review_reply_dialog.dart';

/// The owner-facing reviews list -- paginated exactly like
/// [LoyaltyCustomersScreen] (accumulate pages locally, "load more" when
/// there's another). Reviews already have a rating + comment; replying is
/// the one action available here, per backend/reviews' own scope (no
/// deleting or hiding a review -- only the platform can moderate content,
/// same boundary Business Admin respects everywhere else).
class ReviewsScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;

  const ReviewsScreen({super.key, required this.providerId, required this.providerName});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int _page = 0;
  final List<ProviderReview> _items = [];
  final Set<int> _loadedPages = {};
  int _totalPages = 1;

  void _resetPaging() {
    _page = 0;
    _items.clear();
    _loadedPages.clear();
    _totalPages = 1;
  }

  Future<void> _reply(ProviderReview review) async {
    final result = await showReviewReplyDialog(
      context,
      reviewId: review.id,
      existingReply: review.businessReply,
    );
    if (result == null) return;
    setState(() {
      final index = _items.indexWhere((r) => r.id == review.id);
      if (index != -1) {
        _items[index] = review.copyWithReply(businessReply: result.reply, businessReplyAt: result.repliedAt);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (widget.providerId, _page);
    final pageAsync = ref.watch(providerReviewsProvider(key));

    ref.listen(providerReviewsProvider(key), (previous, next) {
      next.whenData((resp) {
        if (_loadedPages.add(resp.number)) {
          setState(() {
            _items.addAll(resp.content);
            _totalPages = resp.totalPages;
          });
        }
      });
    });

    final awaitingReply = _items.where((r) => !r.hasReply).length;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.reviewsScreenTitle(widget.providerName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(providerReviewsProvider);
          setState(_resetPaging);
        },
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space4),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        value: _averageRating(_items).toStringAsFixed(1),
                        label: l10n.reviewsAverageRatingLabel,
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: _StatTile(value: '${_items.length}', label: l10n.reviewsTotalCountLabel),
                    ),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: _StatTile(
                        value: '$awaitingReply',
                        label: l10n.reviewsAwaitingReplyLabel,
                        highlight: awaitingReply > 0,
                      ),
                    ),
                  ],
                ),
              ),
            if (_items.isEmpty)
              pageAsync.when(
                data: (resp) => resp.content.isEmpty
                    ? FactoryEmptyState(
                        icon: Icons.star_outline_rounded,
                        title: l10n.reviewsEmptyTitle,
                        message: l10n.reviewsEmptyMessage,
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                        child: FactoryLoadingState(),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                  child: FactoryLoadingState(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space4),
                  child: FactoryErrorState(
                    message: l10n.errorReviewsLoadFailed(error.toString()),
                    onRetry: () => ref.invalidate(providerReviewsProvider(key)),
                  ),
                ),
              )
            else ...[
              for (final review in _items) ...[
                _ReviewCard(review: review, onReply: () => _reply(review)),
                const SizedBox(height: FactorySpacing.space3),
              ],
              if (_page + 1 < _totalPages)
                Center(
                  child: pageAsync.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(FactorySpacing.space4),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : FactoryButton(
                          label: l10n.reviewsLoadMore,
                          variant: FactoryButtonVariant.secondary,
                          onPressed: () => setState(() => _page += 1),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  double _averageRating(List<ProviderReview> items) =>
      items.isEmpty ? 0 : items.map((r) => r.rating).reduce((a, b) => a + b) / items.length;
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;

  const _StatTile({required this.value, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return FactoryCard(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space3, horizontal: FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(color: highlight ? colors.warning : colors.text),
          ),
          const SizedBox(height: 2),
          Text(label, style: textTheme.labelMedium?.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}

/// Board 15 (v2 design audit) — a review's lifecycle is exactly two real,
/// backend-tracked steps: received ([ProviderReview.createdAt], always
/// true) and replied ([ProviderReview.hasReply]/[businessReplyAt]). No
/// third "resolved"/"escalated" step exists anywhere in backend/reviews,
/// so this stays a two-step stepper rather than inventing one.
class _ReviewLifecycleStepper extends StatelessWidget {
  final ProviderReview review;

  const _ReviewLifecycleStepper({required this.review});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StepDot(done: true, colors: colors),
            Expanded(
              child: Container(height: 2, color: review.hasReply ? colors.primary : colors.border),
            ),
            _StepDot(done: review.hasReply, colors: colors),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reviewLifecycleReceived,
                style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                review.hasReply
                    ? l10n.reviewLifecycleRepliedOn(
                        DateFormat.yMMMd(locale).format(review.businessReplyAt!.toLocal()),
                      )
                    : l10n.reviewLifecyclePending,
                textAlign: TextAlign.end,
                style: textTheme.labelSmall?.copyWith(
                  color: review.hasReply ? colors.textSecondary : colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool done;
  final FactoryColors colors;

  const _StepDot({required this.done, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? colors.primary : colors.surfaceAlt,
        border: done ? null : Border.all(color: colors.border, width: 1.5),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ProviderReview review;
  final VoidCallback onReply;

  const _ReviewCard({required this.review, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(review.customerName, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              FactoryRatingLabel(rating: review.rating.toDouble()),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat.yMMMd(locale).format(review.createdAt.toLocal()),
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: FactorySpacing.space3),
          _ReviewLifecycleStepper(review: review),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(review.comment!, style: textTheme.bodyMedium),
          ],
          const SizedBox(height: FactorySpacing.space3),
          if (review.hasReply)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FactorySpacing.space3),
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: BorderRadius.circular(FactoryRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reviewOwnerReplyLabel,
                    style: textTheme.labelSmall?.copyWith(color: colors.primaryStrong, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(review.businessReply!, style: textTheme.bodySmall?.copyWith(color: colors.text)),
                  const SizedBox(height: FactorySpacing.space2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: onReply, child: Text(l10n.reviewEditReplyButton)),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(l10n.reviewReplyButton),
            ),
        ],
      ),
    );
  }
}
