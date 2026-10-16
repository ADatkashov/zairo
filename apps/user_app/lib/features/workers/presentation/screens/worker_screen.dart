import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatting/initials.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../beauty/presentation/providers/beauty_providers.dart';
import '../../../workforce/presentation/providers/workforce_providers.dart';
import '../../data/models/worker_profile.dart';
import '../widgets/favorite_worker_button.dart';
import '../providers/workers_providers.dart';

/// A master's public page, opened from Home's "Best masters" rail: who they
/// are, how they are rated, what they do and what it costs — with the way to
/// book one tap away. Booking itself is the business's flow (services, then
/// times), so the button opens the business already at its booking steps.
class WorkerScreen extends ConsumerWidget {
  const WorkerScreen({super.key, required this.workerId});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(workerProfileProvider(workerId));

    return Scaffold(
      appBar: FactoryAppBar(
        title: l10n.workerPageTitle,
        actions: [FavoriteWorkerButton(workerId: workerId)],
      ),
      body: profileAsync.when(
        data: (profile) => _WorkerBody(profile: profile),
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorWorkerLoadFailed,
              onRetry: () => ref.invalidate(workerProfileProvider(workerId)),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many of a worker's next free times the page shows.
const _maxSoonestTimes = 6;

/// "Today 14:00", "Tomorrow 10:00", or "Oct 21, 14:00" further out.
String _slotLabel(AppLocalizations l10n, String locale, DateTime now, DateTime start) {
  final time = DateFormat.Hm(locale).format(start);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final days = day.difference(today).inDays;
  if (days == 0) return l10n.workerSlotToday(time);
  if (days == 1) return l10n.workerSlotTomorrow(time);
  return DateFormat.MMMd(locale).add_Hm().format(start);
}

class _WorkerBody extends ConsumerWidget {
  const _WorkerBody({required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final rating = profile.averageRating;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Their next free times, so booking is one tap from here. Best-effort: no chips while loading, empty or failed.
    final now = DateTime.now();
    final soonest = (ref.watch(workerSlotsProvider((profile.providerId, profile.id))).value ?? const [])
        .where((slot) => slot.isOpen && slot.startsAt.isAfter(now))
        .take(_maxSoonestTimes)
        .toList();
    // Only a master has a photo portfolio; best-effort, no strip while loading, empty or failed.
    final work = profile.hasPortfolio ? ref.watch(masterPortfolioProvider(profile.id)).value ?? const [] : const [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              Center(
                child: FactoryAvatar(
                  initials: initialsFor(profile.displayName),
                  size: 96,
                  image: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                ),
              ),
              const SizedBox(height: FactorySpacing.space3),
              Text(profile.displayName, textAlign: TextAlign.center, style: textTheme.titleLarge),
              const SizedBox(height: FactorySpacing.space2),
              Center(
                child: rating == null
                    ? Text(l10n.workerNoReviews, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary))
                    : FactoryRatingLabel(
                        rating: rating,
                        reviewCount: profile.reviewCount,
                        iconSize: 16,
                        semanticLabel: l10n.ratingSemanticLabelWithReviews(
                          rating.toStringAsFixed(1),
                          profile.reviewCount,
                        ),
                      ),
              ),
              const SizedBox(height: FactorySpacing.space4),
              FactoryCard(
                onTap: () => context.push(AppRoutes.provider(profile.providerId)),
                child: Row(
                  children: [
                    Icon(Symbols.storefront_rounded, color: colors.textSecondary),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.workerBusinessLabel,
                            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                          ),
                          Text(profile.providerName, style: textTheme.titleSmall),
                        ],
                      ),
                    ),
                    Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
                  ],
                ),
              ),
              if (soonest.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.space5),
                Text(l10n.workerSoonestTitle, style: textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space3),
                Wrap(
                  spacing: FactorySpacing.space2,
                  runSpacing: FactorySpacing.space2,
                  children: [
                    for (final slot in soonest)
                      FactoryTimeSlot(
                        label: _slotLabel(l10n, locale, now, slot.startsAt.toLocal()),
                        onTap: () => context.push(
                          AppRoutes.provider(
                            profile.providerId,
                            book: true,
                            workerId: profile.id,
                            workerKind: profile.kind,
                            slotId: slot.id,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (profile.bio != null) ...[
                const SizedBox(height: FactorySpacing.space5),
                Text(l10n.workerAboutTitle, style: textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space2),
                Text(profile.bio!, style: textTheme.bodyMedium),
              ],
              const SizedBox(height: FactorySpacing.space5),
              Text(l10n.workerServicesTitle, style: textTheme.titleSmall),
              const SizedBox(height: FactorySpacing.space3),
              if (profile.services.isEmpty)
                Text(l10n.workerServicesEmpty, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary))
              else
                for (final service in profile.services)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                    child: FactoryCard(
                      // One tap from the service you want to booking it with this person.
                      onTap: () => context.push(
                        AppRoutes.provider(
                          profile.providerId,
                          book: true,
                          workerId: profile.id,
                          workerKind: profile.kind,
                          serviceId: service.id,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(service.title, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  l10n.serviceDurationMinutes(service.durationMinutes),
                                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          FactoryPriceText(amount: service.price, currencySymbol: service.currency),
                        ],
                      ),
                    ),
                  ),
              if (work.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.space5),
                Text(l10n.workerWorkTitle, style: textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space3),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: work.length,
                    separatorBuilder: (_, _) => const SizedBox(width: FactorySpacing.space2),
                    itemBuilder: (context, index) => InkWell(
                      borderRadius: FactoryRadius.mdRadius,
                      onTap: () => context.push(AppRoutes.portfolio(profile.id, masterName: profile.displayName)),
                      child: ClipRRect(
                        borderRadius: FactoryRadius.mdRadius,
                        child: Image.network(
                          work[index].imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(width: 96, height: 96, color: colors.surfaceAlt),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (profile.reviews.isNotEmpty) ...[
                const SizedBox(height: FactorySpacing.space5),
                Text(l10n.reviewsTitle, style: textTheme.titleSmall),
                const SizedBox(height: FactorySpacing.space3),
                for (final review in profile.reviews)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                    child: FactoryCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              FactoryRatingLabel(
                                rating: review.rating.toDouble(),
                                semanticLabel: l10n.ratingSemanticLabel(review.rating.toString()),
                              ),
                              const Spacer(),
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
                              l10n.reviewsBusinessReply,
                              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w700),
                            ),
                            Text(review.businessReply!, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        // The two things a person comes here to do stay on screen, not at the
        // bottom of the list.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: Row(
              children: [
                if (profile.hasPortfolio) ...[
                  Expanded(
                    child: FactoryButton(
                      label: l10n.workerPortfolioAction,
                      icon: Symbols.photo_library_rounded,
                      variant: FactoryButtonVariant.secondary,
                      onPressed: () => context.push(
                        AppRoutes.portfolio(profile.id, masterName: profile.displayName),
                      ),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                ],
                Expanded(
                  child: FactoryButton(
                    label: l10n.workerBookAction,
                    onPressed: () => context.push(
                      AppRoutes.provider(profile.providerId, book: true, workerId: profile.id, workerKind: profile.kind),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
