import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/models/vehicle.dart';
import '../providers/auto_providers.dart';
import '../widgets/add_vehicle_dialog.dart';

/// Only ever pushed from Profile while logged in — the vehicles it manages
/// have no meaning for a logged-out caller, unlike Favorites/Bookings which
/// are reachable directly from the bottom nav and so need their own
/// logged-out handling.
class VehiclesScreen extends ConsumerWidget {
  final String userId;

  const VehiclesScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final vehiclesAsync = ref.watch(vehiclesProvider(userId));

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(l10n.vehiclesScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addVehicleButton,
            onPressed: () => _addVehicle(context, ref),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(
              child: FactoryEmptyState(
                icon: Icons.directions_car_outlined,
                title: l10n.vehiclesEmptyTitle,
                message: l10n.vehiclesEmptyMessage,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space3),
            itemBuilder: (context, index) => _VehicleTile(
              vehicle: vehicles[index],
              onDelete: () => _deleteVehicle(context, ref, vehicles[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            child: FactoryErrorState(
              message: l10n.errorVehiclesLoadFailed,
              onRetry: () => ref.invalidate(vehiclesProvider(userId)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addVehicle(BuildContext context, WidgetRef ref) async {
    final result = await showAddVehicleDialog(context);
    if (result == null) return;
    await ref.read(autoApiProvider).registerVehicle(
          ownerUserId: userId,
          make: result.make,
          model: result.model,
          year: result.year,
          licensePlate: result.licensePlate,
        );
    ref.invalidate(vehiclesProvider(userId));
  }

  Future<void> _deleteVehicle(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteVehicleConfirmTitle),
        content: Text(l10n.deleteVehicleConfirmMessage(vehicle.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.addVehicleCancelButton)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.deleteVehicleButton)),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(autoApiProvider).deleteVehicle(vehicle.id);
    ref.invalidate(vehiclesProvider(userId));
  }
}

class _VehicleTile extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onDelete;

  const _VehicleTile({required this.vehicle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return FactorySelectableTile(
      title: vehicle.displayName,
      subtitle: Text(vehicle.licensePlate, style: FactoryTypography.mono(size: 13, color: colors.textTertiary)),
      leading: Icon(Icons.directions_car_rounded, color: colors.textSecondary),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.deleteVehicleButton,
        onPressed: onDelete,
      ),
    );
  }
}
