import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auth/presentation/auth_navigation.dart';

void main() {
  testWidgets(
    'popAuthFlow closes the whole auth chain and lands on the screen that '
    'opened it, not on the root route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Builder(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => pushAuthScreen(
                            context,
                            Builder(
                              builder: (context) => Scaffold(
                                body: TextButton(
                                  onPressed: () => pushAuthScreen(
                                    context,
                                    Builder(
                                      builder: (context) => Scaffold(
                                        body: TextButton(
                                          onPressed: () =>
                                              popAuthFlow(context),
                                          child: const Text('finish login'),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: const Text('step two'),
                                ),
                              ),
                            ),
                          ),
                          child: const Text('provider card'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('root'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('provider card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('step two'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('finish login'));
      await tester.pumpAndSettle();

      expect(find.text('provider card'), findsOneWidget);
      expect(find.text('root'), findsNothing);
    },
  );
}
