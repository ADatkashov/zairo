import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/models/business_type.dart';
import '../../../catalog/data/models/category.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../widgets/platform_admin_common.dart';
import '../widgets/platform_catalog_create_dialog.dart';

/// The master catalog in one place: pick a level (categories, spheres,
/// subspheres, services) and, for the lower levels, the category / sphere it
/// lives in. The picks are shared between levels, so moving from "Spheres" to
/// "Services" keeps you in the same category. Items are shown in the app's
/// language, can be hidden/shown with a switch, and new ones are added with
/// the button at the bottom.
class PlatformAdminCatalogTab extends ConsumerStatefulWidget {
  const PlatformAdminCatalogTab({super.key, required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<PlatformAdminCatalogTab> createState() => _PlatformAdminCatalogTabState();
}

class _PlatformAdminCatalogTabState extends ConsumerState<PlatformAdminCatalogTab> {
  CatalogLevel _level = CatalogLevel.category;
  String? _categoryId;
  String? _sphereId;

  String get _token => widget.platformToken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final categoriesAsync = ref.watch(platformAllCategoriesProvider(_token));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          PlatformLoadError(onRetry: () => ref.invalidate(platformAllCategoriesProvider(_token))),
      data: (categories) {
        final category = categories.where((c) => c.id == _categoryId).firstOrNull ?? categories.firstOrNull;
        final needsCategory = _level != CatalogLevel.category;
        final needsSphere = _level == CatalogLevel.subsphere || _level == CatalogLevel.service;

        final spheres = needsSphere && category != null
            ? ref.watch(platformAllBusinessTypesProvider((_token, category.id)))
            : const AsyncData<List<BusinessType>>([]);
        final sphere =
            (spheres.value ?? const <BusinessType>[]).where((s) => s.id == _sphereId).firstOrNull ??
            spheres.value?.firstOrNull;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: PlatformContentFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FactorySpacing.space4,
                    FactorySpacing.space4,
                    FactorySpacing.space4,
                    FactorySpacing.space2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.paCatalogHint,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.factoryColors.textSecondary),
                      ),
                      const SizedBox(height: FactorySpacing.space3),
                      Wrap(
                        spacing: FactorySpacing.space2,
                        runSpacing: FactorySpacing.space2,
                        children: [
                          for (final level in CatalogLevel.values)
                            FactoryChip(
                              label: _levelLabel(l10n, level),
                              selected: _level == level,
                              onTap: () => setState(() => _level = level),
                            ),
                        ],
                      ),
                      if (needsCategory && categories.isNotEmpty) ...[
                        const SizedBox(height: FactorySpacing.space3),
                        DropdownButtonFormField<String>(
                          key: ValueKey('category-${category?.id}'),
                          initialValue: category?.id,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.paSelectCategory),
                          items: [
                            for (final c in categories)
                              DropdownMenuItem(value: c.id, child: Text(_categoryTitle(c, languageCode))),
                          ],
                          onChanged: (value) => setState(() {
                            _categoryId = value;
                            _sphereId = null;
                          }),
                        ),
                      ],
                      if (needsSphere && (spheres.value?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: FactorySpacing.space3),
                        DropdownButtonFormField<String>(
                          key: ValueKey('sphere-${sphere?.id}'),
                          initialValue: sphere?.id,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l10n.paSelectSphere),
                          items: [
                            for (final s in spheres.value!)
                              DropdownMenuItem(value: s.id, child: Text(s.nameFor(languageCode))),
                          ],
                          onChanged: (value) => setState(() => _sphereId = value),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: _body(l10n, languageCode, categories, category, spheres, sphere)),
              ],
            ),
          ),
          floatingActionButton: _canAdd(categories, category, sphere)
              ? FloatingActionButton.extended(
                  onPressed: () => _add(category, sphere),
                  icon: const Icon(Icons.add),
                  label: Text(_addLabel(l10n)),
                )
              : null,
        );
      },
    );
  }

  Widget _body(
    AppLocalizations l10n,
    String languageCode,
    List<Category> categories,
    Category? category,
    AsyncValue<List<BusinessType>> spheres,
    BusinessType? sphere,
  ) {
    switch (_level) {
      case CatalogLevel.category:
        return _CatalogList(
          emptyMessage: l10n.paEmptyCategories,
          rows: [
            for (final c in categories)
              _CatalogRow(
                title: _categoryTitle(c, languageCode),
                code: c.code,
                status: c.status,
                onSetStatus: (next) => ref.read(catalogApiProvider).setCategoryStatus(_token, c.id, next),
              ),
          ],
          onChanged: () => ref.invalidate(platformAllCategoriesProvider(_token)),
        );
      case CatalogLevel.sphere:
        if (category == null) return _Notice(message: l10n.paNeedCategoryFirst);
        final async = ref.watch(platformAllBusinessTypesProvider((_token, category.id)));
        return _asyncList<BusinessType>(
          async,
          retry: () => ref.invalidate(platformAllBusinessTypesProvider((_token, category.id))),
          builder: (items) => _CatalogList(
            emptyMessage: l10n.paEmptySpheres,
            rows: [
              for (final s in items)
                _CatalogRow(
                  title: s.nameFor(languageCode),
                  code: s.code,
                  status: s.status,
                  onSetStatus: (next) => ref.read(catalogApiProvider).setBusinessTypeStatus(_token, s.id, next),
                ),
            ],
            onChanged: () => ref.invalidate(platformAllBusinessTypesProvider((_token, category.id))),
          ),
        );
      case CatalogLevel.subsphere:
      case CatalogLevel.service:
        if (category == null) return _Notice(message: l10n.paNeedCategoryFirst);
        if (spheres.isLoading) return const Center(child: CircularProgressIndicator());
        if (spheres.hasError) {
          return PlatformLoadError(
            onRetry: () => ref.invalidate(platformAllBusinessTypesProvider((_token, category.id))),
          );
        }
        if (sphere == null) return _Notice(message: l10n.paNeedSphereFirst);
        if (_level == CatalogLevel.subsphere) {
          final async = ref.watch(platformAllSubspheresProvider((_token, sphere.id)));
          return _asyncList(
            async,
            retry: () => ref.invalidate(platformAllSubspheresProvider((_token, sphere.id))),
            builder: (items) => _CatalogList(
              emptyMessage: l10n.paEmptySubspheres,
              rows: [
                for (final s in items)
                  _CatalogRow(
                    title: s.nameFor(languageCode),
                    code: s.code,
                    status: s.status,
                    onSetStatus: (next) => ref.read(catalogApiProvider).setSubsphereStatus(_token, s.id, next),
                  ),
              ],
              onChanged: () => ref.invalidate(platformAllSubspheresProvider((_token, sphere.id))),
            ),
          );
        }
        final async = ref.watch(platformAllCatalogServicesProvider((_token, sphere.id)));
        return _asyncList(
          async,
          retry: () => ref.invalidate(platformAllCatalogServicesProvider((_token, sphere.id))),
          builder: (items) => _CatalogList(
            emptyMessage: l10n.paEmptyServices,
            rows: [
              for (final s in items)
                _CatalogRow(
                  title: s.nameFor(languageCode),
                  status: s.status,
                  onSetStatus: (next) => ref.read(catalogApiProvider).setCatalogServiceStatus(_token, s.id, next),
                ),
            ],
            onChanged: () => ref.invalidate(platformAllCatalogServicesProvider((_token, sphere.id))),
          ),
        );
    }
  }

  Widget _asyncList<T>(
    AsyncValue<List<T>> async, {
    required VoidCallback retry,
    required Widget Function(List<T>) builder,
  }) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => PlatformLoadError(onRetry: retry),
      data: builder,
    );
  }

  bool _canAdd(List<Category> categories, Category? category, BusinessType? sphere) => switch (_level) {
    CatalogLevel.category => true,
    CatalogLevel.sphere => category != null,
    CatalogLevel.subsphere || CatalogLevel.service => sphere != null,
  };

  Future<void> _add(Category? category, BusinessType? sphere) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final parentId = switch (_level) {
      CatalogLevel.category => null,
      CatalogLevel.sphere => category?.id,
      _ => sphere?.id,
    };
    final parentName = switch (_level) {
      CatalogLevel.category => null,
      CatalogLevel.sphere => category?.nameFor(languageCode),
      _ => sphere?.nameFor(languageCode),
    };
    final level = _level;
    final created = await showDialog<String>(
      context: context,
      builder: (_) =>
          PlatformCatalogCreateDialog(platformToken: _token, level: level, parentId: parentId, parentName: parentName),
    );
    if (created == null || !mounted) return;
    switch (level) {
      case CatalogLevel.category:
        ref.invalidate(platformAllCategoriesProvider(_token));
      case CatalogLevel.sphere:
        ref.invalidate(platformAllBusinessTypesProvider((_token, parentId!)));
      case CatalogLevel.subsphere:
        ref.invalidate(platformAllSubspheresProvider((_token, parentId!)));
      case CatalogLevel.service:
        ref.invalidate(platformAllCatalogServicesProvider((_token, parentId!)));
    }
    showPlatformSnack(context, AppLocalizations.of(context)!.paItemCreated(created));
  }

  String _levelLabel(AppLocalizations l10n, CatalogLevel level) => switch (level) {
    CatalogLevel.category => l10n.paLevelCategories,
    CatalogLevel.sphere => l10n.paLevelSpheres,
    CatalogLevel.subsphere => l10n.paLevelSubspheres,
    CatalogLevel.service => l10n.paLevelServices,
  };

  String _addLabel(AppLocalizations l10n) => switch (_level) {
    CatalogLevel.category => l10n.paAddCategory,
    CatalogLevel.sphere => l10n.paAddSphere,
    CatalogLevel.subsphere => l10n.paAddSubsphere,
    CatalogLevel.service => l10n.paAddService,
  };

  String _categoryTitle(Category c, String languageCode) => '${c.icon ?? ''} ${c.nameFor(languageCode)}'.trim();
}

