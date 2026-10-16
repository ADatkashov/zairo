import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_admin/app/routes.dart';
import 'package:platform_admin/core/formatting/csv.dart';

import 'support/harness.dart';

void main() {
  group('toCsv', () {
    test('plain cells are joined with commas, one row per line', () {
      expect(
        toCsv(
          ['a', 'b'],
          [
            ['1', '2'],
            ['3', '4'],
          ],
        ),
        'a,b\r\n1,2\r\n3,4',
      );
    });

    test('commas, quotes and line breaks are quoted, quotes doubled', () {
      expect(
        toCsv(
          ['n'],
          [
            ['Glow, Salon'],
            ['say "hi"'],
            ['two\nlines'],
          ],
        ),
        'n\r\n"Glow, Salon"\r\n"say ""hi"""\r\n"two\nlines"',
      );
    });

    test('a cell that would run as a spreadsheet formula is defused', () {
      expect(
        toCsv(
          ['n'],
          [
            ['=HYPERLINK("x")'],
            ['+1'],
            ['-1'],
            ['@sum'],
            ['safe'],
          ],
        ),
        'n\r\n"\'=HYPERLINK(""x"")"\r\n\'+1\r\n\'-1\r\n\'@sum\r\nsafe',
      );
    });

    test('an empty list is just the header', () {
      expect(toCsv(['a'], const []), 'a');
    });
  });

  testWidgets(
    'Copy list as CSV puts the businesses on screen on the clipboard',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpConsole(
        tester,
        backend: defaultBackend(),
        location: ConsoleRoutes.businesses,
        size: const Size(1400, 900),
      );

      await tester.tap(find.byTooltip('Copy list as CSV'));
      await tester.pumpAndSettle();

      final lines = copied!.split('\r\n');
      expect(lines.first, 'id,name,vertical,status,registered');
      expect(lines.length, 3);
      expect(copied, contains('Glow Salon'));
      expect(copied, contains('Zen Spa'));
      expect(find.text('2 businesses copied as CSV'), findsOneWidget);
    },
  );

  testWidgets('only the filtered businesses are copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpConsole(
      tester,
      backend: defaultBackend(),
      location: '${ConsoleRoutes.businesses}?status=PENDING',
      size: const Size(1400, 900),
    );

    await tester.tap(find.byTooltip('Copy list as CSV'));
    await tester.pumpAndSettle();

    expect(copied, contains('Glow Salon'));
    expect(copied, isNot(contains('Zen Spa')));
    expect(find.text('1 business copied as CSV'), findsOneWidget);
  });
}
