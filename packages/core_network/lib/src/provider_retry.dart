import 'package:dio/dio.dart';

/// App-wide retry policy for failed Riverpod providers (`ProviderScope(retry: appProviderRetry)`).
///
/// Riverpod 3 retries every failed provider up to 10 times with a growing delay, which keeps a
/// screen on its loading spinner for the better part of a minute before the error and its Retry
/// button ever appear. A person waiting on a screen is better served by one quick silent retry for
/// a network blip and then an honest error: only transient network failures are retried, once.
/// Anything else (a 4xx, a parsing bug, a thrown [Error]) fails at once.
Duration? appProviderRetry(int retryCount, Object error) {
  if (retryCount >= 1) return null;
  if (error is! DioException) return null;
  final transient = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
    _ => false,
  };
  return transient ? const Duration(milliseconds: 500) : null;
}
