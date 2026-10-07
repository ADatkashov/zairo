import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/staff_cabinet.dart';
import '../providers/staff_cabinet_providers.dart';

/// The staff member's own cabinet: pick the business they work at, then see and
/// handle only the appointments booked with them (accept, cancel, complete,
/// no-show) and their rating. One person can work at several businesses, so the
/// business switcher is the first thing on the screen.
class StaffCabinetScreen extends ConsumerStatefulWidget {
  const StaffCabinetScreen({super.key});

  @override
  ConsumerState<StaffCabinetScreen> createState() => _StaffCabinetScreenState();
}

class _StaffCabinetScreenState extends ConsumerState<StaffCabinetScreen> {
  String? _selectedStaffId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final memberships = ref.watch(staffMembershipsProvider);

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.staffCabinetTitle),
      body: memberships.when(
        loading: () => const FactoryLoadingState(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.staffCabinetLoadFailed,
              onRetry: () => ref.invalidate(staffMembershipsProvider),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return FactoryEmptyState(
              icon: Symbols.work_rounded,
              title: l10n.staffCabinetEmptyUpcoming,
              message: '',
            );
          }
          final selected = list.firstWhere(
            (m) => m.staffId == _selectedStaffId,
            orElse: () => list.first,
          );
          return Column(
            children: [
              if (list.length > 1)
                _BusinessSwitcher(
                  memberships: list,
                  selectedStaffId: selected.staffId,
                  onSelect: (id) => setState(() => _selectedStaffId = id),
                ),
              Expanded(child: _MembershipView(key: ValueKey(selected.staffId), membership: selected)),
            ],
          );
        },
      ),
    );
  }
}

class _BusinessSwitcher extends StatelessWidget {
  const _BusinessSwitcher({
    required this.memberships,
    required this.selectedStaffId,
    required this.onSelect,
  });

  final List<StaffMembership> memberships;
  final String selectedStaffId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: FactorySpacing.space4,
          vertical: FactorySpacing.space2,
        ),
        itemCount: memberships.length,
        separatorBuilder: (context, index) => const SizedBox(width: FactorySpacing.space2),
        itemBuilder: (context, index) {
          final m = memberships[index];
          final pending = m.pendingCount > 0 ? ' (${m.pendingCount})' : '';
          return FactoryChip(
            label: '${m.providerName}$pending',
            selected: m.staffId == selectedStaffId,
            onTap: () => onSelect(m.staffId),
          );
        },
      ),
    );
  }
}

class _MembershipView extends ConsumerWidget {
  const _MembershipView({super.key, required this.membership});

