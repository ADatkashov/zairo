import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../data/models/platform_admin_session.dart';
import '../platform_admin_labels.dart';
import '../providers/platform_admin_providers.dart';
import '../widgets/platform_admin_common.dart';

/// The console's path to business moderation — the same Provider resource the
/// ADMIN-role ModerationScreen moderates, reachable by PLATFORM_ADMIN and
/// PLATFORM_MODERATOR. PLATFORM_SUPPORT sees the list (any platform role can
/// read it) but gets no action buttons — it stays read-only by design.
///
/// Businesses waiting for approval come first, with a banner that filters
/// down to them; the rest can be searched by name and filtered by status.
class PlatformAdminBusinessesTab extends ConsumerStatefulWidget {
  const PlatformAdminBusinessesTab({super.key, required this.session});

  final PlatformAdminSession session;

  @override
  ConsumerState<PlatformAdminBusinessesTab> createState() => _PlatformAdminBusinessesTabState();
}

class _PlatformAdminBusinessesTabState extends ConsumerState<PlatformAdminBusinessesTab> {
  final _searchController = TextEditingController();
  String _query = '';

  /// null = every status.
  String? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _token => widget.session.accessToken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final businessesAsync = ref.watch(platformBusinessesProvider(_token));
    Future<void> refresh() => ref.refresh(platformBusinessesProvider(_token).future);

    return businessesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          PlatformLoadError(onRetry: () => ref.invalidate(platformBusinessesProvider(_token))),
      data: (businesses) {
        if (businesses.isEmpty) {
          return PlatformEmptyState(
            icon: Icons.storefront_outlined,
            title: l10n.paBusinessesEmptyTitle,
            message: l10n.paBusinessesEmptyMessage,
            onRefresh: refresh,
          );
        }

        final pendingCount = businesses.where((b) => b.status == 'PENDING').length;
        final needle = _query.trim().toLowerCase();
        final visible =
            businesses.where((b) {
                if (_statusFilter != null && b.status != _statusFilter) return false;
                return needle.isEmpty || b.name.toLowerCase().contains(needle);
              }).toList()
              // Awaiting approval first, then A-Z.
              ..sort((a, b) {
                final byPending = (b.status == 'PENDING' ? 1 : 0) - (a.status == 'PENDING' ? 1 : 0);
                return byPending != 0 ? byPending : a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

        return PlatformContentFrame(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(FactorySpacing.space4),
              children: [
                if (pendingCount > 0 && _statusFilter != 'PENDING') ...[
                  _PendingBanner(count: pendingCount, onShow: () => setState(() => _statusFilter = 'PENDING')),
                  const SizedBox(height: FactorySpacing.space3),
                ],
                FactorySearchField(
                  controller: _searchController,
                  hint: l10n.paBusinessesSearchHint,
                  onChanged: (value) => setState(() => _query = value),
                  onCleared: () => setState(() => _query = ''),
                  clearSemanticLabel: l10n.customerListSearchClear,
                ),
                const SizedBox(height: FactorySpacing.space3),
                Wrap(
                  spacing: FactorySpacing.space2,
                  runSpacing: FactorySpacing.space2,
                  children: [
                    FactoryChip(
                      label: l10n.paFilterAll,
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                    for (final status in const ['PENDING', 'ACTIVE', 'SUSPENDED'])
                      FactoryChip(
                        label: platformStatusLabel(l10n, status),
                        selected: _statusFilter == status,
                        onTap: () => setState(() => _statusFilter = status),
                      ),
                  ],
                ),
                const SizedBox(height: FactorySpacing.space4),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space6),
                    child: Center(
                      child: FactoryEmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.paBusinessesNoMatch,
                        message: '',
                      ),
                    ),
                  )
                else
                  for (final business in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                      child: _BusinessCard(
                        business: business,
                        canModerate: widget.session.canModerateBusinesses,
                        onChangeStatus: (next) => _changeStatus(business, next),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeStatus(AdminProvider business, String nextStatus) async {
    final l10n = AppLocalizations.of(context)!;
    // Suspending hides a business from customer search and stops it taking
    // bookings — never a single tap, unlike approving a still-invisible
    // PENDING business into view.
    if (nextStatus == 'SUSPENDED') {
      final confirmed = await confirmPlatformAction(
        context,
        title: l10n.paSuspendTitle(business.name),
        message: l10n.paSuspendMessage,
        confirmLabel: l10n.suspendButton,
      );
      if (!confirmed || !mounted) return;
    }
    try {
      await ref.read(platformBusinessApiProvider).setStatus(_token, business.id, nextStatus);
      ref.invalidate(platformBusinessesProvider(_token));
      if (!mounted) return;
      showPlatformSnack(context, switch ((business.status, nextStatus)) {
        (_, 'SUSPENDED') => l10n.paBusinessSuspended(business.name),
        ('SUSPENDED', _) => l10n.paBusinessReinstated(business.name),
        _ => l10n.paBusinessApproved(business.name),
      });
    } catch (_) {
      if (mounted) showPlatformSnack(context, l10n.paActionFailed);
    }
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onShow});

  final int count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    return Material(
      color: colors.accentTint,
      borderRadius: FactoryRadius.mdRadius,
      child: InkWell(
        borderRadius: FactoryRadius.mdRadius,
        onTap: onShow,
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space3),
          child: Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: colors.text),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Text(
                  l10n.paBusinessesPendingBanner(count),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.text),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business, required this.canModerate, required this.onChangeStatus});

  final AdminProvider business;
  final bool canModerate;
  final ValueChanged<String> onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    final actions = <Widget>[
      if (canModerate && business.status == 'PENDING')
        FactoryButton(label: l10n.approveButton, onPressed: () => onChangeStatus('ACTIVE')),
      if (canModerate && business.status == 'SUSPENDED')
        FactoryButton(label: l10n.paReinstateButton, onPressed: () => onChangeStatus('ACTIVE')),
      if (canModerate && business.status != 'SUSPENDED')
        FactoryButton(
          label: l10n.suspendButton,
          variant: FactoryButtonVariant.textDanger,
          onPressed: () => onChangeStatus('SUSPENDED'),
        ),
    ];

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FactoryAvatar(
                initials: initialsFor(business.name),
                image: business.coverPhotoUrl != null ? NetworkImage(business.coverPhotoUrl!) : null,
              ),
              const SizedBox(width: FactorySpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(business.name, style: textTheme.titleSmall?.copyWith(color: colors.text)),
                    const SizedBox(height: 2),
                    Text(
                      platformVerticalLabel(l10n, business.vertical),
                      style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FactorySpacing.space2),
              PlatformStatusBadge(status: business.status),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space3),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space2,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
