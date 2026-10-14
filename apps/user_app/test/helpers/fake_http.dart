import 'dart:convert';
import 'dart:typed_data';

import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';

/// A canned HTTP response: status + JSON body.
class FakeReply {
  final int status;
  final Object? body;

  const FakeReply(this.body, {this.status = 200});
}

/// An in-memory backend for API-class tests: the real Dio and the real API
/// class run, only the network is replaced. Routes are keyed "METHOD /path"
/// (no base URL, no query string); every request is recorded.
class FakeHttp implements HttpClientAdapter {
  final Map<String, FakeReply> routes = {};
  final List<RequestOptions> requests = [];

  void reply(String method, String path, Object? body, {int status = 200}) =>
      routes['$method $path'] = FakeReply(body, status: status);

  /// Makes every request to [method] [path] answer with an HTTP error [status].
  void fail(String method, String path, int status, {String? message}) =>
      reply(method, path, message == null ? <String, Object?>{} : {'message': message}, status: status);

  /// Requests made to "METHOD /path", oldest first.
  List<RequestOptions> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).toList();

  /// The decoded JSON body of the one request made to [method] [path].
  Map<String, dynamic> bodyOf(String method, String path) {
    final sent = calls(method, path);
    if (sent.length != 1) throw StateError('expected one $method $path, got ${sent.length}');
    return Map<String, dynamic>.from(sent.single.data as Map);
  }

  /// A [DioClient] on this backend, for constructing the API class under test.
  DioClient client() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = this;
    return DioClient(dio);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = routes['${options.method} ${options.path}'] ??
        const FakeReply({'message': 'no fake route'}, status: 404);
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(reply.body)),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
