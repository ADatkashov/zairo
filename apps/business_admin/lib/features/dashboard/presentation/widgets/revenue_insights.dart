import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/revenue_pulse.dart';

/// Initials for an avatar: first letters of the first two words, or the first
/// two letters of a single word; "?" for nothing.
String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// The two "who pays me" cards: the split of the last 30 days by service, and the
/// biggest customers. Side by side where there is room (a tablet, the desktop
/// sidebar layout), stacked on a phone; either one alone takes the full width,
/// and with neither — loading, error, no earnings yet — nothing is drawn.
class RevenueInsights extends ConsumerWidget {
  const RevenueInsights({super.key, required this.ownerUserId});

  final String ownerUserId;

  /// Two cards sit side by side from this width; below it they stack.
  static const double sideBySideFrom = 640;

  /// Below this inner width the ring's legend goes under the ring instead of
  /// beside it.
  static const double legendBesideFrom = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(ownerRevenuePulseProvider(ownerUserId)).value;
    final ranking = ref.watch(ownerTopCustomersProvider(ownerUserId)).value;

    final showMix = pulse != null && pulse.services.isNotEmpty;
    final showCustomers = ranking != null && !ranking.isEmpty;
    if (!showMix && !showCustomers) return const SizedBox.shrink();

    // One LayoutBuilder for both cards, outside the row: a card never measures
    // itself, so the row can safely give them equal height.
    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = showMix && showCustomers && constraints.maxWidth >= sideBySideFrom;
          final cardWidth = sideBySide ? (constraints.maxWidth - FactorySpacing.space3) / 2 : constraints.maxWidth;
          // Card padding (16 + 16) and its 1 px border on both sides.
          final stackedLegend = cardWidth - 34 < legendBesideFrom;
          final cards = [
            if (showMix) ServiceMixCard(pulse: pulse, stackedLegend: stackedLegend),
            if (showCustomers) TopCustomersCard(ranking: ranking),
          ];
          if (cards.length == 1) return cards.single;
          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[0], const SizedBox(height: FactorySpacing.space3), cards[1]],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: FactorySpacing.space3),
                Expanded(child: cards[1]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: context.factoryColors.textTertiary,
          ),
        ),
        const SizedBox(height: FactorySpacing.space3),
      ],
    );
  }
}

/// Revenue by service over the last 30 days as a ring with a legend: the few
/// services that earn most, then "Other".
class ServiceMixCard extends StatelessWidget {
  const ServiceMixCard({super.key, required this.pulse, this.stackedLegend = false});

  final RevenuePulse pulse;

  /// Put the legend under the ring (a narrow card) instead of beside it.
  final bool stackedLegend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String money(double amount) => formatFactoryMoney(amount, pulse.currency);

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            title: l10n.dashboardServiceMixTitle,
            subtitle: l10n.dashboardPulseMonth,
          ),
          FactoryDonutChart(
            stacked: stackedLegend,
            centerLabel: money(pulse.serviceTotal),
            segments: [
              for (final share in pulse.services)
                FactoryChartSegment(
                  label: share.isOther
                      ? l10n.dashboardServiceMixOther
                      : (share.title ?? l10n.dashboardServiceFallback),
                  value: share.amount,
                  valueLabel: money(share.amount),
                ),
            ],
            semanticLabel: l10n.dashboardServiceMixTitle,
          ),
        ],
      ),
    );
  }
}

/// The customers who have spent the most, each with their part of everything
/// customers have spent.
class TopCustomersCard extends StatelessWidget {
  const TopCustomersCard({super.key, required this.ranking});

  final CustomerRanking ranking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            title: l10n.dashboardTopCustomersTitle,
            subtitle: l10n.dashboardTopCustomersSubtitle,
          ),
          FactoryShareList(
            items: [
              for (final customer in ranking.top)
                FactoryShareItem(
                  label: customer.name ?? l10n.dashboardCustomerFallback,
                  valueLabel: formatFactoryMoney(
                    customer.spent,
                    customer.currency,
                  ),
                  share: ranking.shareOf(customer),
                  color: colors.primary,
                  leading: FactoryAvatar(
                    initials: initialsFor(customer.name ?? '?'),
                    size: 32,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
