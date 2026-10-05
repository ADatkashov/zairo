import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/labels.dart';
import '../../../core/network/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../data/city.dart';
import '../data/city_api.dart';

/// Create or edit a city. A new city's timezone and currency are prefilled
/// from its country; the code is generated from the name and then fixed (it's
/// the city's identifier). Pops with the city's name when saved.
class CityDialog extends ConsumerStatefulWidget {
  const CityDialog({super.key, this.city});

  /// Set when editing.
  final City? city;

  @override
  ConsumerState<CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends ConsumerState<CityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.city?.name);
  late final _nameKk = TextEditingController(text: widget.city?.nameKk);
  late final _code = TextEditingController(text: widget.city?.code);
  late final _timezone = TextEditingController(text: widget.city?.timezone);
  late final _currency = TextEditingController(text: widget.city?.currency);
  late final _latitude = TextEditingController(text: widget.city?.latitude?.toString());
  late final _longitude = TextEditingController(text: widget.city?.longitude?.toString());
  late final _radius = TextEditingController(text: '${widget.city?.radiusKm ?? 50}');
  late String _countryCode = widget.city?.countryCode ?? 'KZ';
  bool _codeEditedByHand = false;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEdit => widget.city != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      // Kazakhstan is the only market today; the real list replaces this as
      // soon as it loads.
      _timezone.text = 'Asia/Almaty';
      _currency.text = 'KZT';
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _nameKk, _code, _timezone, _currency, _latitude, _longitude, _radius]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _pickCountry(String? code, List<CountryOption> countries) {
    if (code == null) return;
    setState(() => _countryCode = code);
    final country = countries.where((c) => c.code == code).firstOrNull;
    if (country != null && !_isEdit) {
      _timezone.text = country.timezone;
      _currency.text = country.currency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countries = ref.watch(countriesProvider).value ?? const <CountryOption>[];
    const gap = SizedBox(height: FactorySpacing.space3);
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;
    String? optionalNumber(String? v) =>
        (v == null || v.trim().isEmpty || double.tryParse(v.trim()) != null) ? null : l10n.fieldNumberInvalid;

    return FactoryDialog(
      title: _isEdit ? l10n.cityEditTitle(widget.city!.name) : l10n.cityNewTitle,
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FactoryTextField(
                  controller: _name,
                  enabled: !_isSubmitting,
                  label: l10n.cityName,
                  textInputAction: TextInputAction.next,
                  validator: required,
                  onChanged: (value) {
                    if (!_isEdit && !_codeEditedByHand) _code.text = slugifyCode(value);
                  },
                ),
                gap,
                FactoryTextField(
                  controller: _nameKk,
                  enabled: !_isSubmitting,
                  label: l10n.cityNameKk,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                gap,
                if (!_isEdit && countries.length > 1) ...[
                  DropdownButtonFormField<String>(
                    initialValue: countries.any((c) => c.code == _countryCode) ? _countryCode : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.cityCountry),
                    items: [
                      for (final c in countries) DropdownMenuItem(value: c.code, child: Text('${c.name} (${c.code})')),
                    ],
                    onChanged: _isSubmitting ? null : (value) => _pickCountry(value, countries),
                  ),
                  gap,
                ],
                FactoryTextField(
                  controller: _code,
                  enabled: !_isSubmitting && !_isEdit,
                  readOnly: _isEdit,
                  label: l10n.fieldCode,
                  onChanged: (_) => _codeEditedByHand = true,
                  validator: (value) {
                    if (_isEdit) return null;
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.fieldRequired;
                    return isValidCode(text) ? null : l10n.fieldCodeInvalid;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space1),
                    child: Text(
                      _isEdit ? l10n.fieldCodeFixed : l10n.fieldCodeHelper,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                gap,
                FactoryTextField(
                  controller: _timezone,
                  enabled: !_isSubmitting,
                  label: l10n.cityTimezone,
                  validator: required,
                ),
                gap,
                FactoryTextField(
                  controller: _currency,
                  enabled: !_isSubmitting,
                  label: l10n.cityCurrency,
                  validator: required,
                ),
                gap,
                Row(
                  children: [
                    Expanded(
                      child: FactoryTextField(
                        controller: _latitude,
                        enabled: !_isSubmitting,
                        label: l10n.cityLatitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: optionalNumber,
                      ),
                    ),
                    const SizedBox(width: FactorySpacing.space3),
                    Expanded(
                      child: FactoryTextField(
                        controller: _longitude,
                        enabled: !_isSubmitting,
                        label: l10n.cityLongitude,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: optionalNumber,
                      ),
                    ),
                  ],
                ),
                gap,
                FactoryTextField(
                  controller: _radius,
                  enabled: !_isSubmitting,
                  label: l10n.cityRadius,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return (n == null || n <= 0) ? l10n.fieldNumberInvalid : null;
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: FactorySpacing.space3),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancel,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        FactoryButton(
          label: _isEdit ? l10n.save : l10n.create,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final api = ref.read(cityApiProvider);
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    final radius = int.parse(_radius.text.trim());
    try {
      if (_isEdit) {
        await api.update(
          widget.city!,
          name: _name.text.trim(),
          nameKk: _nameKk.text.trim(),
          timezone: _timezone.text.trim(),
          currency: _currency.text.trim().toUpperCase(),
          latitude: lat,
          longitude: lng,
          radiusKm: radius,
        );
      } else {
        await api.create(
          code: _code.text.trim(),
          name: _name.text.trim(),
          nameKk: _nameKk.text.trim(),
          countryCode: _countryCode,
          timezone: _timezone.text.trim(),
          currency: _currency.text.trim().toUpperCase(),
          latitude: lat,
          longitude: lng,
          radiusKm: radius,
        );
      }
      if (mounted) Navigator.of(context).pop(_name.text.trim());
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = isConflict(error) ? l10n.codeTaken : describeError(l10n, error);
        _isSubmitting = false;
      });
    }
  }
}
