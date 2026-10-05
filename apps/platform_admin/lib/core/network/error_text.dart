import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';

/// A sentence a person can act on, instead of `DioException [bad response]…`.
String describeError(AppLocalizations l10n, Object? error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return l10n.errorNetwork;
      default:
        break;
    }
    switch (error.response?.statusCode) {
      case 401:
        return l10n.errorSessionExpired;
      case 403:
        return l10n.errorForbidden;
      case 404:
        return l10n.errorNotFound;
      case 409:
        return l10n.errorConflict;
      case final int status when status >= 500:
        return l10n.errorServer;
    }
  }
  return l10n.errorGeneric;
}

bool isConflict(Object? error) => error is DioException && error.response?.statusCode == 409;
