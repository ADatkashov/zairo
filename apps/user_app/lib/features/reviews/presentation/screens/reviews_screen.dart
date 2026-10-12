import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/public_review.dart';
import '../providers/reviews_providers.dart';

const int _pageSize = 20;

/// Everything customers said about one business: the average with a star
/// breakdown, then the reviews newest first, each with the business's reply
/// when it wrote one. Reviews only exist after a completed visit (backend
/// rule), so this is never a place for unverified opinions.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key, required this.providerId, this.providerName});

  final String providerId;
  final String? providerName;

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  int _size = _pageSize;
  int? _rating;
  bool _withCommentOnly = false;
  ReviewSort _sort = ReviewSort.newest;

  bool get _filtered => _rating != null || _withCommentOnly;

  PublicReviewsKey get _key => (
    providerId: widget.providerId,
    size: _size,
    rating: _rating,
    withCommentOnly: _withCommentOnly,
    sort: _sort,
  );

  /// Any change of filter or order starts again from the first page.
  void _change(VoidCallback update) => setState(() {
    update();
    _size = _pageSize;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final summaryAsync = ref.watch(reviewSummaryProvider(widget.providerId));
    final pageAsync = ref.watch(publicReviewsProvider(_key));

    Future<void> refresh() async {
      ref.invalidate(reviewSummaryProvider(widget.providerId));
      ref.invalidate(publicReviewsProvider(_key));
      await ref.read(reviewSummaryProvider(widget.providerId).future);
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: widget.providerName ?? l10n.reviewsTitle),
      body: summaryAsync.when(
        loading: () => const FactoryLoadingState(),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.reviewsError,
              onRetry: refresh,
            ),
          ),
        ),
        data: (summary) {
          if (summary.total == 0) {
            return Center(
              child: FactoryEmptyState(
                icon: Symbols.reviews_rounded,
                title: l10n.reviewsEmptyTitle,
                message: l10n.reviewsEmptyMessage,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              children: [
                ReviewSummaryCard(summary: summary),
                const SizedBox(height: FactorySpacing.space4),
                _FilterBar(
                  rating: _rating,
                  withCommentOnly: _withCommentOnly,
                  sort: _sort,
                  onRating: (v) => _change(() => _rating = v),
                  onWithComment: (v) => _change(() => _withCommentOnly = v),
                  onSort: (v) => _change(() => _sort = v),
                ),
                const SizedBox(height: FactorySpacing.space3),
                ...pageAsync.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.all(FactorySpacing.space6),
                      child: FactoryLoadingState(),
                    ),
                  ],
                  error: (_, _) => [
                    FactoryErrorState(
                      message: l10n.reviewsError,
                      onRetry: refresh,
                    ),
                  ],
                  data: (page) => [
                    if (page.reviews.isEmpty)
                      FactoryEmptyState(
                        compact: true,
                        icon: Symbols.filter_alt_off_rounded,
                        title: l10n.reviewsNoMatchTitle,
                        message: l10n.reviewsNoMatchMessage,
                        actionLabel: _filtered
                            ? l10n.reviewsResetFilters
                            : null,
                        onAction: _filtered
                            ? () => _change(() {
                                _rating = null;
                                _withCommentOnly = false;
                              })
                            : null,
                      ),
                    for (final review in page.reviews) ...[
                      ReviewCard(review: review),
                      const SizedBox(height: FactorySpacing.space3),
                    ],
                    if (page.hasMore)
                      FactoryButton(
                        label: l10n.reviewsShowMore,
                        variant: FactoryButtonVariant.tonal,
                        onPressed: () => setState(() => _size += _pageSize),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Two rows of chips: what to show (all / a star count / only with text) and
/// the order (newest / highest / lowest). Both scroll sideways on a narrow
/// phone instead of wrapping into a tall block above the list.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.rating,
    required this.withCommentOnly,
    required this.sort,
    required this.onRating,
    required this.onWithComment,
    required this.onSort,
  });

  final int? rating;
  final bool withCommentOnly;
  final ReviewSort sort;
  final ValueChanged<int?> onRating;
  final ValueChanged<bool> onWithComment;
  final ValueChanged<ReviewSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sortLabels = {
      ReviewSort.newest: l10n.reviewsSortNewest,
      ReviewSort.highest: l10n.reviewsSortHighest,
      ReviewSort.lowest: l10n.reviewsSortLowest,
    };

    Widget row(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[chip, const SizedBox(width: 8)],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row([
          FactoryChip(
            label: l10n.reviewsFilterAll,
            selected: rating == null && !withCommentOnly,
            onTap: () {
              onRating(null);
              onWithComment(false);
            },
          ),
          for (var stars = 5; stars >= 1; stars--)
            FactoryChip(
              label: '$stars',
              icon: Symbols.star_rounded,
              selected: rating == stars,
              onTap: () => onRating(rating == stars ? null : stars),
            ),
          FactoryChip(
            label: l10n.reviewsFilterWithText,
            selected: withCommentOnly,
            onTap: () => onWithComment(!withCommentOnly),
          ),
        ]),
        const SizedBox(height: 8),
        row([
          for (final entry in sortLabels.entries)
            FactoryChip(
              label: entry.value,
              selected: sort == entry.key,
              onTap: () => onSort(entry.key),
            ),
        ]),
      ],
    );
  }
}

/// "4.8 ★★★★★ — based on 128 reviews" plus one bar per star, 5 down to 1.
class ReviewSummaryCard extends StatelessWidget {
  const ReviewSummaryCard({super.key, required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final average = summary.average ?? 0;

    return FactoryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    average.toStringAsFixed(1),
                    style: FactoryTypography.mono(
                      size: 40,
                      weight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Stars(rating: average.round(), size: 16),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  l10n.reviewsBasedOn(summary.total),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(width: FactorySpacing.space4),
          Expanded(
            child: Column(
              children: [
                for (var stars = 5; stars >= 1; stars--)
                  _DistributionBar(
                    stars: stars,
                    count: summary.distribution[stars - 1],
                    total: summary.total,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Semantics(
      label: l10n.reviewsStarRowSemantic(stars, count),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              child: Text(
                '$stars',
                style: FactoryTypography.mono(
                  size: 12,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Icon(Symbols.star_rounded, size: 12, fill: 1, color: colors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : count / total,
                  minHeight: 6,
                  backgroundColor: colors.surfaceAlt,
                  color: colors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.end,
                style: FactoryTypography.mono(
                  size: 12,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five stars, [rating] of them filled. Decorative: callers label the whole
/// row themselves.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              Symbols.star_rounded,
              size: size,
              fill: i <= rating ? 1 : 0,
              color: i <= rating ? colors.accent : colors.borderStrong,
            ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final PublicReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final comment = review.comment?.trim();

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FactoryAvatar(initials: initialsFor(review.authorName), size: 36),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: textTheme.titleSmall),
                    Text(
                      DateFormat.yMMMd(locale)
                          .format(review.createdAt.toLocal()),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: l10n.ratingSemanticLabel(review.rating.toString()),
                excludeSemantics: true,
                child: Stars(rating: review.rating),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space3),
            Text(comment, style: textTheme.bodyMedium),
          ],
          if (review.businessReply != null &&
              review.businessReply!.trim().isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FactorySpacing.space3),
              decoration: BoxDecoration(
                color: colors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.reply_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.reviewsBusinessReply,
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.businessReply!.trim(),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
