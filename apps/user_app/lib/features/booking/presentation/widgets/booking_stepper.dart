import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';

/// Where the customer is in "service -> time -> confirm". [step] is the
/// zero-based current step: the ones before it show a check, the current one
/// is ringed, the rest are muted. A [step] of [count] means every step is done
/// (the booking is confirmed): all checks, no current step. State is never colour alone: done steps have
/// a check mark and the current one is bold, and the whole bar reads aloud as
/// "Step 2 of 3: Time".
class BookingStepper extends StatelessWidget {
  const BookingStepper({super.key, required this.step});

  final int step;

  static const int count = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.bookingStepService,
      l10n.bookingStepTime,
      l10n.bookingStepConfirm,
    ];
    final allDone = step >= count;
    final current = step.clamp(0, count - 1);

    return Semantics(
      label: allDone
          ? l10n.bookingStepsDone
          : l10n.bookingStepSemantic(current + 1, count, labels[current]),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0)
              Expanded(child: _Connector(done: allDone || i <= current)),
            // Steps shrink (their label ellipsizes) before the connectors do:
            // a long label in another language must not overflow a small phone.
            Flexible(
              flex: 3,
              child: _Step(
                index: i,
                label: labels[i],
                state: allDone || i < current
                    ? _State.done
                    : (i == current ? _State.current : _State.upcoming),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _State { done, current, upcoming }

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.label, required this.state});

  final int index;
  final String label;
  final _State state;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final done = state == _State.done;
    final current = state == _State.current;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: FactoryMotion.resolve(context, FactoryMotion.base),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? colors.primary
                : (current ? colors.primaryTint : Colors.transparent),
            border: Border.all(
              color: done || current ? colors.primary : colors.borderStrong,
              width: 1.5,
            ),
          ),
          child: done
              ? Icon(
                  Symbols.check_rounded,
                  size: 14,
                  weight: 700,
                  color: colors.onPrimary,
                )
              : Text(
                  '${index + 1}',
                  style: FactoryTypography.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: current ? colors.primaryStrong : colors.textTertiary,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: current
                  ? colors.text
                  : (done ? colors.textSecondary : colors.textTertiary),
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: done ? colors.primary : colors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
