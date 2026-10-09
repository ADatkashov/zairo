import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/staff_owner_providers.dart';

/// "This master charges more/less for this service": shown only while the business uses per-worker prices.
/// Customers never see a "paid" label — they just see this price when they pick the person.
class WorkerPricesSection extends ConsumerWidget {
  const WorkerPricesSection({super.key, required this.providerId, required this.workerId});

  final String providerId;
  final String workerId;

  Future<void> _edit(BuildContext context, WidgetRef ref, String serviceId, double base, double? current) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: current == null ? '' : _plain(current));
    final result = await showDialog<_PriceChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.workerPricesEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.workerPricesFieldLabel, hintText: _plain(base)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(const _PriceChoice(null)),
            child: Text(l10n.workerPricesUseBase),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (value == null || value < 0) return;
              Navigator.of(dialogContext).pop(_PriceChoice(value));
            },
            child: Text(l10n.workerPricesSave),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(staffOwnerApiProvider).setWorkerPrice(providerId, workerId, serviceId, result.price);
      ref.invalidate(workerPricesProvider((providerId, workerId)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.teamScheduleSaveFailed)));
      }
    }
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final enabled = ref.watch(workforceSettingsProvider(providerId)).value?.workerPricingEnabled ?? false;
    if (!enabled) return const SizedBox.shrink();
    final services = ref.watch(providerServicesProvider((providerId, false))).value ?? const [];
    final prices = ref.watch(workerPricesProvider((providerId, workerId))).value ?? const <String, double>{};
    if (services.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FactorySpacing.space6),
        FactorySectionHeader(title: l10n.workerPricesTitle),
        const SizedBox(height: FactorySpacing.space2),
        Text(l10n.workerPricesHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
        for (final service in services)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(service.title),
            subtitle: prices.containsKey(service.id) ? null : Text(l10n.workerPricesBase),
            trailing: Text(
              '${_plain(prices[service.id] ?? service.price)} ${service.currency}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: () => _edit(context, ref, service.id, service.price, prices[service.id]),
          ),
      ],
    );
  }
}

class _PriceChoice {
  const _PriceChoice(this.price);

  final double? price;
}
