import 'package:core_region/core_region.dart';
import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_typography.dart';

/// Space-groups the integer part of [amount]: 12400 -> "12 400" — the
/// thousands style used throughout the design system for tenge amounts.
/// Deliberately not `NumberFormat` (no `intl` dependency for one rule);
/// a vertical/locale that needs real locale-aware grouping can replace
/// this without touching [FactoryPriceText]'s API.
String formatFactoryAmount(num amount) {
  final wholePart = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < wholePart.length; i++) {
    final fromEnd = wholePart.length - i;
    if (i > 0 && fromEnd % 3 == 0) buffer.write(' ');
    buffer.write(wholePart[i]);
  }
  return amount < 0 ? '-$buffer' : buffer.toString();
}

/// "12 400 ₸" — amount plus the symbol for [currency] (an ISO 4217 code such as
/// "KZT" or "USD"; null falls back to the platform's current market). Use this
/// instead of gluing a raw currency code onto an amount, so every price shows
/// the same symbol for the same currency.
String formatFactoryMoney(num amount, String? currency) {
  final code = (currency == null || currency.isEmpty) ? RegionDefaults.country.currency : currency;
  return '${formatFactoryAmount(amount)} ${currencySymbolFor(code)}';
}

/// Prices, always tabular and monospaced — see FactoryTypography.mono.
/// [prefix] renders in the surrounding body style ("from "), the amount
/// itself always in mono so a list of prices lines up.
class FactoryPriceText extends StatelessWidget {
  const FactoryPriceText({
    super.key,
    required this.amount,
    this.currencySymbol,
    this.prefix,
    this.fontSize = 13,
    this.color,
    this.weight = FontWeight.w600,
  });

  final num amount;

  /// An ISO 4217 code ("KZT", "USD" — what the API returns) or a ready symbol;
  /// a code is resolved to its symbol, so callers can pass `service.currency`
  /// straight through. Defaults to [RegionDefaults.currencySymbol] — the platform's current
  /// (and, for now, only) market — rather than a bare literal, so a caller
  /// that already knows the amount's real currency can override it, and the
  /// "why tenge" question has one named, documented answer instead of a
  /// hardcoded symbol buried in a presentation widget. See the Factory
  /// Country Architecture document's "known debt" section.
  final String? currencySymbol;
  final String? prefix;
  final double fontSize;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final resolvedColor = color ?? colors.text;
    final resolvedSymbol = currencySymbolFor(currencySymbol ?? RegionDefaults.country.currency);
    // FittedBox+scaleDown: a price can be arbitrarily wide (large amounts,
    // long currency codes) and this often sits in a tightly-constrained
    // card footer — shrink slightly rather than hard-overflow if it ever
    // doesn't fit, instead of assuming a width that happens to work today.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (prefix != null)
            Text(prefix!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
          Text(
            '${formatFactoryAmount(amount)} $resolvedSymbol',
            style: FactoryTypography.mono(size: fontSize, weight: weight, color: resolvedColor),
          ),
        ],
      ),
    );
  }
}
