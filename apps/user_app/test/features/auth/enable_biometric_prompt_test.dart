import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/auth/presentation/widgets/enable_biometric_prompt.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _StubAuthController extends AuthController {
  int enableCalls = 0;

  @override
  Future<UserSummary?> build() async => null;

  @override
  Future<bool> isBiometricAvailable() async => true;

  @override
  Future<bool> isBiometricEnabled() async => false;

  @override
  Future<bool> enableBiometric() async {
    enableCalls++;
    return true;
  }
}

void main() {
  testWidgets('screens of one sign-in chain that fire together open a single dialog', (tester) async {
    final controller = _StubAuthController();
    late BuildContext screenContext;
    late WidgetRef screenRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              screenContext = context;
              screenRef = ref;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Login (underneath) and OTP both react to the same signed-in change.
    final first = maybeOfferEnableBiometric(screenContext, screenRef);
    final second = maybeOfferEnableBiometric(screenContext, screenRef);
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(screenContext)!;
    expect(find.text(l10n.biometricEnrollTitle), findsOneWidget);

    await tester.tap(find.text(l10n.biometricEnrollEnable));
    await tester.pumpAndSettle();
    await Future.wait([first, second]);

    expect(find.text(l10n.biometricEnrollTitle), findsNothing);
    expect(controller.enableCalls, 1);
  });

  testWidgets('the dialog still closes when the screen that asked is gone', (tester) async {
    final controller = _StubAuthController();
    final showHome = ValueNotifier(true);
    late BuildContext screenContext;
    late WidgetRef screenRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: showHome,
            builder: (_, visible, _) => visible
                ? Consumer(
                    builder: (context, ref, _) {
                      screenContext = context;
                      screenRef = ref;
                      return const Scaffold(body: Text('home'));
                    },
                  )
                : const Scaffold(body: Text('elsewhere')),
          ),
        ),
      ),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(screenContext)!;

    final offer = maybeOfferEnableBiometric(screenContext, screenRef);
    await tester.pumpAndSettle();
    expect(find.text(l10n.biometricEnrollTitle), findsOneWidget);

    showHome.value = false; // the asking screen is removed under the dialog
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.biometricEnrollNotNow));
    await tester.pumpAndSettle();
    await offer;

    expect(find.text(l10n.biometricEnrollTitle), findsNothing);
    expect(controller.enableCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
