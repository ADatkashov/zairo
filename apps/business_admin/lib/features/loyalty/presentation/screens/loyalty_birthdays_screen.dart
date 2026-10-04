import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/loyalty_birthday.dart';
import '../providers/loyalty_admin_providers.dart';

/// Members who opted in to greetings and have a birthday in the next 30
/// days, soonest first. If the program grants a birthday bonus the backend
/// pays it automatically on the day -- this list is for the owner to see who
/// is coming up (and to greet them personally); it never shows the age.
class LoyaltyBirthdaysScreen extends ConsumerWidget {
  final String providerId;

  static const _windowDays = 30;

  const LoyaltyBirthdaysScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final key = (providerId, _windowDays);
    final birthdaysAsync = ref.watch(loyaltyBirthdaysProvider(key));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(loyaltyBirthdaysProvider(key));
        await ref.read(loyaltyBirthdaysProvider(key).future).catchError((_) => <LoyaltyBirthday>[]);
      },
      child: birthdaysAsync.when(
        loading: () => const FactoryLoadingState(),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            FactoryErrorState(
              message: l10n.errorLoyaltyBirthdaysLoadFailed(error.toString()),
              onRetry: () => ref.invalidate(loyaltyBirthdaysProvider(key)),
            ),
          ],
        ),
        data: (birthdays) => ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            Text(
              l10n.loyaltyBirthdaysIntro(_windowDays),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: FactorySpacing.space3),
            if (birthdays.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                child: Center(
                  child: Text(
                    l10n.loyaltyBirthdaysEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                  ),
                ),
              )
            else
              for (final birthday in birthdays) ...[
                _BirthdayRow(birthday: birthday),
                const SizedBox(height: FactorySpacing.space3),
              ],
          ],
        ),
      ),
    );
  }
}

class _BirthdayRow extends StatelessWidget {
  final LoyaltyBirthday birthday;

  const _BirthdayRow({required this.birthday});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    // The year is irrelevant (and unknown); 2000 is a leap year so 29 Feb formats.
    final dateLabel = DateFormat.MMMMd(locale).format(DateTime(2000, birthday.month, birthday.day));
    final when = switch (birthday.daysUntil) {
      0 => l10n.loyaltyBirthdaysToday,
      1 => l10n.loyaltyBirthdaysTomorrow,
      final n => l10n.loyaltyBirthdaysInDays(n),
    };

    return FactoryCard(
      child: Row(
        children: [
          Icon(Symbols.cake_rounded, color: birthday.daysUntil == 0 ? colors.primary : colors.textSecondary),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(birthday.displayName ?? '—', style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('$dateLabel · $when', style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          if (birthday.bonusPoints > 0)
            Text(
              birthday.bonusAwarded
                  ? l10n.loyaltyBirthdaysBonusAwarded(birthday.bonusPoints)
                  : l10n.loyaltyBirthdaysBonusPending(birthday.bonusPoints),
              style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}
