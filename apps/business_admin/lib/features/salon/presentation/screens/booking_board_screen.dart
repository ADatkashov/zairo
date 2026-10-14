import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/schedule_entry.dart';
import '../providers/salon_providers.dart';
import 'week_calendar_screen.dart';

/// The same week as the calendar, laid out by status instead of by day:
/// awaiting payment, confirmed, completed, no-show. View only — a booking's
/// status moves through payment, completion and no-show actions with their own
/// rules (refunds, slot release), so cards are not draggable. Cancelled
/// bookings are not on the board (the agenda leaves them out).
class BookingBoardScreen extends ConsumerStatefulWidget {
  const BookingBoardScreen({super.key, required this.ownerUserId, this.weekStart, this.today});

  final String ownerUserId;

  /// The Monday to open on; defaults to this week.
  final DateTime? weekStart;

  /// Overrides "today" in tests.
  final DateTime? today;

  @override
  ConsumerState<BookingBoardScreen> createState() => _BookingBoardScreenState();
}

/// Below this width the columns scroll sideways instead of sharing the row.
const double _boardColumnsMinWidth = 720;
const double _narrowColumnWidth = 280;

class _BoardColumn {
  const _BoardColumn(this.statuses, this.title, this.tone);

  final Set<String> statuses;
  final String title;
  final Color tone;
}

class _BookingBoardScreenState extends ConsumerState<BookingBoardScreen> {
  late final DateTime _today = DateTime(
    (widget.today ?? DateTime.now()).year,
    (widget.today ?? DateTime.now()).month,
    (widget.today ?? DateTime.now()).day,
  );
  late DateTime _weekStart = widget.weekStart ?? weekStartOf(_today);

  void _shift(int weeks) =>
      setState(() => _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final locale = Localizations.localeOf(context).toString();
    final key = (widget.ownerUserId, _weekStart);
    final agendaAsync = ref.watch(ownerWeekAgendaProvider(key));
    final weekEnd = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 6);
    final rangeLabel = '${DateFormat.MMMd(locale).format(_weekStart)} – ${DateFormat.MMMd(locale).format(weekEnd)}';
    final columns = [
      _BoardColumn({'PENDING', 'PENDING_PAYMENT'}, l10n.bookingStatusPendingPayment, colors.warning),
      _BoardColumn({'CONFIRMED'}, l10n.bookingStatusConfirmed, colors.info),
      _BoardColumn({'COMPLETED'}, l10n.bookingStatusCompleted, colors.success),
      _BoardColumn({'NO_SHOW'}, l10n.bookingStatusNoShow, colors.error),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.boardTitle),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(FactorySpacing.space2, FactorySpacing.space2, FactorySpacing.space2, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.calendarPrevWeek,
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(rangeLabel, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: l10n.calendarNextWeek,
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: agendaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(FactorySpacing.space4),
                    child: FactoryErrorState(
                      message: l10n.calendarLoadFailed,
                      onRetry: () => ref.invalidate(ownerWeekAgendaProvider(key)),
                    ),
                  ),
                ),
                data: (items) {
                  final multiple = items.map((a) => a.providerName).toSet().length > 1;
                  final lanes = [
                    for (final column in columns)
                      _Lane(
                        column: column,
                        items: [for (final item in items) if (column.statuses.contains(item.entry.status)) item],
                        showProvider: multiple,
                      ),
                  ];
                  return LayoutBuilder(
                    builder: (context, constraints) => constraints.maxWidth >= _boardColumnsMinWidth
                        ? Padding(
                            padding: const EdgeInsets.all(FactorySpacing.space3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final lane in lanes)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space1),
                                      child: lane,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(FactorySpacing.space3),
                            children: [
                              for (final lane in lanes)
                                SizedBox(
                                  width: _narrowColumnWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: FactorySpacing.space3),
                                    child: lane,
                                  ),
                                ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.column, required this.items, required this.showProvider});

  final _BoardColumn column;
  final List<AgendaItem> items;
  final bool showProvider;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: column.tone, shape: BoxShape.circle)),
                const SizedBox(width: FactorySpacing.space2),
                Expanded(child: Text(column.title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${items.length}', style: FactoryTypography.mono(size: 13, weight: FontWeight.w600, color: colors.text)),
              ],
            ),
            const SizedBox(height: FactorySpacing.space3),
            if (items.isEmpty)
              Text(l10n.calendarDayEmpty, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                  child: _BoardCard(item: item, showProvider: showProvider),
                ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.item, required this.showProvider});

  final AgendaItem item;
  final bool showProvider;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final start = item.entry.startsAt.toLocal();
    return FactoryCard(
      padding: const EdgeInsets.all(FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat.MMMEd(locale).format(start)} · ${DateFormat.Hm(locale).format(start)}',
            style: FactoryTypography.mono(size: 12, color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(item.serviceTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
          if (showProvider)
            Text(item.providerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          const SizedBox(height: 2),
          Text(
            formatFactoryMoney(item.entry.totalPrice, item.entry.currency),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
