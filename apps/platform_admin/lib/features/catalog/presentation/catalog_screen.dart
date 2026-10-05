import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/catalog_api.dart';
import '../data/catalog_models.dart';
import 'catalog_edit_dialog.dart';

/// The master catalog — what a business can say it offers. Businesses don't
/// invent their own category or service names; they pick from here, so this is
/// where a new category, sphere, subsphere or service gets added, translated
/// (Kazakh / Russian / English), reordered, renamed or hidden.
///
/// Pick a level, and for the lower levels the category / sphere it lives in;
/// the picks are shared between levels, so moving from "Spheres" to "Services"
/// keeps you in the same category. Only platform admins can change anything;
/// other roles read.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  CatalogLevel _level = CatalogLevel.category;
  String? _categoryId;
  String? _sphereId;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _needsCategory => _level != CatalogLevel.category;
  bool get _needsSphere => _level == CatalogLevel.subsphere || _level == CatalogLevel.service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final canEdit = ref.watch(permissionsProvider).canEditCatalog;
    final categoriesAsync = ref.watch(catalogNodesProvider((CatalogLevel.category, null)));

    return AreaScaffold(
      title: l10n.navCatalog,
      body: AsyncView<List<CatalogNode>>(
        value: categoriesAsync,
        onRetry: () => ref.invalidate(catalogNodesProvider((CatalogLevel.category, null))),
        builder: (categoriesRaw) {
          final categories = _sorted(categoriesRaw);
          final category = categories.where((c) => c.id == _categoryId).firstOrNull ?? categories.firstOrNull;

          final spheresAsync = (_needsSphere && category != null)
              ? ref.watch(catalogNodesProvider((CatalogLevel.sphere, category.id)))
              : const AsyncData<List<CatalogNode>>([]);
          final spheres = _sorted(spheresAsync.value ?? const []);
          final sphere = spheres.where((s) => s.id == _sphereId).firstOrNull ?? spheres.firstOrNull;

          final canAdd = switch (_level) {
            CatalogLevel.category => true,
            CatalogLevel.sphere => category != null,
            _ => sphere != null,
          };

          return Stack(
            children: [
              ContentFrame(
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
                            canEdit ? l10n.catalogHint : l10n.catalogHintReadOnly,
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
                          if (_needsCategory && categories.isNotEmpty) ...[
                            const SizedBox(height: FactorySpacing.space3),
                            DropdownButtonFormField<String>(
                              key: ValueKey('category-${category?.id}'),
                              initialValue: category?.id,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n.selectCategory),
                              items: [
                                for (final c in categories)
                                  DropdownMenuItem(value: c.id, child: Text(c.titleFor(languageCode))),
                              ],
                              onChanged: (value) => setState(() {
                                _categoryId = value;
                                _sphereId = null;
                              }),
                            ),
                          ],
                          if (_needsSphere && spheres.isNotEmpty) ...[
                            const SizedBox(height: FactorySpacing.space3),
                            DropdownButtonFormField<String>(
                              key: ValueKey('sphere-${sphere?.id}'),
                              initialValue: sphere?.id,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: l10n.selectSphere),
                              items: [
                                for (final s in spheres)
                                  DropdownMenuItem(value: s.id, child: Text(s.nameFor(languageCode))),
                              ],
                              onChanged: (value) => setState(() => _sphereId = value),
                            ),
                          ],
                          const SizedBox(height: FactorySpacing.space3),
                          FactorySearchField(
                            controller: _search,
                            hint: l10n.catalogSearchHint,
                            onChanged: (value) => setState(() => _query = value),
                            onCleared: () => setState(() => _query = ''),
                            clearSemanticLabel: l10n.clear,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _body(l10n, languageCode, canEdit, category, sphere, spheresAsync)),
                  ],
                ),
              ),
              if (canEdit && canAdd)
                Positioned(
                  right: FactorySpacing.space4,
                  bottom: FactorySpacing.space4,
                  child: FloatingActionButton.extended(
                    onPressed: () => _create(category, sphere),
                    icon: const Icon(Icons.add),
                    label: Text(_addLabel(l10n)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(
    AppLocalizations l10n,
    String languageCode,
    bool canEdit,
    CatalogNode? category,
    CatalogNode? sphere,
    AsyncValue<List<CatalogNode>> spheresAsync,
  ) {
    String? parentId;
    switch (_level) {
      case CatalogLevel.category:
        parentId = null;
      case CatalogLevel.sphere:
        if (category == null) return _Notice(message: l10n.needCategoryFirst);
        parentId = category.id;
      case CatalogLevel.subsphere:
      case CatalogLevel.service:
        if (category == null) return _Notice(message: l10n.needCategoryFirst);
        if (spheresAsync.isLoading) return const Center(child: CircularProgressIndicator());
        if (spheresAsync.hasError) {
          return LoadError(
            error: spheresAsync.error,
            onRetry: () => ref.invalidate(catalogNodesProvider((CatalogLevel.sphere, category.id))),
          );
        }
        if (sphere == null) return _Notice(message: l10n.needSphereFirst);
        parentId = sphere.id;
    }
    final key = (_level, parentId);
    final async = ref.watch(catalogNodesProvider(key));
    return AsyncView<List<CatalogNode>>(
      value: async,
      onRetry: () => ref.invalidate(catalogNodesProvider(key)),
      builder: (items) {
        final needle = _query.trim().toLowerCase();
        final sorted = _sorted(items).where((n) {
          if (needle.isEmpty) return true;
          return [n.nameEn, n.nameRu, n.nameKk, n.code ?? ''].any((text) => text.toLowerCase().contains(needle));
        }).toList();
        if (sorted.isEmpty) {
          return _Notice(message: needle.isNotEmpty ? l10n.noMatches : _emptyMessage(l10n, canEdit));
        }
        // Subsphere names for services that hang under one.
        final subsphereNames = <String, String>{};
        if (_level == CatalogLevel.service) {
          for (final s
              in ref.watch(catalogNodesProvider((CatalogLevel.subsphere, parentId))).value ?? const <CatalogNode>[]) {
            subsphereNames[s.id] = s.nameFor(languageCode);
          }
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(catalogNodesProvider(key).future),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            // Leave room so the add button never covers the last row.
            padding: const EdgeInsets.fromLTRB(FactorySpacing.space4, FactorySpacing.space2, FactorySpacing.space4, 96),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
            itemBuilder: (context, index) {
              final node = sorted[index];
              return _CatalogTile(
                node: node,
                canEdit: canEdit,
                subsphereName: node.subsphereId == null ? null : subsphereNames[node.subsphereId],
                onEdit: () => _edit(node, key, category, sphere),
                onSetVisible: (visible) => _setVisible(node, visible, key),
              );
            },
          ),
        );
      },
    );
  }

  List<CatalogNode> _sorted(List<CatalogNode> items) => [...items]
    ..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.nameEn.compareTo(b.nameEn));

  int _nextPosition(List<CatalogNode> items) =>
      items.isEmpty ? 10 : (items.map((n) => n.sortOrder).reduce((a, b) => a > b ? a : b) ~/ 10 + 1) * 10;

  Future<void> _create(CatalogNode? category, CatalogNode? sphere) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final parent = switch (_level) {
      CatalogLevel.category => null,
      CatalogLevel.sphere => category,
      _ => sphere,
    };
    final key = (_level, parent?.id);
    final existing = ref.read(catalogNodesProvider(key)).value ?? const <CatalogNode>[];
    final subspheres = _level == CatalogLevel.service
        ? _sorted(ref.read(catalogNodesProvider((CatalogLevel.subsphere, sphere?.id))).value ?? const [])
        : const <CatalogNode>[];
    final created = await showDialog<String>(
      context: context,
      builder: (_) => CatalogEditDialog(
        level: _level,
        parentId: parent?.id,
        parentName: parent?.nameFor(languageCode),
        suggestedPosition: _nextPosition(existing),
        subspheres: subspheres,
      ),
    );
    if (created == null || !mounted) return;
    ref.invalidate(catalogNodesProvider(key));
    showSnack(context, AppLocalizations.of(context)!.catalogCreated(created));
  }

  Future<void> _edit(CatalogNode node, (CatalogLevel, String?) key, CatalogNode? category, CatalogNode? sphere) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => CatalogEditDialog(level: node.level, node: node),
    );
    if (saved == null || !mounted) return;
    ref.invalidate(catalogNodesProvider(key));
    showSnack(context, AppLocalizations.of(context)!.catalogSaved(saved));
  }

  /// Hiding asks first — this is the tree businesses pick from, so switching a
  /// row off is never a single accidental tap; showing it again is the safe
  /// direction and stays instant.
  Future<void> _setVisible(CatalogNode node, bool visible, (CatalogLevel, String?) key) async {
    final l10n = AppLocalizations.of(context)!;
    final name = node.titleFor(Localizations.localeOf(context).languageCode);
    if (!visible) {
      final confirmed = await confirmAction(
        context,
        title: l10n.catalogHideTitle(name),
        message: l10n.catalogHideMessage,
        confirmLabel: l10n.catalogHide,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await ref.read(catalogApiProvider).setStatus(node, visible ? 'ACTIVE' : 'INACTIVE');
      ref.invalidate(catalogNodesProvider(key));
      if (mounted) showSnack(context, visible ? l10n.catalogShown(name) : l10n.catalogHidden(name));
    } catch (error) {
      if (mounted) showSnack(context, describeError(l10n, error));
    }
  }

  String _levelLabel(AppLocalizations l10n, CatalogLevel level) => switch (level) {
    CatalogLevel.category => l10n.levelCategories,
    CatalogLevel.sphere => l10n.levelSpheres,
    CatalogLevel.subsphere => l10n.levelSubspheres,
    CatalogLevel.service => l10n.levelServices,
  };

  String _addLabel(AppLocalizations l10n) => switch (_level) {
    CatalogLevel.category => l10n.addCategory,
    CatalogLevel.sphere => l10n.addSphere,
    CatalogLevel.subsphere => l10n.addSubsphere,
    CatalogLevel.service => l10n.addService,
  };

  String _emptyMessage(AppLocalizations l10n, bool canEdit) => switch (_level) {
    CatalogLevel.category => canEdit ? l10n.emptyCategories : l10n.emptyCategoriesReadOnly,
    CatalogLevel.sphere => canEdit ? l10n.emptySpheres : l10n.emptySpheresReadOnly,
    CatalogLevel.subsphere => l10n.emptySubspheres,
    CatalogLevel.service => canEdit ? l10n.emptyServices : l10n.emptyServicesReadOnly,
  };
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

/// A catalog row: the name in the app's language, the other two translations
/// underneath so a missing or wrong translation is visible at a glance, the
/// code, and (for admins) a visibility switch and an edit button.
class _CatalogTile extends StatefulWidget {
  const _CatalogTile({
    required this.node,
    required this.canEdit,
    required this.onEdit,
    required this.onSetVisible,
    this.subsphereName,
  });

  final CatalogNode node;
  final bool canEdit;
  final String? subsphereName;
  final VoidCallback onEdit;
  final Future<void> Function(bool visible) onSetVisible;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _busy = false;

  Future<void> _toggle(bool visible) async {
    setState(() => _busy = true);
    try {
      await widget.onSetVisible(visible);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final node = widget.node;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final others = [
      if (languageCode != 'en') 'EN: ${node.nameEn}',
      if (languageCode != 'ru') 'RU: ${node.nameRu}',
      if (languageCode != 'kk') 'KK: ${node.nameKk}',
    ].join('  ·  ');

    return FactorySelectableTile(
      title: node.titleFor(languageCode),
      titleColor: node.isActive ? null : Theme.of(context).disabledColor,
      onTap: widget.canEdit ? widget.onEdit : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(others),
          if (widget.subsphereName != null) Text(l10n.inSubsphere(widget.subsphereName!)),
          if (node.code != null) Text(node.code!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!node.isActive) ToneBadge(label: taxonomyStatusLabel(l10n, node.status)),
          if (widget.canEdit && node.status != 'ARCHIVED')
            Tooltip(
              message: node.isActive ? l10n.itemVisible : l10n.itemHiddenSwitch,
              child: Switch(value: node.isActive, onChanged: _busy ? null : _toggle),
            ),
          if (widget.canEdit)
            IconButton(tooltip: l10n.edit, icon: const Icon(Icons.edit_outlined), onPressed: widget.onEdit),
        ],
      ),
    );
  }
}
