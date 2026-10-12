import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/public_review.dart';
import '../providers/reviews_providers.dart';
import '../screens/reviews_screen.dart';

/// How many reviews the business page shows before "All reviews".
const int reviewsPreviewCount = 3;

/// The reviews block on a business's page: average, count and the latest few
/// reviews, then a way to the full screen. Renders nothing while loading, on
/// a load error, or when the business has no reviews yet -- this sits under
/// the booking steps, so it must never push an error or an empty box into a
/// screen whose job is to book.
class ReviewsPreview extends ConsumerWidget {
  const ReviewsPreview({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reviewSummaryProvider(providerId)).asData?.value;
    final page = ref
        .watch(
          publicReviewsProvider((
            providerId: providerId,
            size: reviewsPreviewCount,
            rating: null,
            withCommentOnly: false,
            sort: ReviewSort.newest,
          )),
        )
        .asData
        ?.value;
    if (summary == null || summary.total == 0 || page == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    final average = summary.average ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FactorySpacing.space6),
        Text(l10n.reviewsTitle, style: textTheme.titleMedium),
        const SizedBox(height: FactorySpacing.space2),
        Row(
          children: [
            Text(
              average.toStringAsFixed(1),
              style: FactoryTypography.mono(
                size: 28,
                weight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(width: FactorySpacing.space2),
            Stars(rating: average.round(), size: 16),
            const SizedBox(width: FactorySpacing.space2),
            Flexible(
              child: Text(
                l10n.reviewsBasedOn(summary.total),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: FactorySpacing.space3),
        for (final review in page.reviews) ...[
          ReviewCard(review: review),
          const SizedBox(height: FactorySpacing.space3),
        ],
        FactoryButton(
          label: l10n.reviewsSeeAll,
          variant: FactoryButtonVariant.secondary,
          expand: true,
          onPressed: () => context.push(
            AppRoutes.reviews(providerId, providerName: providerName),
          ),
        ),
      ],
    );
  }
}
