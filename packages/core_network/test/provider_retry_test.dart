import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
);

void main() {
  test('a network blip or a server error is retried once, quickly', () {
    for (final error in [
      _dio(DioExceptionType.connectionTimeout),
      _dio(DioExceptionType.receiveTimeout),
      _dio(DioExceptionType.connectionError),
      _dio(DioExceptionType.badResponse, status: 503),
    ]) {
      expect(appProviderRetry(0, error), const Duration(milliseconds: 500), reason: '$error');
      expect(appProviderRetry(1, error), isNull, reason: 'only one retry: $error');
    }
  });

  test('an error that retrying cannot fix fails at once', () {
    expect(appProviderRetry(0, _dio(DioExceptionType.badResponse, status: 404)), isNull);
    expect(appProviderRetry(0, _dio(DioExceptionType.badResponse, status: 401)), isNull);
    expect(appProviderRetry(0, _dio(DioExceptionType.cancel)), isNull);
    expect(appProviderRetry(0, StateError('bug')), isNull);
    expect(appProviderRetry(0, const FormatException('bad json')), isNull);
  });
}
