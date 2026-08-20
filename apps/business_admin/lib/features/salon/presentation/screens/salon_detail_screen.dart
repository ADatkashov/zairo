import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../beauty/presentation/providers/beauty_admin_providers.dart';
import '../../../beauty/presentation/widgets/add_master_dialog.dart';
import '../../../beauty/presentation/widgets/add_portfolio_item_dialog.dart';
import '../../../beauty/presentation/widgets/manage_master_services_dialog.dart';
import '../../data/models/admin_provider.dart';
import '../providers/salon_providers.dart';
import '../widgets/add_service_dialog.dart';
import '../widgets/add_slot_dialog.dart';

class SalonDetailScreen extends StatelessWidget {
  final AdminProvider provider;

  const SalonDetailScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(provider.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${provider.vertical} — ${provider.status}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _ServicesSection(providerId: provider.id),
          const SizedBox(height: 24),
          _AvailabilitySection(providerId: provider.id),
          if (provider.vertical == 'beauty') ...[
            const SizedBox(height: 24),
            _MastersSection(providerId: provider.id),
          ],
          const SizedBox(height: 24),
          _BookingsSection(providerId: provider.id),
        ],
      ),
    );
  }
}

class _ServicesSection extends ConsumerWidget {
  final String providerId;

  const _ServicesSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(providerServicesProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => AddServiceDialog(providerId: providerId),
                );
                if (added == true) ref.invalidate(providerServicesProvider(providerId));
              },
            ),
          ],
        ),
        servicesAsync.when(
          data: (services) {
            if (services.isEmpty) return const Text('No services yet.');
            return Column(
              children: services
                  .map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.title),
                        subtitle: Text('${s.durationMinutes} min — \$${s.price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () async {
                                final saved = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AddServiceDialog(providerId: providerId, existing: s),
                                );
                                if (saved == true) ref.invalidate(providerServicesProvider(providerId));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                              onPressed: () async {
                                await ref.read(salonAdminApiProvider).deactivateService(s.id);
                                ref.invalidate(providerServicesProvider(providerId));
                              },
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text('Failed to load services: $error'),
        ),
      ],
    );
  }
}

class _AvailabilitySection extends ConsumerWidget {
  final String providerId;

  const _AvailabilitySection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(providerSlotsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Availability', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => AddSlotDialog(providerId: providerId),
                );
                if (added == true) ref.invalidate(providerSlotsProvider(providerId));
              },
            ),
          ],
        ),
        slotsAsync.when(
          data: (slots) {
            if (slots.isEmpty) return const Text('No time slots yet.');
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              // Only an OPEN slot can be removed (see backend's
              // AvailabilitySlotController.delete()) — a booked one keeps
              // its chip but with no delete affordance.
              children: slots
                  .map((s) => Chip(
                        label: Text('${_formatDateTime(s.startsAt.toLocal())} — ${s.status}'),
                        onDeleted: s.status == 'OPEN'
                            ? () async {
                                await ref.read(salonAdminApiProvider).deleteSlot(s.id);
                                ref.invalidate(providerSlotsProvider(providerId));
                              }
                            : null,
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text('Failed to load availability: $error'),
        ),
      ],
    );
  }
}

class _MastersSection extends ConsumerWidget {
  final String providerId;

  const _MastersSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastersAsync = ref.watch(adminMastersProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Masters', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              onPressed: () async {
                final added = await showDialog<bool>(
                  context: context,
                  builder: (_) => AddMasterDialog(providerId: providerId),
                );
                if (added == true) ref.invalidate(adminMastersProvider(providerId));
              },
            ),
          ],
        ),
        mastersAsync.when(
          data: (masters) {
            if (masters.isEmpty) return const Text('No masters yet.');
            return Column(
              children: masters
                  .map((m) => Card(
                        child: ListTile(
                          title: Text(m.displayName),
                          subtitle: m.bio != null ? Text(m.bio!) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.design_services_outlined),
                                tooltip: 'Services this master offers',
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      ManageMasterServicesDialog(providerId: providerId, masterId: m.id),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_a_photo_outlined),
                                tooltip: 'Add portfolio photo',
                                onPressed: () => showDialog<bool>(
                                  context: context,
                                  builder: (_) => AddPortfolioItemDialog(masterId: m.id),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: 'Remove master',
                                onPressed: () async {
                                  await ref.read(beautyAdminApiProvider).deactivateMaster(m.id);
                                  ref.invalidate(adminMastersProvider(providerId));
                                },
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text('Failed to load masters: $error'),
        ),
      ],
    );
  }
}

class _BookingsSection extends ConsumerWidget {
  final String providerId;

  const _BookingsSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(providerBookingsProvider(providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bookings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        bookingsAsync.when(
          data: (bookings) {
            if (bookings.isEmpty) return const Text('No bookings yet.');
            return Column(
              children: bookings
                  .map((b) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('\$${b.totalPrice.toStringAsFixed(2)} — ${b.status}'),
                        subtitle: Text(_formatDateTime(b.createdAt.toLocal())),
                        trailing: b.status == 'CONFIRMED'
                            ? TextButton(
                                onPressed: () async {
                                  await ref.read(salonAdminApiProvider).completeBooking(b.id);
                                  ref.invalidate(providerBookingsProvider(providerId));
                                },
                                child: const Text('Mark complete'),
                              )
                            : null,
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Text('Failed to load bookings: $error'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, $hour:$minute';
}
