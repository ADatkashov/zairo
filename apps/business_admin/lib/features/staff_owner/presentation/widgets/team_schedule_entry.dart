import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../screens/team_schedule_screen.dart';

/// The business screen's way into the team schedule.
class TeamScheduleEntry extends StatelessWidget {
  const TeamScheduleEntry({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return FactorySelectableTile(
      leading: Icon(Icons.event_available_outlined, color: colors.textSecondary),
      title: l10n.teamScheduleEntryTitle,
      subtitle: Text(
        l10n.teamScheduleEntrySubtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TeamScheduleScreen(providerId: providerId)),
      ),
    );
  }
}
