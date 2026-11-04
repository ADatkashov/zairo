import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/formatting/opening_hours.dart';
import '../../../../core/links/external_links.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../discovery/data/models/provider_search_result.dart';

/// What a customer wants to know before booking, right under the business name: is it open, where is it, how to
/// reach it, what is it. The two actions people actually take (call, get directions) are one tap each; the weekly
/// hours open on a tap of the status line. Renders nothing when the owner has filled in none of it.
class ProviderInfoSection extends StatefulWidget {
  const ProviderInfoSection({super.key, required this.provider, this.now});

  final ProviderSearchResult provider;

  /// The moment "open now" is judged at; the clock by default (tests pass a fixed one).
  final DateTime Function()? now;

  @override
  State<ProviderInfoSection> createState() => _ProviderInfoSectionState();
}

class _ProviderInfoSectionState extends State<ProviderInfoSection> {
  bool _hoursExpanded = false;
  bool _descriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final description = provider.description;
    final address = provider.address;
    final phone = provider.phone;
    final hours = provider.workingHours;
    final hasCoords = provider.latitude != null && provider.longitude != null;
    final hasHours = openingDayKeys.any((d) => hoursOf(hours, d) != null);
    if (description == null && address == null && phone == null && !hasHours) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    final children = <Widget>[];
    if (hasHours) {
      final status = openingStatus(hours, (widget.now ?? DateTime.now)());
      children.add(
        InkWell(
          onTap: () => setState(() => _hoursExpanded = !_hoursExpanded),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(
                  Symbols.schedule_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: FactorySpacing.space2),
                Expanded(
                  child: Text(
                    _statusText(l10n, locale, status),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: status.state == OpeningState.open
                          ? colors.primaryStrong
                          : colors.text,
                    ),
                  ),
                ),
                Icon(
                  _hoursExpanded
                      ? Symbols.expand_less_rounded
                      : Symbols.expand_more_rounded,
                  size: 20,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      );
      if (_hoursExpanded) {
        children.add(
          _WeekHours(
            hours: hours,
            locale: locale,
            today: (widget.now ?? DateTime.now)().weekday - 1,
          ),
        );
      }
    }
    if (address != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.location_on_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(child: Text(address, style: textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }
    if (description != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: FactorySpacing.space1),
          child: _Description(
            text: description,
            expanded: _descriptionExpanded,
            onToggle: () =>
                setState(() => _descriptionExpanded = !_descriptionExpanded),
          ),
        ),
      );
    }
    if (phone != null || (address != null && hasCoords)) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: FactorySpacing.space2),
          child: Wrap(
            spacing: FactorySpacing.space2,
            runSpacing: FactorySpacing.space2,
            children: [
              if (phone != null)
                FactoryButton(
                  variant: FactoryButtonVariant.secondary,
                  icon: Symbols.call_rounded,
                  label: l10n.providerCallButton,
                  onPressed: () => launchUrl(ExternalLinks.call(phone)),
                ),
              if (hasCoords)
                FactoryButton(
                  variant: FactoryButtonVariant.secondary,
                  icon: Symbols.directions_rounded,
                  label: l10n.providerDirectionsButton,
                  onPressed: () => launchUrl(
                    ExternalLinks.directionsTo(
                      latitude: provider.latitude!,
                      longitude: provider.longitude!,
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: FactorySpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static String _statusText(
    AppLocalizations l10n,
    String locale,
    OpeningStatus status,
  ) {
    final time = status.time ?? '';
    return switch (status.state) {
      OpeningState.open => l10n.providerOpenUntil(time),
      OpeningState.closed => switch (status.daysAhead) {
        0 => l10n.providerClosedOpensToday(time),
        1 => l10n.providerClosedOpensTomorrow(time),
        _ => l10n.providerClosedOpensOn(_dayName(locale, status.dayKey!), time),
      },
      OpeningState.unknown => '',
    };
  }
}

/// Short weekday name in [locale]; 2024-01-01 is a Monday, so the key's index is the day offset.
String _dayName(String locale, String dayKey) =>
    DateFormat.E(locale)
        .format(DateTime(2024, 1, 1 + openingDayKeys.indexOf(dayKey)));

class _WeekHours extends StatelessWidget {
  const _WeekHours({
    required this.hours,
    required this.locale,
    required this.today,
  });

  final Map<String, String> hours;
  final String locale;
  final int today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: FactorySpacing.space2),
      child: Column(
        children: [
          for (var i = 0; i < openingDayKeys.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dayName(locale, openingDayKeys[i]),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: i == today
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    _range(l10n, openingDayKeys[i]),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: i == today
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: hoursOf(hours, openingDayKeys[i]) == null
                          ? colors.textTertiary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _range(AppLocalizations l10n, String key) {
    final range = hoursOf(hours, key);
    return range == null
        ? l10n.providerDayClosed
        : '${range.start}–${range.end}';
  }
}

class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  /// Short descriptions need no toggle; this is roughly three lines on a phone.
  static const _collapsedChars = 140;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.factoryColors;
    final long = text.length > _collapsedChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: long && !expanded ? 3 : null,
          overflow: long && !expanded ? TextOverflow.ellipsis : null,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        if (long)
          InkWell(
            onTap: onToggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  expanded ? l10n.providerReadLess : l10n.providerReadMore,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.primaryStrong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
