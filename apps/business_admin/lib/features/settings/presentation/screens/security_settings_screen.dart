import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// "Security" -> "Biometric login" ON/OFF (fingerprint / Face ID unlock of the
/// stored session on app restart). Reached from SettingsScreen when signed in.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _available = false;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = ref.read(authControllerProvider.notifier);
    final available = await controller.isBiometricAvailable();
    final enabled = await controller.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _onToggled(bool value) async {
    final controller = ref.read(authControllerProvider.notifier);
    if (value) {
      final enabled = await controller.enableBiometric();
      if (!mounted) return;
      setState(() => _enabled = enabled);
      if (!enabled) await _load();
    } else {
      await controller.disableBiometric();
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.securityTitle),
      body: ListView(
        children: [
          const SizedBox(height: FactorySpacing.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
            child: Text(l10n.securityBiometricSectionTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (!_loading && !_available)
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: Text(
                l10n.securityBiometricUnavailable,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.factoryColors.textSecondary),
              ),
            )
          else
            SwitchListTile(
              title: Text(l10n.securityBiometricToggleTitle),
              subtitle: Text(l10n.securityBiometricToggleSubtitle),
              value: _enabled,
              onChanged: _loading ? null : _onToggled,
            ),
        ],
      ),
    );
  }
}
