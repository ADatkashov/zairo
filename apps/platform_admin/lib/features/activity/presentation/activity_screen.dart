import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  /// The entries with a day heading ("Today", "Yesterday", or the date)
  /// before the first entry of each day; [entries] is already newest first.
  List<Widget> _grouped(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
    List<AuditEntry> entries,
    Map<String, String> businessNames,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String label(DateTime day) {
      if (day == today) return l10n.activityToday;
      if (day == DateTime(today.year, today.month, today.day - 1)) return l10n.activityYesterday;
      return formatDate(locale, day);
    }

    final children = <Widget>[];
    DateTime? current;
    for (final entry in entries) {
      final local = entry.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day != current) {
        current = day;
        children.add(_DayHeading(label: label(day)));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
          child: _EntryTile(
            entry: entry,
            locale: locale,
            targetName: entry.targetType == 'PROVIDER' ? businessNames[entry.targetId] : null,
          ),
        ),
      );
    }
    return children;
  }

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
                    ..._grouped(context, l10n, locale, visible, businessNames),
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

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space3, bottom: FactorySpacing.space2),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textTertiary),
      ),
    );
  }
}

/// One change: who did what to what, as a from → to line when a value changed,
/// with the time on the right. Tap to expand the exact time, the target and
/// the entry id (for support questions and bug reports).
class _EntryTile extends StatefulWidget {
  const _EntryTile({required this.entry, required this.locale, this.targetName});

  final AuditEntry entry;
  final String locale;
  final String? targetName;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  static String _initials(String email) {
    final local = email.split('@').first;
    return local.isEmpty ? '?' : local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.mdRadius;
    final hasChange = entry.previousValue != null || entry.newValue != null;
    final reason = entry.reason;
    final mono = FactoryTypography.mono(size: 12, weight: FontWeight.w500, color: colors.textTertiary);

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: colors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FactoryAvatar(initials: _initials(entry.actorEmail), size: FactoryAvatarSize.sm),
                  const SizedBox(width: FactorySpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auditActionLabel(l10n, entry.action), style: textTheme.titleSmall?.copyWith(color: colors.text)),
                        if (widget.targetName != null)
                          Text(widget.targetName!, style: textTheme.bodyMedium?.copyWith(color: colors.text)),
                        Text(l10n.activityBy(entry.actorEmail), style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
                        if (hasChange) ...[
                          const SizedBox(height: FactorySpacing.space1),
                          // One Text so the whole change reads (and is found) as
                          // "from → to"; the old value is muted, the new one bold.
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: auditValueLabel(l10n, entry.previousValue),
                                  style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                                ),
                                TextSpan(text: ' → ', style: textTheme.bodyMedium?.copyWith(color: colors.textTertiary)),
                                TextSpan(
                                  text: auditValueLabel(l10n, entry.newValue),
                                  style: textTheme.bodyMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (reason != null && reason.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: FactorySpacing.space1),
                            child: Text('“$reason”', style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FactorySpacing.space2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat.Hm(widget.locale).format(entry.createdAt.toLocal()), style: mono),
                      Icon(
                        _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: FactorySpacing.space3),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: FactorySpacing.space3),
                _Detail(label: l10n.activityDetailTime, value: formatDateTime(widget.locale, entry.createdAt)),
                if (entry.targetType != null)
                  _Detail(
                    label: l10n.activityDetailTarget,
                    value: '${entry.targetType}${entry.targetId == null ? '' : ' · ${entry.targetId}'}',
                    mono: true,
                  ),
                _Detail(label: l10n.activityDetailEntryId, value: entry.id, mono: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary))),
          Expanded(
            child: SelectableText(
              value,
              style: mono
                  ? FactoryTypography.mono(size: 12, weight: FontWeight.w500, color: colors.textSecondary)
                  : textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
