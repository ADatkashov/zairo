import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/auth_navigation.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../providers/waitlist_providers.dart';

/// How many days ahead the customer can pick from.
const int waitlistDaysAhead = 14;

/// The "no open times" state of a business, with the one thing a customer can do about it: ask to be told the moment
/// a time frees up. One tap on "Notify me" is enough (any day will do); a strip of days above the button narrows it
/// to the day the customer wants. Logged out, the button opens LoginScreen — same gate as the favorite button. Once
/// on the list the state says so (and for which day) and offers to leave it.
class NoTimesWaitlist extends ConsumerStatefulWidget {
  final String providerId;

  const NoTimesWaitlist({super.key, required this.providerId});

  @override
  ConsumerState<NoTimesWaitlist> createState() => _NoTimesWaitlistState();
}

class _NoTimesWaitlistState extends ConsumerState<NoTimesWaitlist> {
  bool _busy = false;

  /// The picked local calendar day; null is "any day".
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(authControllerProvider).value;

    // A failed or slow lookup just shows the join form: joining is idempotent on the backend.
    if (currentUser != null) {
      final entry = ref.watch(waitlistEntriesProvider(currentUser.id)).value?[widget.providerId];
      if (entry != null) {
        final day = entry.day;
        return FactoryEmptyState(
          compact: true,
          icon: Symbols.notifications_active_rounded,
          title: l10n.waitlistJoinedTitle,
          message: day == null
              ? l10n.waitlistJoinedMessage
              : l10n.waitlistJoinedDayMessage(formatWeekdayMonthDay(l10n, day)),
          actionLabel: l10n.waitlistLeaveButton,
          onAction: _busy ? null : () => _change(currentUser.id, join: false),
        );
      }
    }

    final today = DateTime.now();
    final days = [for (var i = 0; i < waitlistDaysAhead; i++) DateTime(today.year, today.month, today.day + i)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FactoryEmptyState(
          compact: true,
          icon: Symbols.event_busy_rounded,
          title: l10n.noOpenTimesTitle,
          message: l10n.noOpenTimesWaitlistMessage,
        ),
        Text(l10n.waitlistWhichDay, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center),
        const SizedBox(height: FactorySpacing.space2),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
            children: [
              _chip(l10n.waitlistAnyDay, _day == null, () => setState(() => _day = null)),
              for (var i = 0; i < days.length; i++)
                _chip(
                  switch (i) {
                    0 => l10n.waitlistToday,
                    1 => l10n.waitlistTomorrow,
                    _ => formatWeekdayMonthDay(l10n, days[i]),
                  },
                  _day == days[i],
                  () => setState(() => _day = days[i]),
                ),
            ],
          ),
        ),
        const SizedBox(height: FactorySpacing.space4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space6),
          child: FactoryButton(
            label: l10n.waitlistJoinButton,
            onPressed: _busy
                ? null
                : () {
                    if (currentUser == null) {
                      pushAuthScreen(context, const LoginScreen());
                      return;
                    }
                    _change(currentUser.id, join: true);
                  },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: FactorySpacing.space2),
    child: Center(child: FactoryChip(label: label, selected: selected, onTap: onTap)),
  );

  Future<void> _change(String userId, {required bool join}) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(waitlistApiProvider);
    try {
      if (join) {
        await api.join(userId, widget.providerId, day: _day);
      } else {
        await api.leave(userId, widget.providerId);
      }
      ref.invalidate(waitlistEntriesProvider(userId));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.waitlistFailed)));
    }
    if (mounted) setState(() => _busy = false);
  }
}
