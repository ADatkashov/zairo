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

class SalonDetailScreen extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const SalonDetailScreen({super.key, required this.provider});

  @override
  ConsumerState<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends ConsumerState<SalonDetailScreen> {
  late AdminProvider _provider = widget.provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_provider.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit salon',
            onPressed: () async {
              final updated = await showDialog<AdminProvider>(
                context: context,
                builder: (_) => _EditSalonDialog(provider: _provider),
              );
              if (updated != null) {
                setState(() => _provider = updated);
                ref.invalidate(myProvidersProvider(_provider.ownerUserId));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${_provider.vertical} — ${_provider.status}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _ServicesSection(providerId: _provider.id),
          const SizedBox(height: 24),
          _AvailabilitySection(providerId: _provider.id),
          if (_provider.vertical == 'beauty') ...[
            const SizedBox(height: 24),
            _MastersSection(providerId: _provider.id),
          ],
          const SizedBox(height: 24),
          _BookingsSection(providerId: _provider.id),
        ],
      ),
    );
  }
}

/// Owner-editable fields only — vertical and status aren't here on purpose,
/// see backend's Provider.update() for why.
class _EditSalonDialog extends ConsumerStatefulWidget {
  final AdminProvider provider;

  const _EditSalonDialog({required this.provider});

  @override
  ConsumerState<_EditSalonDialog> createState() => _EditSalonDialogState();
}

class _EditSalonDialogState extends ConsumerState<_EditSalonDialog> {
  late final _nameController = TextEditingController(text: widget.provider.name);
  late final _latController = TextEditingController(text: widget.provider.latitude?.toString() ?? '');
  late final _lngController = TextEditingController(text: widget.provider.longitude?.toString() ?? '');
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit salon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(labelText: 'Salon name'),
          ),
          TextField(
            controller: _latController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Latitude (optional)'),
          ),
          TextField(
            controller: _lngController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Longitude (optional)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a salon name');
      return;
    }
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    final lat = latText.isEmpty ? null : double.tryParse(latText);
    final lng = lngText.isEmpty ? null : double.tryParse(lngText);
    if ((latText.isNotEmpty && lat == null) || (lngText.isNotEmpty && lng == null)) {
      setState(() => _error = 'Latitude/longitude must be valid numbers');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final updated = await ref.read(salonAdminApiProvider).updateProvider(
            providerId: widget.provider.id,
            name: name,
            latitude: lat,
            longitude: lng,
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() {
        _error = 'Failed to save salon: $e';
        _isSubmitting = false;
      });
    }
  }
}

class _ServicesSection extends ConsumerWidget {
  final String providerId;

  const _ServicesSection({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showInactive = ref.watch(showInactiveServicesProvider(providerId));
    final servicesAsync = ref.watch(providerServicesProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(providerServicesProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () =>
                      ref.read(showInactiveServicesProvider(providerId).notifier).state = !showInactive,
                  child: Text(showInactive ? 'Hide removed' : 'Show removed'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: () async {
                    final added = await showDialog<bool>(
                      context: context,
                      builder: (_) => AddServiceDialog(providerId: providerId),
                    );
                    if (added == true) refresh();
                  },
                ),
              ],
            ),
          ],
        ),
        servicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return Text(showInactive ? 'No services yet.' : 'No active services.');
            }
            return Column(
              children: services
                  .map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.title, style: s.active ? null : const TextStyle(color: Colors.grey)),
                        subtitle: Text('${s.durationMinutes} min — \$${s.price.toStringAsFixed(2)}'
                            '${s.active ? '' : ' — removed'}'),
                        trailing: s.active
                            ? Row(
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
                                      if (saved == true) refresh();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove',
                                    onPressed: () async {
                                      await ref.read(salonAdminApiProvider).deactivateService(s.id);
                                      refresh();
                                    },
                                  ),
                                ],
                              )
                            : TextButton(
                                onPressed: () async {
                                  await ref.read(salonAdminApiProvider).reactivateService(s.id);
                                  refresh();
                                },
                                child: const Text('Reactivate'),
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
    final showInactive = ref.watch(showInactiveMastersProvider(providerId));
    final mastersAsync = ref.watch(adminMastersProvider((providerId, showInactive)));
    void refresh() => ref.invalidate(adminMastersProvider((providerId, showInactive)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Masters', style: Theme.of(context).textTheme.titleMedium),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () =>
                      ref.read(showInactiveMastersProvider(providerId).notifier).state = !showInactive,
                  child: Text(showInactive ? 'Hide removed' : 'Show removed'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: () async {
                    final added = await showDialog<bool>(
                      context: context,
                      builder: (_) => AddMasterDialog(providerId: providerId),
                    );
                    if (added == true) refresh();
                  },
                ),
              ],
            ),
          ],
        ),
        mastersAsync.when(
          data: (masters) {
            if (masters.isEmpty) {
              return Text(showInactive ? 'No masters yet.' : 'No active masters.');
            }
            return Column(
              children: masters
                  .map((m) => Card(
                        child: ListTile(
                          title: Text(m.displayName, style: m.active ? null : const TextStyle(color: Colors.grey)),
                          subtitle: Text([
                            if (m.bio != null) m.bio!,
                            if (!m.active) 'removed',
                          ].join(' — ')),
                          trailing: m.active
                              ? Row(
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
                                        refresh();
                                      },
                                    ),
                                  ],
                                )
                              : TextButton(
                                  onPressed: () async {
                                    await ref.read(beautyAdminApiProvider).reactivateMaster(m.id);
                                    refresh();
                                  },
                                  child: const Text('Reactivate'),
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
