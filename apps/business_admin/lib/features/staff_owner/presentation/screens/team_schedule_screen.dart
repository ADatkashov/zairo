import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/worker_schedule.dart';
import '../providers/staff_owner_providers.dart';
import 'worker_schedule_screen.dart';

/// The owner's team schedule: everyone who works at the business, whether they have their own weekly schedule, who is
/// off right now, and the switch that lets customers choose a person (otherwise they book "any master").
class TeamScheduleScreen extends ConsumerWidget {
  const TeamScheduleScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workers = ref.watch(workersProvider(providerId));

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.teamScheduleTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workersProvider(providerId));
          ref.invalidate(workforceSettingsProvider(providerId));
        },
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            _ChoiceSwitch(providerId: providerId),
            const SizedBox(height: FactorySpacing.space4),
            workers.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: FactorySpacing.space4),
                child: LinearProgressIndicator(),
              ),
              error: (error, stackTrace) => FactoryErrorState(
                message: l10n.teamScheduleSaveFailed,
                onRetry: () => ref.invalidate(workersProvider(providerId)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return FactoryEmptyState(
                    icon: Icons.groups_outlined,
                    title: l10n.teamScheduleEmpty,
                    message: '',
                  );
                }
                return Column(
                  children: [
                    for (final worker in list) ...[
                      _WorkerTile(providerId: providerId, worker: worker),
                      const SizedBox(height: FactorySpacing.space2),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSwitch extends ConsumerWidget {
  const _ChoiceSwitch({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(workforceSettingsProvider(providerId)).value;

    return FactorySettingsGroup(
      children: [
        SwitchListTile(
          secondary: const FactoryIconBadge(icon: Icons.person_search_outlined),
          title: Text(l10n.teamScheduleChoiceTitle),
          subtitle: Text(l10n.teamScheduleChoiceSubtitle),
          // Until the current value is known the switch is disabled rather than guessing.
          value: settings?.allowWorkerChoice ?? true,
          onChanged: settings == null
              ? null
              : (value) async {
                  try {
                    await ref.read(staffOwnerApiProvider).updateSettings(
                          providerId,
                          allowWorkerChoice: value,
                          workerPricingEnabled: settings.workerPricingEnabled,
                        );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamScheduleSaveFailed)));
                    }
                  }
                  ref.invalidate(workforceSettingsProvider(providerId));
                },
        ),
        SwitchListTile(
          secondary: const FactoryIconBadge(icon: Icons.sell_outlined),
          title: Text(l10n.teamSchedulePricingTitle),
          subtitle: Text(l10n.teamSchedulePricingSubtitle),
          value: settings?.workerPricingEnabled ?? false,
          onChanged: settings == null
              ? null
              : (value) async {
                  try {
                    await ref.read(staffOwnerApiProvider).updateSettings(
                          providerId,
                          allowWorkerChoice: settings.allowWorkerChoice,
                          workerPricingEnabled: value,
                        );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamScheduleSaveFailed)));
                    }
                  }
                  ref.invalidate(workforceSettingsProvider(providerId));
                },
        ),
      ],
    );
  }
}

String workerKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
      'MASTER' => l10n.workerKindMaster,
      'MECHANIC' => l10n.workerKindMechanic,
      'CLEANER' => l10n.workerKindCleaner,
      _ => l10n.workerKindStaff,
    };

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({required this.providerId, required this.worker});

  final String providerId;
  final WorkerSummary worker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final off = worker.offUntil;

    return FactorySelectableTile(
      leading: FactoryAvatar(
        initials: worker.displayName.isEmpty ? '?' : worker.displayName[0].toUpperCase(),
        image: worker.photoUrl != null ? NetworkImage(worker.photoUrl!) : null,
      ),
      title: worker.displayName,
      titleColor: worker.active ? null : colors.textTertiary,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workerKindLabel(l10n, worker.kind), style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 4),
          _RatingLine(worker: worker),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              FactoryBadge(
                label: worker.scheduleConfigured ? l10n.teamScheduleOwnBadge : l10n.teamScheduleSharedBadge,
                variant: worker.scheduleConfigured ? FactoryBadgeVariant.available : FactoryBadgeVariant.neutral,
              ),
              if (off != null)
                FactoryBadge(
                  label: l10n.teamScheduleOffUntil(formatMonthDayTime(l10n, off.toLocal())),
                  variant: FactoryBadgeVariant.limited,
                ),
            ],
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WorkerScheduleScreen(providerId: providerId, worker: worker)),
      ),
    );
  }
}

/// The person's rating and how far they are from "Best masters" in the customer app (3 reviews needed).
class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.worker});

  final WorkerSummary worker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary);
    final rating = worker.averageRating;
    final missing = WorkerSummary.reviewsToQualify - worker.reviewCount;

    if (rating == null) {
      return Text(l10n.teamRatingNone(WorkerSummary.reviewsToQualify), style: style);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        FactoryRatingLabel(
          rating: rating,
          reviewCount: worker.reviewCount,
          semanticLabel: l10n.teamRatingSemantic(rating.toStringAsFixed(1), worker.reviewCount),
        ),
        Text(missing > 0 ? l10n.teamRatingMissing(missing) : l10n.teamRatingQualified, style: style),
      ],
    );
  }
}
