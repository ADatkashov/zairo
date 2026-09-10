import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../l10n/app_localizations.dart';

/// The real running app version/build number (via package_info_plus) —
/// never a hardcoded string that would silently drift from pubspec.yaml.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.aboutTitle),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              children: [
                const SizedBox(height: FactorySpacing.space6),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: colors.primaryTint,
                          borderRadius: FactoryRadius.xlRadius,
                        ),
                        child: Icon(
                          Symbols.storefront_rounded,
                          size: 36,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: FactorySpacing.space4),
                      Text(
                        AppConfig.appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: FactorySpacing.space1),
                      Text(
                        info == null
                            ? l10n.aboutVersionLoading
                            : l10n.aboutVersionLabel(
                                info.version,
                                info.buildNumber,
                              ),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
