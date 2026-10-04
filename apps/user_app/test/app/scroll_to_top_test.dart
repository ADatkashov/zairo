import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/app/router/tab_reselect.dart';
import 'package:zairo/app/widgets/scroll_to_top_on_tab_reselect.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ScrollToTopOnTabReselect(
              tabIndex: 1,
              child: ListView(
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 80, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(ScrollToTopOnTabReselect)),
    );
  }

  double offset(WidgetTester tester) =>
      PrimaryScrollController.of(tester.element(find.byType(ListView))).offset;

  testWidgets('reselecting its own tab scrolls the list back to the top', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0));

    container.read(tabReselectProvider.notifier).reselect(1);
    await tester.pumpAndSettle();

    expect(offset(tester), 0);
  });

  testWidgets('reselecting another tab leaves the list where it is', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    final before = offset(tester);

    container.read(tabReselectProvider.notifier).reselect(2);
    await tester.pumpAndSettle();

    expect(offset(tester), before);
  });
}
