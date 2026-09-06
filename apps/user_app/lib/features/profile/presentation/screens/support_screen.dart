import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';

/// The one real support channel this project has today — a Telegram
/// handle, not an invented email/phone that would just bounce.
const _supportTelegramHandle = 'ADatkashov';
final _supportTelegramUri = Uri.parse('https://t.me/$_supportTelegramHandle');

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.supportTitle),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.supportIntro,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: FactorySpacing.space4),
              FactorySelectableTile(
                title: l10n.supportTelegramLabel,
                subtitle: Text(
                  '@$_supportTelegramHandle',
                  style: FactoryTypography.mono(
                    size: 13,
                    color: colors.textSecondary,
                  ),
                ),
                leading: Icon(Icons.send_rounded, color: colors.primary),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
                onTap: () => launchUrl(
                  _supportTelegramUri,
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
