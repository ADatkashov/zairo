import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/category.dart';
import '../category_icon.dart';
import '../providers/catalog_providers.dart';

/// The full master catalog — every category (20 at last count) and, per
/// category, its spheres (`catalog.BusinessType`). Reached from Home's
/// popular-categories row via its trailing "All categories" tile, never
/// shown inline on Home itself: Home stays a curated shortlist, this screen
/// is the actual Category -> Sphere browse surface.
///
/// Picking a category (or one of its spheres) pops back to the caller with
/// that category's `code` — the same value Home's own category tiles pass
/// to the search-vertical filter. Sphere-level search filtering doesn't
/// exist in the API yet (see catalog_providers.dart's businessTypesProvider
/// doc comment), so a sphere resolves to its parent category, same as
/// selecting the category itself — honest about what the backend can
/// actually narrow down today, not a dead end either.
class AllCategoriesScreen extends ConsumerWidget {
  const AllCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(title: Text(l10n.allCategoriesTitle)),
      body: SafeArea(
        child: categoriesAsync.when(
          data: (categories) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
            itemCount: categories.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
            itemBuilder: (context, index) => _CategoryExpansionTile(category: categories[index]),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: FactoryErrorState(
                message: l10n.errorCategoriesLoadFailed,
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single category row that expands in place to show its spheres.
/// Deliberately its own [ConsumerStatefulWidget] with local expanded state
/// (rather than an [ExpansionTile] built from an always-watched provider)
/// so [businessTypesProvider] only fires for a category once it's actually
/// expanded — 20 categories eagerly fetching their spheres on screen open
/// would be 20 concurrent requests for rows the user may never open.
class _CategoryExpansionTile extends StatefulWidget {
  const _CategoryExpansionTile({required this.category});

  final Category category;

  @override
  State<_CategoryExpansionTile> createState() => _CategoryExpansionTileState();
}

class _CategoryExpansionTileState extends State<_CategoryExpansionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final languageCode = Localizations.localeOf(context).languageCode;
    final category = widget.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space3),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: category.icon != null
                          ? Text(category.icon!, style: const TextStyle(fontSize: FactoryIconSize.md))
                          : Icon(iconForCategory(category.code), size: FactoryIconSize.md, color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(
                    child: Text(
                      category.nameFor(languageCode),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: colors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) _SphereList(category: category),
      ],
    );
  }
}

class _SphereList extends ConsumerWidget {
  const _SphereList({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final languageCode = Localizations.localeOf(context).languageCode;
    final businessTypesAsync = ref.watch(businessTypesProvider(category.id));

    return Padding(
      padding: const EdgeInsets.only(left: FactorySpacing.space10, right: FactorySpacing.space4, bottom: FactorySpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SphereRow(
            label: l10n.allCategoriesShowAllServicesLabel,
            emphasized: true,
            onTap: () => Navigator.of(context).pop(category.code),
          ),
          businessTypesAsync.when(
            data: (businessTypes) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final businessType in businessTypes)
                  _SphereRow(
                    label: businessType.nameFor(languageCode),
                    onTap: () => Navigator.of(context).pop(category.code),
                  ),
              ],
            ),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.textTertiary),
              ),
            ),
            // Best-effort: the "all services" row above still works even if
            // this specific category's spheres fail to load.
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SphereRow extends StatelessWidget {
  const _SphereRow({required this.label, required this.onTap, this.emphasized = false});

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: FactoryRadius.smRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: emphasized ? colors.primary : colors.textSecondary,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
