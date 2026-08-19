import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../discovery/data/models/provider_search_result.dart';
import '../../data/booking_exception.dart';
import '../../data/models/availability_slot.dart';
import '../providers/booking_providers.dart';

class ProviderDetailScreen extends ConsumerStatefulWidget {
  final ProviderSearchResult provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  String? _selectedServiceId;
  String? _selectedSlotId;
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(availabilitySlotsProvider(widget.provider.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.provider.vertical, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Services', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _selectedServiceId,
            onChanged: (value) => setState(() => _selectedServiceId = value),
            child: Column(
              children: widget.provider.services
                  .map(
                    (service) => RadioListTile<String>(
                      value: service.id,
                      title: Text(service.title),
                      subtitle: Text(
                          '${service.durationMinutes} min — \$${service.price.toStringAsFixed(2)}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Available times', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          slotsAsync.when(
            data: (slots) {
              final openSlots = slots.where((s) => s.isOpen).toList();
              if (openSlots.isEmpty) {
                return const Text('No open time slots right now.');
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: openSlots.map((slot) => _SlotChip(
                      slot: slot,
                      selected: _selectedSlotId == slot.id,
                      onSelected: () => setState(() => _selectedSlotId = slot.id),
                    )).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text('Failed to load availability: $error'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_selectedServiceId != null && _selectedSlotId != null && !_isBooking)
                ? _book
                : null,
            child: _isBooking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Book'),
          ),
        ],
      ),
    );
  }

  Future<void> _book() async {
    // Reads authControllerProvider.future rather than a synchronous
    // .value snapshot: if this is the first time anything has touched
    // authControllerProvider (e.g. the user never opened the Profile tab),
    // .value would race the AsyncNotifier's still-in-flight session
    // restore and wrongly read as "logged out" — caught by a flaky
    // widget test, see provider_detail_screen_test.dart.
    setState(() => _isBooking = true);
    final currentUser = await ref.read(authControllerProvider.future);
    if (currentUser == null) {
      setState(() => _isBooking = false);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final service = widget.provider.services.firstWhere((s) => s.id == _selectedServiceId);
    try {
      await ref.read(bookingApiProvider).createBooking(
            userId: currentUser.id,
            serviceId: service.id,
            availabilitySlotId: _selectedSlotId!,
            totalPrice: service.price,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking confirmed!')),
      );
      Navigator.of(context).pop();
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      ref.invalidate(availabilitySlotsProvider(widget.provider.id));
      setState(() {
        _selectedSlotId = null;
        _isBooking = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      setState(() => _isBooking = false);
    }
  }
}

class _SlotChip extends StatelessWidget {
  final AvailabilitySlot slot;
  final bool selected;
  final VoidCallback onSelected;

  const _SlotChip({required this.slot, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_formatSlot(slot.startsAt.toLocal())),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatSlot(DateTime dt) {
    final month = _months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month ${dt.day}, $hour:$minute';
  }
}
