import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// "Step 2 of 2" with a progress bar, and — once a phone number has been
/// entered — that number with a way back to change it. Every phone sign-in /
/// linking flow is two steps (number, then code or password), so a user who
/// mistyped the number is never stranded on step 2.
class AuthStepHeader extends StatelessWidget {
  const AuthStepHeader({
    super.key,
    required this.step,
    this.total = 2,
    this.phone,
    this.onChangePhone,
  });

  final int step;
  final int total;

  /// Shown with a "Change number" action when both this and [onChangePhone]
  /// are given.
  final String? phone;
  final VoidCallback? onChangePhone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Theme colors only: the auth screens are also exercised under a plain
    // MaterialApp, and this header should look right either way.
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: FactorySpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.authStepLabel(step, total),
            style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: FactorySpacing.space2),
          ClipRRect(
            borderRadius: FactoryRadius.smRadius,
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
          if (phone != null && onChangePhone != null) ...[
            const SizedBox(height: FactorySpacing.space2),
            // A Wrap, not a Row: with a large font on a narrow phone the button moves under the number
            // instead of running off the screen.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(phone!, style: textTheme.titleSmall),
                TextButton(onPressed: onChangePhone, child: Text(l10n.authChangeNumber)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
