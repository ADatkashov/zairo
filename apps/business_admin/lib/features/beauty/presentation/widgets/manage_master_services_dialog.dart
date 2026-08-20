import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salon/presentation/providers/salon_providers.dart';
import '../providers/beauty_admin_providers.dart';

/// Checkbox list of every service this salon offers; toggling a checkbox
/// links/unlinks that service to the master immediately (each toggle is
/// its own network call, not batched behind a Save button) — this is what
/// enforces the beauty booking rule server-side (see
/// backend/vertical-beauty's BeautyBookingService).
class ManageMasterServicesDialog extends ConsumerWidget {
  final String providerId;
  final String masterId;

  const ManageMasterServicesDialog({super.key, required this.providerId, required this.masterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(providerServicesProvider((providerId, false)));
    final linkedAsync = ref.watch(adminMasterServicesProvider(masterId));

    return AlertDialog(
      title: const Text('Services this master offers'),
      content: SizedBox(
        width: 360,
        child: servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return const Text('Add a service to this salon first.');
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
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('Failed to load services: $error'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref, String serviceId, bool linked) async {
    final api = ref.read(beautyAdminApiProvider);
    if (linked) {
      await api.linkService(masterId: masterId, serviceId: serviceId);
    } else {
      await api.unlinkService(masterId: masterId, serviceId: serviceId);
    }
    ref.invalidate(adminMasterServicesProvider(masterId));
  }
}
