import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
);

Widget _app(FutureProvider<String> provider, {Duration? Function(int, Object)? retry}) => ProviderScope(
  retry: retry,
  child: MaterialApp(
    home: Consumer(
      builder: (context, ref, _) => ref
          .watch(provider)
          .when(data: Text.new, loading: () => const Text('loading'), error: (e, _) => const Text('error')),
    ),
  ),
);


void main() {
  testWidgets('with the app policy a 404 shows the error at once (the Riverpod default keeps it loading)', (
    tester,
  ) async {
    final failing = FutureProvider<String>((ref) async => throw _dio(DioExceptionType.badResponse, status: 404));

    await tester.pumpWidget(_app(failing, retry: appProviderRetry));
    await tester.pump();
    await tester.pump();
    expect(find.text('error'), findsOneWidget);

    // For contrast: the default policy retries a 404 with growing delays, so the screen stays on its spinner.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(failing));
    await tester.pump();
    await tester.pump();
    expect(find.text('loading'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a network blip is retried once and the screen recovers without showing an error', (tester) async {
    var calls = 0;
    final flaky = FutureProvider<String>((ref) async {
      calls++;
      if (calls == 1) throw _dio(DioExceptionType.connectionError);
      return 'loaded';
    });

    await tester.pumpWidget(_app(flaky, retry: appProviderRetry));
    await tester.pump();
    expect(find.text('error'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('loaded'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('a connection that keeps failing shows the error after the one retry', (tester) async {
    final down = FutureProvider<String>((ref) async => throw _dio(DioExceptionType.connectionTimeout));

    await tester.pumpWidget(_app(down, retry: appProviderRetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
  });
}
