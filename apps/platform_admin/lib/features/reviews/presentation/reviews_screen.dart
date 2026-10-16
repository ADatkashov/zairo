import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/formatting/csv.dart';
import '../../../core/network/error_text.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/review_api.dart';
import '../data/review_report.dart';

/// Reviews a business reported: read them, then hide one (it counts nowhere), keep it, or put a hidden one back.
/// Reading is open to every platform role; deciding is for admins and moderators.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  String _status = 'OPEN';

  /// The reports of the open tab, for "Copy as CSV".
  List<ReviewReport> _shown = const [];

  /// Puts the reviews of the open tab on the clipboard as CSV: paste it straight into a spreadsheet.
  Future<void> _copyCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final csv = toCsv(
      const ['id', 'business', 'rating', 'comment', 'status', 'reported', 'report_reason', 'decided'],
      [
        for (final r in _shown)
          [
            r.id,
            r.providerName,
            '${r.rating}',
            r.comment ?? '',
            r.status,
            r.reportedAt?.toUtc().toIso8601String() ?? '',
            r.reportReason ?? '',
            r.decidedAt?.toUtc().toIso8601String() ?? '',
          ],
      ],
    );
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) showSnack(context, l10n.reviewsCsvCopied(_shown.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canDecide = ref.watch(permissionsProvider).canModerateReviews;
    final queue = ref.watch(reviewQueueProvider(_status));
    Future<void> refresh() => ref.refresh(reviewQueueProvider(_status).future);

    return AreaScaffold(
      title: l10n.navReviews,
      actions: [
        if (queue.hasValue)
          IconButton(
            tooltip: l10n.reviewsCopyCsv,
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: _copyCsv,
          ),
        IconButton(tooltip: l10n.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: refresh),
      ],
      body: ContentFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FactorySpacing.space4,
                FactorySpacing.space3,
                FactorySpacing.space4,
                0,
              ),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'OPEN', label: Text(l10n.reviewsTabOpen)),
                  ButtonSegment(value: 'HIDDEN', label: Text(l10n.reviewsTabHidden)),
                  ButtonSegment(value: 'DISMISSED', label: Text(l10n.reviewsTabKept)),
                ],
                selected: {_status},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _status = value.first),
              ),
            ),
            Expanded(
              child: AsyncView<List<ReviewReport>>(
                value: queue,
                onRetry: () => ref.invalidate(reviewQueueProvider(_status)),
                builder: (items) {
                  _shown = items;
                  if (items.isEmpty) {
                    return EmptyView(
                      icon: Icons.rate_review_outlined,
                      title: switch (_status) {
                        'HIDDEN' => l10n.reviewsEmptyHidden,
                        'DISMISSED' => l10n.reviewsEmptyKept,
                        _ => l10n.reviewsEmptyOpen,
                      },
                      message: '',
                      onRefresh: refresh,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(FactorySpacing.space4),
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                            child: _ReviewCard(report: item, canDecide: canDecide, status: _status),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.report, required this.canDecide, required this.status});

  final ReviewReport report;
  final bool canDecide;
  final String status;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(ReviewApi api, String? reason) action,
    String done, {
    String? askReasonTitle,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    String? reason;
    if (askReasonTitle != null) {
      final answer = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(title: askReasonTitle),
      );
      if (answer == null || !context.mounted) return;
      reason = answer;
    }
    try {
      await action(ref.read(reviewApiProvider), reason);
      ref
        ..invalidate(reviewQueueProvider('OPEN'))
        ..invalidate(reviewQueueProvider('HIDDEN'))
        ..invalidate(reviewQueueProvider('DISMISSED'));
      if (context.mounted) showSnack(context, done);
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(l10n, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final small = textTheme.bodySmall?.copyWith(color: colors.textTertiary);

    return FactoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FactoryRatingLabel(
                rating: report.rating.toDouble(),
                semanticLabel: l10n.reviewsRatingSemantic(report.rating),
              ),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(
                child: Text(report.providerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.titleSmall),
              ),
              Text(DateFormat.yMMMd(locale).format(report.createdAt.toLocal()), style: small),
            ],
          ),
          if (report.comment != null && report.comment!.isNotEmpty) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(report.comment!, style: textTheme.bodyMedium),
          ],
          if (report.reportReason != null) ...[
            const SizedBox(height: FactorySpacing.space2),
            Text(l10n.reviewsReportedBecause(report.reportReason!), style: textTheme.bodySmall?.copyWith(color: colors.error)),
          ],
          if (report.decidedAt != null) ...[
            const SizedBox(height: FactorySpacing.space1),
            Text(l10n.reviewsDecidedOn(DateFormat.yMMMd(locale).format(report.decidedAt!.toLocal())), style: small),
          ],
          if (report.isHidden && report.hiddenReason != null) ...[
            const SizedBox(height: FactorySpacing.space1),
            Text(l10n.reviewsHiddenBecause(report.hiddenReason!), style: small),
          ],
          if (canDecide) ...[
            const SizedBox(height: FactorySpacing.space2),
            Wrap(
              spacing: FactorySpacing.space2,
              runSpacing: FactorySpacing.space1,
              children: [
                if (report.isHidden)
                  FactoryButton(
                    label: l10n.reviewsRestore,
                    variant: FactoryButtonVariant.secondary,
                    onPressed: () => _decide(context, ref, (api, r) => api.restore(report.id, reason: r), l10n.reviewsRestored),
                  )
                else ...[
                  FactoryButton(
                    label: l10n.reviewsHide,
                    variant: FactoryButtonVariant.danger,
                    onPressed: () => _decide(
                      context,
                      ref,
                      (api, r) => api.hide(report.id, reason: r),
                      l10n.reviewsHidden,
                      askReasonTitle: l10n.reviewsHideTitle,
                    ),
                  ),
                  if (report.isOpen)
                    FactoryButton(
                      label: l10n.reviewsKeep,
                      variant: FactoryButtonVariant.secondary,
                      onPressed: () => _decide(context, ref, (api, r) => api.dismiss(report.id, reason: r), l10n.reviewsKept),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks for an optional note on hiding a review; pops with the trimmed text (possibly empty), or null on cancel.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: widget.title,
      content: SizedBox(
        width: 400,
        child: FactoryTextField(controller: _reason, label: l10n.reviewsHideReasonLabel, maxLines: 3),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.reviewsHide,
          variant: FactoryButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
        ),
      ],
    );
  }
}