class _CatalogRow {
  const _CatalogRow({required this.title, required this.status, required this.onSetStatus, this.code});

  final String title;
  final String? code;
  final String status;
  final Future<void> Function(String nextStatus) onSetStatus;
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.rows, required this.emptyMessage, required this.onChanged});

  final List<_CatalogRow> rows;
  final String emptyMessage;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _Notice(message: emptyMessage);
    return ListView.separated(
      // Leave room so the add button never covers the last row.
      padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space2, FactorySpacing.space4, 96),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
      itemBuilder: (context, index) => _CatalogTile(row: rows[index], onChanged: onChanged),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FactorySpacing.space6),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.factoryColors.textSecondary),
        ),
      ),
    );
  }
}

/// A row with a visibility switch. Hiding asks first — this is the tree
/// businesses pick from, so switching a category/sphere/subsphere/service off
/// is never a single accidental tap; showing it again is the safe direction
/// and stays instant.
class _CatalogTile extends StatefulWidget {
  const _CatalogTile({required this.row, required this.onChanged});

  final _CatalogRow row;
  final VoidCallback onChanged;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _busy = false;

  Future<void> _toggle(bool visible) async {
    final l10n = AppLocalizations.of(context)!;
    final row = widget.row;
    if (!visible) {
      final confirmed = await confirmPlatformAction(
        context,
        title: l10n.paHideTitle(row.title),
        message: l10n.paHideMessage,
        confirmLabel: l10n.paHideButton,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await row.onSetStatus(visible ? 'ACTIVE' : 'INACTIVE');
      widget.onChanged();
      if (mounted) {
        showPlatformSnack(context, visible ? l10n.paItemShown(row.title) : l10n.paItemHidden(row.title));
      }
    } catch (_) {
      if (mounted) showPlatformSnack(context, l10n.paActionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final row = widget.row;
    final active = row.status == 'ACTIVE';
    return FactorySelectableTile(
      title: row.title,
      titleColor: active ? null : Theme.of(context).disabledColor,
      subtitle: row.code == null ? null : Text(row.code!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ARCHIVED can't be switched from here (nothing in this tool sets
          // it), so its badge stands alone.
          if (!active) PlatformStatusBadge(status: row.status),
          if (row.status != 'ARCHIVED')
            Tooltip(
              message: active ? l10n.paItemVisible : l10n.paItemHiddenSwitch,
              child: Switch(value: active, onChanged: _busy ? null : _toggle),
            ),
        ],
      ),
    );
  }
}
