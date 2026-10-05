import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../platform_admin_labels.dart';
import '../providers/platform_admin_providers.dart';
import '../widgets/platform_admin_common.dart';

/// Every platform-admin change, newest first — readable at a glance: what
/// happened, who did it, and (for status changes) from what to what. Any
/// platform role can read it (PLATFORM_SUPPORT included).
class PlatformAdminActivityTab extends ConsumerWidget {
  const PlatformAdminActivityTab({super.key, required this.platformToken});

  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entriesAsync = ref.watch(platformAuditLogProvider(platformToken));
    Future<void> refresh() => ref.refresh(platformAuditLogProvider(platformToken).future);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          PlatformLoadError(onRetry: () => ref.invalidate(platformAuditLogProvider(platformToken))),
      data: (entries) {
        if (entries.isEmpty) {
          return PlatformEmptyState(
            icon: Icons.history_rounded,
            title: l10n.paActivityEmptyTitle,
            message: l10n.paActivityEmptyMessage,
            onRefresh: refresh,
          );
        }
        return PlatformContentFrame(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(FactorySpacing.space4),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final change = (entry.previousValue != null || entry.newValue != null)
                    ? '${_value(l10n, entry.previousValue)} → ${_value(l10n, entry.newValue)}'
                    : null;
                final reason = entry.reason;
                return FactorySelectableTile(
                  title: platformAuditActionLabel(l10n, entry.action),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.paActivityBy(entry.actorEmail)),
                      if (change != null) Text(change),
                      if (reason != null && reason.isNotEmpty) Text('“$reason”'),
                    ],
                  ),
                  trailing: Text(
                    formatMonthDayTime(l10n, entry.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Status codes get their translated name; anything else shows as is.
  String _value(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return '—';
    const statuses = {'PENDING', 'ACTIVE', 'SUSPENDED', 'INACTIVE', 'ARCHIVED'};
    if (statuses.contains(value)) return platformStatusLabel(l10n, value);
    if (value.startsWith('PLATFORM_')) return platformRoleLabel(l10n, value);
    return value;
  }
}
