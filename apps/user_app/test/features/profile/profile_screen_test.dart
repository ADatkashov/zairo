import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/profile/presentation/screens/profile_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _LoggedInAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async {
    return const UserSummary(id: 'user-1', email: 'aigerim@example.com', displayName: 'Aigerim K.', role: 'CUSTOMER');
  }
}

class _LoggedOutAuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => null;
}

Widget _wrap(AuthController controller) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    );

void main() {
  testWidgets('shows a login prompt and create-account action when logged out', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedOutAuthController()));
    await tester.pumpAndSettle();

    expect(find.text("You're not logged in"), findsOneWidget);
    expect(find.text('Log in to book and review providers'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('shows the avatar initials, name, email and menu when logged in', (tester) async {
    await tester.pumpWidget(_wrap(_LoggedInAuthController()));
    await tester.pumpAndSettle();

    expect(find.text('AK'), findsOneWidget);
    expect(find.text('Aigerim K.'), findsOneWidget);
    expect(find.text('aigerim@example.com'), findsOneWidget);
    expect(find.text('My vehicles'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });
}
