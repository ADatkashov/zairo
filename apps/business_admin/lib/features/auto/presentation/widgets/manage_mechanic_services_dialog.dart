import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/auto_admin_providers.dart';

/// Checkbox list of every service this workshop offers; toggling a checkbox
/// links/unlinks that service to the mechanic immediately (each toggle is
/// its own network call, not batched behind a Save button) — this is what
/// enforces the auto booking rule server-side (see
/// backend/vertical-auto's AutoBookingService).
class ManageMechanicServicesDialog extends ConsumerWidget {
  final String providerId;
  final String mechanicId;

  const ManageMechanicServicesDialog({super.key, required this.providerId, required this.mechanicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final servicesAsync = ref.watch(providerServicesProvider((providerId, false)));
    final linkedAsync = ref.watch(adminMechanicServicesProvider(mechanicId));

    return AlertDialog(
      title: Text(l10n.manageMechanicServicesDialogTitle),
      content: servicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return Text(l10n.addServiceFirstMessage);
          }
          final linkedIds = linkedAsync.value?.map((s) => s.serviceId).toSet() ?? const <String>{};
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: services
                .map(
                  (service) => CheckboxListTile(
                    value: linkedIds.contains(service.id),
                    title: Text(service.title),
                    onChanged: (checked) => _toggle(ref, service.id, checked ?? false),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(FactorySpacing.space6),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Text(l10n.errorServicesLoadFailed(error.toString())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.doneButton)),
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref, String serviceId, bool linked) async {
    final api = ref.read(autoAdminApiProvider);
    if (linked) {
      await api.linkService(mechanicId: mechanicId, serviceId: serviceId);
    } else {
      await api.unlinkService(mechanicId: mechanicId, serviceId: serviceId);
    }
    ref.invalidate(adminMechanicServicesProvider(mechanicId));
  }
}
