import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/data/models/user_summary.dart';
import 'package:zairo/features/auth/presentation/providers/auth_providers.dart';
import 'package:zairo/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

const _user = UserSummary(id: 'u1', email: 'a@example.com', displayName: 'Aigerim', role: 'CUSTOMER');

class _AuthController extends AuthController {
  @override
  Future<UserSummary?> build() async => _user;
}

/// A host screen that pushes the editor, so there is a route to go back to.
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(_AuthController.new)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen(user: _user)),
              ),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open editor'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving with no edits goes straight back', (tester) async {
    await _open(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('open editor'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('leaving with unsaved edits asks first; "Keep editing" stays, "Discard" leaves', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Aigerim K.');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('open editor'), findsNothing); // still on the editor

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open editor'), findsOneWidget);
  });
}
