import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_radius.dart';
import '../theme/factory_typography.dart';

enum FactoryTimeSlotState { available, selected, unavailable }

/// One bookable slot — availability is the part of this product the design
/// system cares most about being instantly legible (see the artifact's
/// "Availability" section), so state is carried by shape and color
/// together, never color alone: [FactoryTimeSlotState.unavailable] gets a
/// dashed border and strikethrough text, not just a dimmer fill.
class FactoryTimeSlot extends StatelessWidget {
  const FactoryTimeSlot({super.key, required this.label, this.state = FactoryTimeSlotState.available, this.onTap});

  final String label;
  final FactoryTimeSlotState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final isSelected = state == FactoryTimeSlotState.selected;
    final isUnavailable = state == FactoryTimeSlotState.unavailable;

    final bgColor = isSelected ? colors.primary : colors.surface;
    final fgColor = isSelected ? colors.onPrimary : (isUnavailable ? colors.textTertiary : colors.text);

    // Unavailable is never color-alone: strikethrough text + a disabled tap
    // target carry the state too, not just a muted border.
    return Semantics(
      button: true,
      enabled: !isUnavailable,
      selected: isSelected,
      label: isUnavailable ? '$label, unavailable' : (isSelected ? '$label, selected' : label),
      child: InkWell(
        onTap: isUnavailable ? null : onTap,
        borderRadius: FactoryRadius.smRadius,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: FactoryRadius.smRadius,
            border: Border.all(color: isSelected ? colors.primary : colors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: FactoryTypography.mono(size: 12, weight: isSelected ? FontWeight.w700 : FontWeight.w500, color: fgColor)
                .copyWith(decoration: isUnavailable ? TextDecoration.lineThrough : null),
          ),
        ),
      ),
    );
  }
}
