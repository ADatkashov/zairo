import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../../data/revenue_pulse.dart';

/// "How am I doing lately": what the owner earned today, over the last 7 days
/// and over the last 30, each with its change against the period before and a
/// trend line. Sits right under the all-time hero, so the first screen answers
/// both "how big is this business" and "is it going up".
///
/// Supplementary like the hero: while loading, on error, and for a business that
/// has not earned anything yet it draws nothing (three zero cards with flat lines
/// tell the owner nothing), and the rest of the dashboard carries on.
class RevenuePulseCards extends ConsumerWidget {
  const RevenuePulseCards({super.key, required this.ownerUserId});

  final String ownerUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(ownerRevenuePulseProvider(ownerUserId)).value;
    if (pulse == null || pulse.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    String money(double amount) => formatFactoryMoney(amount, pulse.currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
      child: FactoryMetricGrid(
        minTileWidth: 150,
        maxColumns: 3,
        children: [
          FactoryKpiCard(
            label: l10n.dashboardPulseToday,
            value: money(pulse.today),
            icon: Icons.today_rounded,
            accent: colors.primary,
            delta: RevenuePulse.change(pulse.today, pulse.yesterday),
            caption: l10n.dashboardPulseVsYesterday,
            trend: pulse.trend(14),
            trendLabel: l10n.dashboardPulseTrendLabel(14),
          ),
          FactoryKpiCard(
            label: l10n.dashboardPulseWeek,
            value: money(pulse.last7),
            icon: Icons.date_range_rounded,
            accent: colors.coral,
            delta: RevenuePulse.change(pulse.last7, pulse.previous7),
            caption: l10n.dashboardPulseVsPrevious7,
            trend: pulse.trend(7),
            trendLabel: l10n.dashboardPulseTrendLabel(7),
          ),
          FactoryKpiCard(
            label: l10n.dashboardPulseMonth,
            value: money(pulse.last30),
            icon: Icons.calendar_month_rounded,
            accent: colors.mint,
            delta: RevenuePulse.change(pulse.last30, pulse.previous30),
            caption: l10n.dashboardPulseVsPrevious30,
            trend: pulse.trend(pulseDays),
            trendLabel: l10n.dashboardPulseTrendLabel(pulseDays),
          ),
        ],
      ),
    );
  }
}
