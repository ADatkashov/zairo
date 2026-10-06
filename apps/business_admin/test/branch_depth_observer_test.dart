import 'package:business_admin/app/owner_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BranchDepthObserver observer;
  late GlobalKey<NavigatorState> navKey;

  Future<void> pumpNav(WidgetTester tester) async {
    observer = BranchDepthObserver();
    navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('root')),
      ),
    );
    await tester.pump();
  }

  testWidgets('a pushed screen counts, popping it restores zero', (tester) async {
    await pumpNav(tester);
    expect(observer.depth.value, 0);

    navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detail'))));
    await tester.pumpAndSettle();
    expect(observer.depth.value, 1);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.depth.value, 0);
  });

  testWidgets('dialogs and menus on the branch navigator do not hide the bar', (tester) async {
    await pumpNav(tester);
    showDialog<void>(
      context: navKey.currentContext!,
      useRootNavigator: false,
      builder: (_) => const AlertDialog(title: Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(observer.depth.value, 0);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(observer.depth.value, 0);
  });

  testWidgets('a push and pop in the same frame do not leave the bar hidden', (tester) async {
    await pumpNav(tester);
    final nav = navKey.currentState!;
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a'))));
    nav.pop();
    await tester.pumpAndSettle();
    expect(observer.depth.value, 0);
  });

  testWidgets('replacing a screen keeps the depth', (tester) async {
    await pumpNav(tester);
    final nav = navKey.currentState!;
    nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a'))));
    await tester.pumpAndSettle();
    nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('b'))));
    await tester.pumpAndSettle();
    expect(observer.depth.value, 1);
    nav.pop();
    await tester.pumpAndSettle();
    expect(observer.depth.value, 0);
  });
}