  final StaffMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _MembershipHeader(membership: membership),
          if (!membership.active)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4, 0, FactorySpacing.space4, FactorySpacing.space2,
              ),
              child: Text(
                l10n.staffCabinetInactiveNotice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          TabBar(
            tabs: [
              Tab(text: l10n.staffCabinetTabUpcoming),
              Tab(text: l10n.staffCabinetTabHistory),
              Tab(text: l10n.staffCabinetTabRating),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AppointmentsList(membership: membership, upcoming: true),
                _AppointmentsList(membership: membership, upcoming: false),
                _RatingView(membership: membership),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipHeader extends StatelessWidget {
  const _MembershipHeader({required this.membership});

  final StaffMembership membership;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final rating = membership.averageRating;

    return Padding(
      padding: const EdgeInsets.all(FactorySpacing.space4),
      child: Row(
        children: [
          FactoryAvatar(
            initials: membership.displayName.isEmpty ? '?' : membership.displayName[0].toUpperCase(),
            size: FactoryAvatarSize.lg,
            image: membership.photoUrl != null ? NetworkImage(membership.photoUrl!) : null,
          ),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(membership.providerName, style: textTheme.titleMedium),
                Text(
                  membership.displayName,
                  style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
                if (rating != null)
                  Row(
                    children: [
                      Icon(Symbols.star_rounded, size: 16, color: colors.warning, fill: 1),
                      const SizedBox(width: 2),
                      Text(
                        '${rating.toStringAsFixed(1)} · ${l10n.staffCabinetReviewsCount(membership.reviewCount)}',
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (membership.pendingCount > 0)
            FactoryBadge(
              label: l10n.staffCabinetPendingBadge(membership.pendingCount),
              variant: FactoryBadgeVariant.limited,
            ),
        ],
      ),
    );
  }
}

class _AppointmentsList extends ConsumerWidget {
  const _AppointmentsList({required this.membership, required this.upcoming});

  final StaffMembership membership;
  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appointments = ref.watch(staffAppointmentsProvider(membership.staffId));

    return appointments.when(
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.staffCabinetLoadFailed,
            onRetry: () => ref.invalidate(staffAppointmentsProvider(membership.staffId)),
          ),
        ),
      ),
      data: (all) {
        final now = DateTime.now();
        bool isUpcoming(StaffAppointment a) =>
            a.endsAt.isAfter(now) && (a.status == 'CONFIRMED' || a.status == 'PENDING_PAYMENT');
        final rows = all.where((a) => isUpcoming(a) == upcoming).toList()
          ..sort((a, b) => upcoming ? a.startsAt.compareTo(b.startsAt) : b.startsAt.compareTo(a.startsAt));

        if (rows.isEmpty) {
          return FactoryEmptyState(
            icon: Symbols.event_available_rounded,
            title: upcoming ? l10n.staffCabinetEmptyUpcoming : l10n.staffCabinetEmptyHistory,
            message: '',
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(staffAppointmentsProvider(membership.staffId));
            ref.invalidate(staffMembershipsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _AppointmentCard(
              staffId: membership.staffId,
              active: membership.active,
              appointment: rows[index],
            ),
          ),
        );
      },
    );
  }
}

class _AppointmentCard extends ConsumerStatefulWidget {
  const _AppointmentCard({required this.staffId, required this.active, required this.appointment});

  final String staffId;
  final bool active;
  final StaffAppointment appointment;

  @override
  ConsumerState<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<_AppointmentCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(StaffCabinetApiAccess api) action) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await action(StaffCabinetApiAccess(ref, widget.staffId, widget.appointment.bookingId));
      ref.invalidate(staffAppointmentsProvider(widget.staffId));
      ref.invalidate(staffMembershipsProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.staffCabinetActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = true,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: l10n.staffCabinetKeepButton,
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FactoryButton(
            label: confirmLabel,
            variant: destructive ? FactoryButtonVariant.danger : FactoryButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final a = widget.appointment;
    final canAct = widget.active && !_busy;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatMonthDayTime(l10n, a.startsAt.toLocal())} – ${formatHourMinute(a.endsAt.toLocal())}',
                  style: textTheme.titleSmall,
                ),
              ),
              FactoryBadge(label: _statusLabel(l10n, a.status), variant: _statusVariant(a.status)),
            ],
          ),
          const SizedBox(height: FactorySpacing.space2),
          if (a.serviceTitle != null) Text(a.serviceTitle!, style: textTheme.bodyLarge),
          Text(
            [
              a.customerName ?? l10n.staffCabinetAnonymousCustomer,
              if (a.customerPhone != null && a.customerPhone!.isNotEmpty) a.customerPhone!,
            ].join(' · '),
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          Text(
            '${a.totalPrice.toStringAsFixed(2)} ${a.currency}',
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (a.status == 'CANCELLED' && a.cancellationReason != null)
            Text(a.cancellationReason!, style: textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          if (a.status == 'CONFIRMED' || a.status == 'PENDING_PAYMENT')
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(
                a.staffDeclinedAt != null
                    ? l10n.staffCabinetDeclinedBadge
                    : a.status != 'CONFIRMED'
                        ? ''
                        : a.staffConfirmedAt == null
                            ? l10n.staffCabinetAwaitingBadge
                            : l10n.staffCabinetAcceptedBadge,
                style: textTheme.bodySmall?.copyWith(
                  color: a.staffDeclinedAt != null || a.staffConfirmedAt != null ? colors.textTertiary : colors.warning,
                ),
              ),
            ),
          if (a.canAccept || a.canDecline || a.canComplete || a.canMarkNoShow)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Wrap(
                spacing: FactorySpacing.space2,
                runSpacing: FactorySpacing.space1,
                children: [
                  if (a.canAccept)
                    FactoryButton(
                      label: l10n.staffCabinetAcceptButton,
                      dense: true,
                      isLoading: _busy,
                      onPressed: canAct ? () => _run((api) => api.accept()) : null,
                    ),
                  if (a.canComplete)
                    FactoryButton(
                      label: l10n.staffCabinetCompleteButton,
                      variant: FactoryButtonVariant.secondary,
                      dense: true,
                      onPressed: canAct ? () => _run((api) => api.complete()) : null,
                    ),
                  if (a.canMarkNoShow)
                    FactoryButton(
                      label: l10n.staffCabinetNoShowButton,
                      variant: FactoryButtonVariant.text,
                      dense: true,
                      onPressed: !canAct
                          ? null
                          : () async {
                              final ok = await _confirm(
                                title: l10n.staffCabinetNoShowConfirmTitle,
                                message: l10n.staffCabinetNoShowConfirmMessage,
                                confirmLabel: l10n.staffCabinetConfirmNoShowButton,
                              );
                              if (ok) await _run((api) => api.markNoShow());
                            },
                    ),
                  if (a.canDecline)
                    FactoryButton(
                      label: l10n.staffCabinetDeclineButton,
                      variant: FactoryButtonVariant.text,
                      dense: true,
                      onPressed: !canAct
                          ? null
                          : () async {
                              final ok = await _confirm(
                                title: l10n.staffCabinetDeclineConfirmTitle,
                                message: l10n.staffCabinetDeclineConfirmMessage,
                                confirmLabel: l10n.staffCabinetConfirmDeclineButton,
                                destructive: false,
                              );
                              if (ok) await _run((api) => api.cannotAttend());
                            },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One appointment's actions, bound to the signed-in staff member's profile.
class StaffCabinetApiAccess {
  StaffCabinetApiAccess(this._ref, this._staffId, this._bookingId);

  final WidgetRef _ref;
  final String _staffId;
  final String _bookingId;

  Future<void> accept() => _ref.read(staffCabinetApiProvider).accept(_staffId, _bookingId);
  Future<void> cannotAttend() => _ref.read(staffCabinetApiProvider).cannotAttend(_staffId, _bookingId);
  Future<void> complete() => _ref.read(staffCabinetApiProvider).complete(_staffId, _bookingId);
  Future<void> markNoShow() => _ref.read(staffCabinetApiProvider).markNoShow(_staffId, _bookingId);
}

String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'CONFIRMED' => l10n.bookingStatusConfirmed,
      'COMPLETED' => l10n.bookingStatusCompleted,
      'CANCELLED' => l10n.bookingStatusCancelled,
      'PENDING_PAYMENT' => l10n.staffCabinetStatusPendingPayment,
      'NO_SHOW' => l10n.staffCabinetStatusNoShow,
      _ => status,
    };

FactoryBadgeVariant _statusVariant(String status) => switch (status) {
      'CONFIRMED' => FactoryBadgeVariant.available,
      'COMPLETED' => FactoryBadgeVariant.verified,
      'CANCELLED' || 'NO_SHOW' => FactoryBadgeVariant.error,
      _ => FactoryBadgeVariant.neutral,
    };

class _RatingView extends ConsumerWidget {
  const _RatingView({required this.membership});

  final StaffMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final rating = ref.watch(staffRatingProvider(membership.staffId));

    return rating.when(
      loading: () => const FactoryLoadingState(),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          child: FactoryErrorState(
            message: l10n.staffCabinetLoadFailed,
            onRetry: () => ref.invalidate(staffRatingProvider(membership.staffId)),
          ),
        ),
      ),
      data: (data) {
        if (data.reviewCount == 0) {
          return FactoryEmptyState(
            icon: Symbols.star_rounded,
            title: l10n.staffCabinetNoReviews,
            message: '',
          );
        }
        final maxCount = data.distribution.fold<int>(1, (m, c) => c > m ? c : m);
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            FactoryCard(
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        (data.averageRating ?? 0).toStringAsFixed(1),
                        style: textTheme.displaySmall,
                      ),
                      Text(
                        l10n.staffCabinetReviewsCount(data.reviewCount),
                        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: FactorySpacing.space4),
                  Expanded(
                    child: Column(
                      children: [
                        for (var stars = 5; stars >= 1; stars--)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(width: 14, child: Text('$stars', style: textTheme.bodySmall)),
                                const SizedBox(width: FactorySpacing.space2),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: (stars <= data.distribution.length ? data.distribution[stars - 1] : 0) /
                                        maxCount,
                                    minHeight: 6,
                                    color: colors.warning,
                                    backgroundColor: colors.border,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FactorySpacing.space3),
            for (final review in data.reviews) ...[
              _ReviewCard(review: review),
              const SizedBox(height: FactorySpacing.space3),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final StaffReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.customerName ?? l10n.staffCabinetAnonymousCustomer,
                  style: textTheme.titleSmall,
                ),
              ),
              for (var i = 1; i <= 5; i++)
                Icon(
                  Symbols.star_rounded,
                  size: 16,
                  fill: i <= review.rating ? 1 : 0,
                  color: i <= review.rating ? colors.warning : colors.border,
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(review.comment!, style: textTheme.bodyMedium),
            ),
          if (review.businessReply != null && review.businessReply!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: FactorySpacing.space2),
              child: Text(
                '${l10n.staffCabinetBusinessReply}: ${review.businessReply}',
                style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: FactorySpacing.space1),
            child: Text(
              formatMonthDayTime(l10n, review.createdAt.toLocal()),
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
