import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/labels.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/business.dart';

/// Below this width the businesses list stays a stack of cards; at or above
/// it the same data reads as a table (name, type, registered, status,
/// actions) so more rows fit and columns can be scanned.
const double businessesTableMinWidth = 640;

/// Width of the trailing actions column: room for "Approve" + "Suspend".
const double _actionsWidth = 200;

/// Dense moderation table. Rows open the business; the actions column holds
/// the same approve / reinstate / suspend buttons the card layout has.
class BusinessesTable extends StatelessWidget {
  const BusinessesTable({
    super.key,
    required this.businesses,
    required this.canModerate,
    required this.onOpen,
    required this.onChangeStatus,
  });

  final List<Business> businesses;
  final bool canModerate;
  final ValueChanged<Business> onOpen;
  final void Function(Business business, String next) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final radius = context.factoryProfileOrNull?.cardBorderRadius ?? FactoryRadius.mdRadius;
    final rowHeight = context.factoryProfileOrNull?.rowHeight ?? 44;

    final headerStyle = textTheme.labelSmall?.copyWith(color: colors.textTertiary);

    Widget header() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(l10n.businessesColName.toUpperCase(), style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n.businessesColType.toUpperCase(), style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n.businessesColRegistered.toUpperCase(), style: headerStyle)),
          Expanded(flex: 2, child: Text(l10n.businessesColStatus.toUpperCase(), style: headerStyle)),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );

    Widget row(Business business) {
      final actions = <Widget>[
        if (canModerate && business.status == 'PENDING')
          FactoryButton(label: l10n.approve, onPressed: () => onChangeStatus(business, 'ACTIVE')),
        if (canModerate && business.status == 'SUSPENDED')
          FactoryButton(label: l10n.reinstate, onPressed: () => onChangeStatus(business, 'ACTIVE')),
        if (canModerate && business.status != 'SUSPENDED')
          FactoryButton(
            label: l10n.suspend,
            variant: FactoryButtonVariant.textDanger,
            onPressed: () => onChangeStatus(business, 'SUSPENDED'),
          ),
      ];
      return InkWell(
        onTap: () => onOpen(business),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space1),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      FactoryAvatar(
                        initials: initialsFor(business.name),
                        size: FactoryAvatarSize.sm,
                        image: business.coverPhotoUrl != null ? NetworkImage(business.coverPhotoUrl!) : null,
                      ),
                      const SizedBox(width: FactorySpacing.space3),
                      Expanded(
                        child: Text(
                          business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    verticalLabel(l10n, business.vertical),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    business.createdAt == null ? '—' : formatDate(locale, business.createdAt!),
                    style: FactoryTypography.mono(size: 13, weight: FontWeight.w500, color: colors.textSecondary),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ToneBadge(
                      label: businessStatusLabel(l10n, business.status),
                      tone: businessStatusTone(business.status),
                    ),
                  ),
                ),
                SizedBox(
                  width: _actionsWidth,
                  child: Wrap(alignment: WrapAlignment.end, spacing: FactorySpacing.space1, children: actions),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              header(),
              for (final business in businesses) ...[Divider(height: 1, color: colors.border), row(business)],
            ],
          ),
        ),
      ),
    );
  }
}
