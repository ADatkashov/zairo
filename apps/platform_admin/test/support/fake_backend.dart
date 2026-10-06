import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned response: status + JSON body.
class FakeReply {
  final int status;
  final Object? body;

  const FakeReply(this.body, {this.status = 200});
}

typedef FakeHandler = FakeReply Function(RequestOptions request);

/// An in-memory backend for widget tests: the real API classes and the real
/// Dio interceptors run, only the network is replaced. Routes are keyed
/// "METHOD /path" (path without the base URL); every request is recorded.
class FakeBackend implements HttpClientAdapter {
  final Map<String, FakeHandler> routes = {};
  final List<RequestOptions> requests = [];

  void on(String method, String path, FakeHandler handler) => routes['$method $path'] = handler;

  void reply(String method, String path, Object? body, {int status = 200}) =>
      routes['$method $path'] = (_) => FakeReply(body, status: status);

  /// Requests made to "METHOD /path", oldest first.
  List<RequestOptions> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    final reply = handler?.call(options) ?? const FakeReply({'message': 'no fake route'}, status: 404);
    final bytes = utf8.encode(jsonEncode(reply.body));
    return ResponseBody.fromBytes(
      bytes,
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
