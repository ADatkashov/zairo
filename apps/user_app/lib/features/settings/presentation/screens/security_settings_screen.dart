import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/apple_sign_in_service.dart';
import '../../../auth/data/google_sign_in_service.dart';
import '../../../auth/data/models/identity_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/phone_login_screen.dart';

/// "Security" -> "Biometric login" ON/OFF, plus every linked sign-in
/// method and a way to add another one — task spec §14 ("In Settings
/// добавить: Security -> Biometric login -> ON/OFF") and §8 (account
/// linking from an already-authenticated session). Reached from
/// SettingsScreen.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loadingBiometric = true;
  List<IdentitySummary> _identities = [];
  bool _loadingIdentities = true;
  bool _isLinking = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadIdentities();
  }

  Future<void> _loadBiometricState() async {
    final controller = ref.read(authControllerProvider.notifier);
    final available = await controller.isBiometricAvailable();
    final enabled = await controller.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _loadingBiometric = false;
    });
  }

  Future<void> _loadIdentities() async {
    try {
      final identities = await ref.read(authControllerProvider.notifier).listIdentities();
      if (!mounted) return;
      setState(() {
        _identities = identities;
        _loadingIdentities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingIdentities = false);
    }
  }

  bool _isLinked(String provider) => _identities.any((i) => i.provider == provider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;

    return Scaffold(
      appBar: FactoryAppBar(title: l10n.securityTitle),
      body: ListView(
        children: [
          const SizedBox(height: FactorySpacing.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
            child: Text(l10n.securityBiometricSectionTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (!_loadingBiometric && !_biometricAvailable)
            Padding(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              child: Text(
                l10n.securityBiometricUnavailable,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            )
          else
            SwitchListTile(
              title: Text(l10n.securityBiometricToggleTitle),
              subtitle: Text(l10n.securityBiometricToggleSubtitle),
              value: _biometricEnabled,
              onChanged: _loadingBiometric ? null : _onBiometricToggled,
            ),
          const SizedBox(height: FactorySpacing.space4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
            child: Text(l10n.securityLinkedAccountsSectionTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (_loadingIdentities)
            const Padding(
              padding: EdgeInsets.all(FactorySpacing.space4),
              child: FactoryLoadingState(),
            )
          else ...[
            if (_linkError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FactorySpacing.space4,
                  vertical: FactorySpacing.space2,
                ),
                child: Text(_linkError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ListTile(
              title: Text(l10n.loginContinueWithGoogle),
              trailing: _isLinked('GOOGLE')
                  ? Icon(Icons.check_circle, color: colors.primary)
                  : TextButton(
                      onPressed: _isLinking ? null : _linkGoogle,
                      child: Text(l10n.securityLinkButton),
                    ),
            ),
            if (ref.watch(appleSignInAvailableProvider).value ?? false)
              ListTile(
                title: Text(l10n.loginContinueWithApple),
                trailing: _isLinked('APPLE')
                    ? Icon(Icons.check_circle, color: colors.primary)
                    : TextButton(
                        onPressed: _isLinking ? null : _linkApple,
                        child: Text(l10n.securityLinkButton),
                      ),
              ),
            ListTile(
              title: Text(l10n.loginContinueWithPhone),
              trailing: _isLinked('PHONE')
                  ? Icon(Icons.check_circle, color: colors.primary)
                  : TextButton(
                      onPressed: _isLinking
                          ? null
                          : () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const PhoneLoginScreen(linking: true)))
                              .then((_) => _loadIdentities()),
                      child: Text(l10n.securityLinkButton),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onBiometricToggled(bool value) async {
    final controller = ref.read(authControllerProvider.notifier);
    if (value) {
      final enabled = await controller.enableBiometric();
      if (mounted) {
        setState(() => _biometricEnabled = enabled);
      }
      // If biometric wasn't enabled (user cancelled), reload state
      if (!enabled && mounted) {
        await _loadBiometricState();
      }
    } else {
      await controller.disableBiometric();
      if (mounted) {
        setState(() => _biometricEnabled = false);
      }
    }
  }

  Future<void> _linkGoogle() async {
    setState(() {
      _isLinking = true;
      _linkError = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final idToken = await ref.read(googleSignInServiceProvider).signIn();
      if (idToken == null) return;
      await ref.read(authControllerProvider.notifier).linkGoogle(idToken);
      await _loadIdentities();
    } catch (e) {
      if (mounted) setState(() => _linkError = l10n.errorAuthGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _linkApple() async {
    setState(() {
      _isLinking = true;
      _linkError = null;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await ref.read(appleSignInServiceProvider).signIn();
      if (result == null) return;
      await ref.read(authControllerProvider.notifier).linkApple(result.identityToken);
      await _loadIdentities();
    } catch (e) {
      if (mounted) setState(() => _linkError = l10n.errorAuthGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }
}
