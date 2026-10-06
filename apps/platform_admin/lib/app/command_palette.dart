import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/session_controller.dart';
import '../features/businesses/data/business.dart';
import '../features/businesses/data/business_api.dart';
import '../l10n/app_localizations.dart';
import 'nav.dart';
import 'routes.dart';

/// What the person picked in the command palette.
sealed class PaletteChoice {
  const PaletteChoice();
}

/// Go to one of the console's areas.
class PagePick extends PaletteChoice {
  const PagePick(this.path);
  final String path;
}

/// Open one business's details.
class BusinessPick extends PaletteChoice {
  const BusinessPick(this.id);
  final String id;
}

/// Quick search over the console's areas and businesses (Ctrl/Cmd+K).
/// Returns the pick, or null when dismissed.
Future<PaletteChoice?> showCommandPalette(BuildContext context) =>
    showDialog<PaletteChoice>(context: context, builder: (_) => const _CommandPalette());

/// How many businesses the palette lists for one query.
const int _maxBusinessResults = 6;

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<({String label, IconData icon, PaletteChoice choice, String section})> _results(AppLocalizations l10n) {
    final needle = _query.trim().toLowerCase();
    final showStaff = ref.watch(permissionsProvider).canManageStaff;

    final pages = [
      for (final path in consoleBranchPaths)
        if (path != ConsoleRoutes.more && (path != ConsoleRoutes.staff || showStaff))
          (item: navItemFor(l10n, path), path: path),
    ];

    final results = <({String label, IconData icon, PaletteChoice choice, String section})>[
      for (final page in pages)
        if (needle.isEmpty || page.item.label.toLowerCase().contains(needle))
          (
            label: page.item.label,
            icon: page.item.icon,
            choice: PagePick(page.path),
            section: l10n.cmdSectionPages,
          ),
    ];

    // Businesses are only listed once there is something to match, so an
    // empty palette stays a short list of areas.
    if (needle.isNotEmpty) {
      final businesses = ref.watch(businessesProvider).value ?? const <Business>[];
      results.addAll([
        for (final b in businesses.where((b) => b.name.toLowerCase().contains(needle)).take(_maxBusinessResults))
          (
            label: b.name,
            icon: Icons.storefront_outlined,
            choice: BusinessPick(b.id),
            section: l10n.cmdSectionBusinesses,
          ),
      ]);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final results = _results(l10n);

    final children = <Widget>[];
    String? lastSection;
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      if (r.section != lastSection) {
        lastSection = r.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FactorySpacing.space3,
              FactorySpacing.space3,
              FactorySpacing.space3,
              FactorySpacing.space1,
            ),
            child: Text(r.section.toUpperCase(), style: textTheme.labelSmall?.copyWith(color: colors.textTertiary)),
          ),
        );
      }
      // The first row is what Enter picks, so it reads as selected.
      children.add(
        Material(
          color: i == 0 ? colors.primaryTint : Colors.transparent,
          borderRadius: FactoryRadius.mdRadius,
          child: InkWell(
            borderRadius: FactoryRadius.mdRadius,
            onTap: () => Navigator.of(context).pop(r.choice),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space3),
                child: Row(
                  children: [
                    Icon(r.icon, size: 20, color: colors.textSecondary),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
                    ),
                    if (i == 0) Icon(Icons.keyboard_return_rounded, size: 16, color: colors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(
        FactorySpacing.space4,
        FactorySpacing.space12 * 2,
        FactorySpacing.space4,
        FactorySpacing.space4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space3),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) {
                  if (results.isNotEmpty) Navigator.of(context).pop(results.first.choice);
                },
                decoration: InputDecoration(
                  hintText: l10n.cmdPlaceholder,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Divider(height: 1, color: colors.border),
            Flexible(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(FactorySpacing.space6),
                      child: Center(
                        child: Text(l10n.cmdNoResults, style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(FactorySpacing.space2),
                      children: children,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
