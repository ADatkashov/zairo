import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/city.dart';
import '../data/city_api.dart';
import 'city_dialog.dart';

/// The cities the platform operates in. A city that is switched off disappears
/// from customers' city pickers but keeps its data; deleting one is permanent,
/// so the screen steers people to switching it off instead.
class CitiesScreen extends ConsumerStatefulWidget {
  const CitiesScreen({super.key});

  @override
  ConsumerState<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends ConsumerState<CitiesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final canEdit = ref.watch(permissionsProvider).canEditCities;
    final async = ref.watch(citiesProvider);
    Future<void> refresh() => ref.refresh(citiesProvider.future);

    return AreaScaffold(
      title: l10n.navCities,
      actions: [IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh)],
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(icon: const Icon(Icons.add), label: Text(l10n.cityAdd), onPressed: _create)
          : null,
      body: AsyncView<List<City>>(
        value: async,
        onRetry: () => ref.invalidate(citiesProvider),
        builder: (cities) {
          if (cities.isEmpty) {
            return EmptyView(
              icon: Icons.location_city_outlined,
              title: l10n.citiesEmptyTitle,
              message: canEdit ? l10n.citiesEmptyMessage : '',
              onRefresh: refresh,
            );
          }
          final needle = _query.trim().toLowerCase();
          final visible =
              cities
                  .where(
                    (c) =>
                        needle.isEmpty || [c.name, c.nameKk ?? '', c.code].any((t) => t.toLowerCase().contains(needle)),
                  )
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          return ContentFrame(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  FactorySpacing.space4,
                  96,
                ),
                children: [
                  FactorySearchField(
                    controller: _search,
                    hint: l10n.citiesSearchHint,
                    onChanged: (value) => setState(() => _query = value),
                    onCleared: () => setState(() => _query = ''),
                    clearSemanticLabel: l10n.clear,
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  if (visible.isEmpty)
                    FactoryEmptyState(icon: Icons.search_off_rounded, title: l10n.noMatches, message: '')
                  else
                    for (final city in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _CityTile(
                          city: city,
                          languageCode: languageCode,
                          canEdit: canEdit,
                          onEdit: () => _edit(city),
                          onSetActive: (active) => _setActive(city, active),
                          onDelete: () => _delete(city),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _create() async {
    final name = await showDialog<String>(context: context, builder: (_) => const CityDialog());
    if (name == null || !mounted) return;
    ref.invalidate(citiesProvider);
    showSnack(context, AppLocalizations.of(context)!.cityCreated(name));
  }

  Future<void> _edit(City city) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => CityDialog(city: city),
    );
    if (name == null || !mounted) return;
    ref.invalidate(citiesProvider);
    showSnack(context, AppLocalizations.of(context)!.citySaved(name));
  }

  Future<void> _setActive(City city, bool active) async {
    final l10n = AppLocalizations.of(context)!;
    if (!active) {
      final confirmed = await confirmAction(
        context,
        title: l10n.cityDeactivateTitle(city.name),
        message: l10n.cityDeactivateMessage,
        confirmLabel: l10n.cityDeactivate,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await ref.read(cityApiProvider).update(city, active: active);
      ref.invalidate(citiesProvider);
      if (mounted) showSnack(context, active ? l10n.cityActivated(city.name) : l10n.cityDeactivated(city.name));
    } catch (error) {
      if (mounted) showSnack(context, describeError(l10n, error));
    }
  }

  Future<void> _delete(City city) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmAction(
      context,
      title: l10n.cityDeleteTitle(city.name),
      message: l10n.cityDeleteMessage,
      confirmLabel: l10n.delete,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(cityApiProvider).delete(city.code);
      ref.invalidate(citiesProvider);
      if (mounted) showSnack(context, l10n.cityDeleted(city.name));
    } catch (error) {
      if (mounted) showSnack(context, describeError(l10n, error));
    }
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.languageCode,
    required this.canEdit,
    required this.onEdit,
    required this.onSetActive,
    required this.onDelete,
  });

  final City city;
  final String languageCode;
  final bool canEdit;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return FactorySelectableTile(
      title: city.nameFor(languageCode),
      titleColor: city.active ? null : Theme.of(context).disabledColor,
      onTap: canEdit ? onEdit : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${city.countryCode} · ${city.timezone} · ${city.currency}'),
          Text(
            l10n.cityRadiusValue(city.radiusKm),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!city.active) ToneBadge(label: l10n.statusHidden),
          if (canEdit) ...[
            Tooltip(
              message: city.active ? l10n.cityActiveTooltip : l10n.cityInactiveTooltip,
              child: Switch(value: city.active, onChanged: onSetActive),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.moreActions,
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.edit),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(l10n.delete),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
