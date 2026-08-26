import 'package:core_ui/core_ui.dart';
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
    return FactoryDialog(
      title: l10n.addVehicleDialogTitle,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(
              controller: _makeController,
              label: l10n.vehicleMakeLabel,
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(
              controller: _modelController,
              label: l10n.vehicleModelLabel,
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(
              controller: _yearController,
              label: l10n.vehicleYearLabel,
              keyboardType: TextInputType.number,
              validator: (value) => int.tryParse(value ?? '') == null ? l10n.addVehicleYearInvalid : null,
            ),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(
              controller: _licensePlateController,
              label: l10n.vehicleLicensePlateLabel,
              validator: (value) => (value == null || value.trim().isEmpty) ? l10n.addVehicleFieldRequired : null,
            ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.addVehicleCancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: l10n.addVehicleButton,
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
        ),
      ],
    );
  }
}
