import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/data/auth_exception.dart';
import '../../../auth/data/apple_sign_in_service.dart';
import '../../../auth/data/google_sign_in_service.dart';
import '../../../auth/data/models/identity_summary.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/link_phone_screen.dart';

/// "Security" -> "Biometric login" ON/OFF (fingerprint / Face ID unlock of the
/// stored session on app restart), plus every linked sign-in method and a way to
/// add another one (Google, Apple, phone) to the same account. Reached from
/// SettingsScreen when signed in.
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _available = false;
  bool _enabled = false;
  bool _loading = true;
  List<IdentitySummary> _identities = [];
  bool _loadingIdentities = true;
  bool _isLinking = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadIdentities();
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

  Future<void> _link(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLinking = true;
      _linkError = null;
    });
    try {
      await action();
      await _loadIdentities();
    } on AuthException catch (e) {
      if (mounted) setState(() => _linkError = e.localizedMessage(l10n));
    } catch (e) {
      if (mounted) setState(() => _linkError = l10n.errorAuthGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _linkGoogle() => _link(() async {
        final idToken = await ref.read(googleSignInServiceProvider).signIn();
        if (idToken == null) return; // Canceled — nothing to show.
        await ref.read(authControllerProvider.notifier).linkGoogle(idToken);
      });

  Future<void> _linkApple() => _link(() async {
        final result = await ref.read(appleSignInServiceProvider).signIn();
        if (result == null) return;
        await ref.read(authControllerProvider.notifier).linkApple(result.identityToken);
      });

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
          const SizedBox(height: FactorySpacing.space4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
            child: Text(l10n.securityLinkedAccountsSectionTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (_loadingIdentities)
            const Padding(padding: EdgeInsets.all(FactorySpacing.space4), child: FactoryLoadingState())
          else ...[
            if (_linkError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4, vertical: FactorySpacing.space2),
                child: Text(_linkError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            _LinkedRow(
              title: l10n.loginContinueWithGoogle,
              linked: _isLinked('GOOGLE'),
              busy: _isLinking,
              onLink: _linkGoogle,
            ),
            if (ref.watch(appleSignInAvailableProvider).value ?? false)
              _LinkedRow(
                title: l10n.loginContinueWithApple,
                linked: _isLinked('APPLE'),
                busy: _isLinking,
                onLink: _linkApple,
              ),
            _LinkedRow(
              title: l10n.loginContinueWithPhone,
              linked: _isLinked('PHONE'),
              busy: _isLinking,
              onLink: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LinkPhoneScreen()))
                  .then((_) => _loadIdentities()),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({required this.title, required this.linked, required this.busy, required this.onLink});

  final String title;
  final bool linked;
  final bool busy;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(title),
      trailing: linked
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : TextButton(onPressed: busy ? null : onLink, child: Text(l10n.securityLinkButton)),
    );
  }
}
