import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/platform_http.dart';
import 'review_report.dart';

/// `/platform/reviews` — read by any platform role; the decisions (hide, restore, keep) by PLATFORM_ADMIN or
/// PLATFORM_MODERATOR (the backend decides; the console only offers what the role may do).
class ReviewApi {
  final Dio _dio;

  ReviewApi(this._dio);

  /// [status]: OPEN, HIDDEN or DISMISSED. The newest reports first; one page is plenty for a moderation queue.
  Future<List<ReviewReport>> queue(String status) async {
    final response = await _dio.get('/platform/reviews', queryParameters: {'status': status, 'size': 100});
    final content = (response.data as Map<String, dynamic>)['content'] as List<dynamic>;
    return content.map((e) => ReviewReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Takes the review out of every rating and list. [reason] is optional.
  Future<void> hide(String id, {String? reason}) => _decide(id, 'hide', reason);

  Future<void> restore(String id, {String? reason}) => _decide(id, 'restore', reason);

  /// Keeps the review: the open report is closed and cannot be filed again.
  Future<void> dismiss(String id, {String? reason}) => _decide(id, 'dismiss', reason);

  Future<void> _decide(String id, String decision, String? reason) async {
    await _dio.post('/platform/reviews/$id/$decision', data: {if (reason != null && reason.isNotEmpty) 'reason': reason});
  }
}

final reviewApiProvider = Provider<ReviewApi>((ref) => ReviewApi(ref.watch(platformDioProvider)));

/// One tab of the moderation queue, by status.
final reviewQueueProvider = FutureProvider.autoDispose.family<List<ReviewReport>, String>(
  (ref, status) => ref.watch(reviewApiProvider).queue(status),
);
