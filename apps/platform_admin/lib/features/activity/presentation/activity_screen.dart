import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/labels.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../businesses/data/business_api.dart';
import '../data/activity_api.dart';
import '../data/audit_entry.dart';

/// Everything platform staff changed, newest first, in words: what happened,
/// to what, who did it, and (for status changes) from what to what. Filter by
/// area or search by person / action. Any platform role can read it.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _pageSize = 50;
  int _size = _pageSize;
  AuditArea? _area;
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
    final locale = Localizations.localeOf(context).toString();
    final async = ref.watch(auditLogProvider(_size));
    final businessNames = {for (final b in ref.watch(businessesProvider).value ?? const []) b.id: b.name};
    Future<void> refresh() => ref.refresh(auditLogProvider(_size).future);

    return AreaScaffold(
      title: l10n.navActivity,
      actions: [IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh)],
      body: AsyncView<List<AuditEntry>>(
        value: async,
        onRetry: () => ref.invalidate(auditLogProvider(_size)),
        builder: (entries) {
          if (entries.isEmpty) {
            return EmptyView(
              icon: Icons.history_rounded,
              title: l10n.activityEmptyTitle,
              message: l10n.activityEmptyMessage,
              onRefresh: refresh,
            );
          }
          final needle = _query.trim().toLowerCase();
          final visible = entries.where((e) {
            if (_area != null && auditAreaOf(e.action) != _area) return false;
            if (needle.isEmpty) return true;
            return e.actorEmail.toLowerCase().contains(needle) ||
                auditActionLabel(l10n, e.action).toLowerCase().contains(needle);
          }).toList();

          return ContentFrame(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FactorySpacing.space4),
                children: [
                  FactorySearchField(
                    controller: _search,
                    hint: l10n.activitySearchHint,
                    onChanged: (value) => setState(() => _query = value),
                    onCleared: () => setState(() => _query = ''),
                    clearSemanticLabel: l10n.clear,
                  ),
                  const SizedBox(height: FactorySpacing.space3),
                  Wrap(
                    spacing: FactorySpacing.space2,
                    runSpacing: FactorySpacing.space2,
                    children: [
                      FactoryChip(
                        label: l10n.filterAll,
                        selected: _area == null,
                        onTap: () => setState(() => _area = null),
                      ),
                      FactoryChip(
                        label: l10n.navBusinesses,
                        selected: _area == AuditArea.businesses,
                        onTap: () => setState(() => _area = AuditArea.businesses),
                      ),
                      FactoryChip(
                        label: l10n.navCatalog,
                        selected: _area == AuditArea.catalog,
                        onTap: () => setState(() => _area = AuditArea.catalog),
                      ),
                      FactoryChip(
                        label: l10n.navStaff,
                        selected: _area == AuditArea.staff,
                        onTap: () => setState(() => _area = AuditArea.staff),
                      ),
                    ],
                  ),
                  const SizedBox(height: FactorySpacing.space4),
                  if (visible.isEmpty)
                    FactoryEmptyState(icon: Icons.search_off_rounded, title: l10n.noMatches, message: '')
                  else
                    for (final entry in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                        child: _EntryTile(
                          entry: entry,
                          locale: locale,
                          targetName: entry.targetType == 'PROVIDER' ? businessNames[entry.targetId] : null,
                        ),
                      ),
                  // A full page means there may be older entries.
                  if (entries.length >= _size)
                    Padding(
                      padding: const EdgeInsets.only(top: FactorySpacing.space2),
                      child: FactoryButton(
                        label: l10n.showMore,
                        variant: FactoryButtonVariant.secondary,
                        onPressed: () => setState(() => _size += _pageSize),
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
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.locale, this.targetName});

  final AuditEntry entry;
  final String locale;
  final String? targetName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final change = (entry.previousValue != null || entry.newValue != null)
        ? '${auditValueLabel(l10n, entry.previousValue)} → ${auditValueLabel(l10n, entry.newValue)}'
        : null;
    final reason = entry.reason;
    return FactorySelectableTile(
      title: auditActionLabel(l10n, entry.action),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (targetName != null) Text(targetName!),
          Text(l10n.activityBy(entry.actorEmail)),
          if (change != null) Text(change),
          if (reason != null && reason.isNotEmpty) Text('“$reason”'),
        ],
      ),
      trailing: Text(formatDateTime(locale, entry.createdAt), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
