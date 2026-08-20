import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salon/data/models/admin_provider.dart';
import '../../../salon/presentation/providers/salon_providers.dart';

/// ADMIN-only: salons awaiting moderation. Reuses SalonAdminApi rather than
/// a separate admin API class — it's the same Provider resource, just a
/// different, privileged view of it (see backend's
/// ProviderController.updateStatus()).
final pendingProvidersProvider = FutureProvider.autoDispose<List<AdminProvider>>((ref) {
  return ref.watch(salonAdminApiProvider).listProvidersByStatus('PENDING');
});
