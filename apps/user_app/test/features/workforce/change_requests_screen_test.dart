import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/workforce/data/change_request_api.dart';
import 'package:zairo/features/workforce/data/models/change_request.dart';
import 'package:zairo/features/workforce/presentation/providers/workforce_providers.dart';
import 'package:zairo/features/workforce/presentation/screens/change_requests_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeApi extends ChangeRequestApi {
  _FakeApi() : super(DioClient(Dio()));

  List<ChangeRequest> items = [
    ChangeRequest(
      bookingId: 'b1',
      providerId: 'p1',
      providerName: 'Salon',
      serviceTitle: 'Haircut',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
      workerName: 'Aigerim',
      replacements: const [ReplacementOption(workerId: 'w2', name: 'Dana')],
      otherTimes: [
        TimeOption(
          slotId: 's9',
          startsAt: DateTime.now().add(const Duration(days: 2)),
          endsAt: DateTime.now().add(const Duration(days: 2, hours: 1)),
        ),
      ],
    ),
  ];
  final List<String> calls = [];

  @override
  Future<List<ChangeRequest>> list() async => items;

  @override
  Future<void> replace(String bookingId, String workerId) async {
    calls.add('replace:$workerId');
    items = [];
  }

  @override
  Future<void> move(String bookingId, String slotId) async {
    calls.add('move:$slotId');
    items = [];
  }

  @override
  Future<void> cancel(String bookingId) async {
    calls.add('cancel');
    items = [];
  }
}

Widget _wrap(_FakeApi api) => ProviderScope(
      overrides: [changeRequestApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        theme: factoryLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChangeRequestsScreen(),
      ),
    );

void main() {
  testWidgets('offers a colleague, another time or a refunded cancel', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    expect(find.text("Aigerim can't make it. Please choose what to do."), findsOneWidget);
    expect(find.text('Dana'), findsOneWidget);
    expect(find.text('Cancel and refund'), findsOneWidget);

    await tester.tap(find.text('Dana'));
    await tester.pumpAndSettle();
    expect(api.calls, ['replace:w2']);
    expect(find.text('Nothing to decide'), findsOneWidget);
  });

  testWidgets('cancelling asks for confirmation first', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel and refund'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tester.tap(find.text('Cancel and refund').last);
    await tester.pumpAndSettle();
    expect(api.calls, ['cancel']);
  });
}
