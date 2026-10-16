import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/worker_schedule.dart';
import '../providers/staff_owner_providers.dart';

/// One person's rating for the owner: the average, how many stars were given how often, and the newest reviews with
/// who wrote them. Opened from the team list.
class WorkerRatingScreen extends ConsumerWidget {
  const WorkerRatingScreen({super.key, required this.providerId, required this.worker});

  final String providerId;
  final WorkerSummary worker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final key = (providerId, worker.id);
    final rating = ref.watch(workerRatingProvider(key));

    return Scaffold(
      appBar: FactoryAppBar(title: worker.displayName),
      body: rating.when(
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.teamScheduleSaveFailed,
              onRetry: () => ref.invalidate(workerRatingProvider(key)),
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(workerRatingProvider(key).future),
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Summary(rating: data),
              const SizedBox(height: FactorySpacing.space5),
              if (data.reviews.isEmpty)
                FactoryEmptyState(
                  icon: Icons.star_outline_rounded,
                  title: l10n.reviewsEmptyTitle,
                  message: l10n.reviewsEmptyMessage,
                )
              else ...[
                Text(l10n.workerRatingLatestTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space3),
                for (final review in data.reviews) ...[
                  _ReviewCard(review: review),
                  const SizedBox(height: FactorySpacing.space2),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rating});

  final WorkerRating rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final average = rating.averageRating;
    final maxCount = rating.distribution.fold<int>(0, (m, n) => n > m ? n : m);
    final missing = WorkerSummary.reviewsToQualify - rating.reviewCount;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (average == null)
            Text(l10n.teamRatingNone(WorkerSummary.reviewsToQualify), style: textTheme.bodyMedium)
          else ...[
            Row(
              children: [
                Text(average.toStringAsFixed(1), style: textTheme.headlineMedium),
                const SizedBox(width: FactorySpacing.space2),
                Icon(Icons.star_rounded, color: colors.accent),
                const SizedBox(width: FactorySpacing.space2),
                Text('(${rating.reviewCount})', style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
              ],
            ),
            const SizedBox(height: FactorySpacing.space1),
            Text(
              missing > 0 ? l10n.teamRatingMissing(missing) : l10n.teamRatingQualified,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: FactorySpacing.space3),
            for (var stars = 5; stars >= 1; stars--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(width: 14, child: Text('$stars', style: textTheme.bodySmall)),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, size: 14, color: colors.accent),
                    const SizedBox(width: FactorySpacing.space2),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: maxCount == 0 ? 0 : rating.distribution[stars - 1] / maxCount,
                          backgroundColor: colors.surfaceAlt,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space2),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${rating.distribution[stars - 1]}',
                        textAlign: TextAlign.end,
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final WorkerReviewItem review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FactoryRatingLabel(
                rating: review.rating.toDouble(),
                semanticLabel: l10n.teamRatingSemantic(review.rating.toString(), 1),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(
                child: Text(
                  review.customerName ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
              Text(
                DateFormat.yMMMd(locale).format(review.createdAt.toLocal()),
                style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(review.comment!, style: textTheme.bodyMedium),
          ],
          if (review.businessReply != null) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(
              l10n.workerRatingBusinessReply,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w700),
            ),
            Text(review.businessReply!, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
