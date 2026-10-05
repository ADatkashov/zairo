import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tells the session layer that the backend rejected the token (it expired or
/// was revoked) so it can sign the person out and send them to the login
/// screen. A plain callback holder rather than a provider dependency, so the
/// HTTP client doesn't depend on the session that depends on the HTTP client.
class UnauthorizedBus {
  void Function()? onUnauthorized;
}

final unauthorizedBusProvider = Provider<UnauthorizedBus>((ref) => UnauthorizedBus());

const loginPath = '/platform/auth/login';

/// A seam for tests: when set, requests go to this adapter instead of the
/// network, while the real interceptors (token, 401 handling) still run.
final httpClientAdapterOverrideProvider = Provider<HttpClientAdapter?>((ref) => null);

/// The console's HTTP client. Deliberately not core_network's `dioProvider`:
/// that one logs every request and response body, which would put staff
/// passwords and bearer tokens into the debug log. Everything under
/// `/platform/**` takes the platform token, which [AuthTokenHolder] carries.
final platformDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(networkConfigProvider);
  final tokenHolder = ref.watch(authTokenHolderProvider);
  final bus = ref.watch(unauthorizedBusProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  final adapter = ref.watch(httpClientAdapterOverrideProvider);
  if (adapter != null) dio.httpClientAdapter = adapter;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenHolder.accessToken;
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // A wrong password on the login call is also a 401 — that one is the
        // login form's to explain, not a reason to "sign out".
        final isLogin = error.requestOptions.path == loginPath;
        if (error.response?.statusCode == 401 && !isLogin && tokenHolder.accessToken != null) {
          bus.onUnauthorized?.call();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});
