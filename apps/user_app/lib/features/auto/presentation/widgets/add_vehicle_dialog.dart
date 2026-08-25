import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

class AddVehicleResult {
  final String make;
  final String model;
  final int year;
  final String licensePlate;

  const AddVehicleResult({
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
  });
}

/// Returns null if the user cancels.
Future<AddVehicleResult?> showAddVehicleDialog(BuildContext context) {
  return showDialog<AddVehicleResult>(
    context: context,
    builder: (_) => const _AddVehicleDialog(),
  );
}

class _AddVehicleDialog extends StatefulWidget {
  const _AddVehicleDialog();

  @override
  State<_AddVehicleDialog> createState() => _AddVehicleDialogState();
}

class _AddVehicleDialogState extends State<_AddVehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  final _licensePlateController = TextEditingController();

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addVehicleDialogTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _makeController,
              decoration: InputDecoration(labelText: l10n.vehicleMakeLabel),
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
            TextFormField(
              controller: _modelController,
              decoration: InputDecoration(labelText: l10n.vehicleModelLabel),
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
            TextFormField(
              controller: _yearController,
              decoration: InputDecoration(labelText: l10n.vehicleYearLabel),
              keyboardType: TextInputType.number,
              validator: (value) => int.tryParse(value ?? '') == null ? l10n.addVehicleYearInvalid : null,
            ),
            TextFormField(
              controller: _licensePlateController,
              decoration: InputDecoration(labelText: l10n.vehicleLicensePlateLabel),
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.addVehicleCancelButton),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(
              AddVehicleResult(
                make: _makeController.text.trim(),
                model: _modelController.text.trim(),
                year: int.parse(_yearController.text.trim()),
                licensePlate: _licensePlateController.text.trim(),
              ),
            );
          },
          child: Text(l10n.addVehicleButton),
        ),
      ],
    );
  }
}
