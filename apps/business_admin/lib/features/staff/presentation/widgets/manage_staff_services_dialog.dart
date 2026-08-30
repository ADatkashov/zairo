import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/staff_admin_providers.dart';

/// Checkbox list of every service this business offers; toggling a
/// checkbox links/unlinks that service to the staff member immediately
/// (each toggle is its own network call, not batched behind a Save
/// button) — this is what enforces the staff booking rule server-side
/// (see backend/staff's StaffBookingService).
class ManageStaffServicesDialog extends ConsumerWidget {
  final String providerId;
  final String staffId;

  const ManageStaffServicesDialog({super.key, required this.providerId, required this.staffId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final servicesAsync = ref.watch(providerServicesProvider((providerId, false)));
    final linkedAsync = ref.watch(adminStaffServicesProvider(staffId));

    return FactoryDialog(
      title: l10n.manageStaffServicesDialogTitle,
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
        FactoryButton(
          label: l10n.doneButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref, String serviceId, bool linked) async {
    final api = ref.read(staffAdminApiProvider);
    if (linked) {
      await api.linkService(staffId: staffId, serviceId: serviceId);
    } else {
      await api.unlinkService(staffId: staffId, serviceId: serviceId);
    }
    ref.invalidate(adminStaffServicesProvider(staffId));
  }
}
