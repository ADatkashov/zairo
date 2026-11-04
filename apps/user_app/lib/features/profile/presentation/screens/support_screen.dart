import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';

/// The one real support channel this project has today — a Telegram
/// handle, not an invented email/phone that would just bounce.
const _supportTelegramHandle = 'ADatkashov';
final _supportTelegramUri = Uri.parse('https://t.me/$_supportTelegramHandle');

/// Answers first, a human second: most questions are "where do I find / what happens if", which the common-questions
/// list settles without waiting for a reply. The Telegram handle is for everything else.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final faq = [
      (l10n.faqBookQ, l10n.faqBookA),
      (l10n.faqChangeQ, l10n.faqChangeA),
      (l10n.faqRefundQ, l10n.faqRefundA),
      (l10n.faqReceiptQ, l10n.faqReceiptA),
      (l10n.faqCardsQ, l10n.faqCardsA),
      (l10n.faqNoTimesQ, l10n.faqNoTimesA),
    ];

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.supportTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            Text(l10n.faqTitle, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space2),
            for (final (question, answer) in faq)
              Theme(
                // No divider lines around each tile: the card edge already separates them.
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(question, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  children: [Text(answer, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary))],
                ),
              ),
            const SizedBox(height: FactorySpacing.space4),
            Text(l10n.faqStillNeedHelp, style: textTheme.titleMedium),
            const SizedBox(height: FactorySpacing.space2),
            Text(l10n.supportIntro, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: FactorySpacing.space3),
            FactorySelectableTile(
              title: l10n.supportTelegramLabel,
              subtitle: Text(
                '@$_supportTelegramHandle',
                style: FactoryTypography.mono(size: 13, color: colors.textSecondary),
              ),
              leading: Icon(Symbols.send_rounded, color: colors.primary),
              trailing: Icon(Symbols.chevron_right_rounded, color: colors.textTertiary),
              onTap: () => launchUrl(_supportTelegramUri, mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}
