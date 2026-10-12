import 'package:business_admin/features/reviews/data/api/reviews_api.dart';
import 'package:business_admin/features/reviews/data/models/provider_review.dart';
import 'package:business_admin/features/reviews/data/reviews_exception.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

const _review = {
  'id': 'r1',
  'bookingId': 'b1',
  'customerName': 'Aigerim',
  'rating': 5,
  'comment': 'Lovely',
  'createdAt': '2026-10-10T10:00:00Z',
  'businessReply': 'Thank you!',
  'businessReplyAt': '2026-10-11T10:00:00Z',
};

Future<ReviewsException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ReviewsException catch (e) {
    return e;
  }
  fail('expected a ReviewsException');
}

void main() {
  late FakeHttp http;
  late ReviewsApi api;

  setUp(() {
    http = FakeHttp();
    api = ReviewsApi(http.client());
  });

  test('fetchReviews pages through the reviews, with and without a reply', () async {
    http.reply('GET', '/providers/p1/reviews', {
      'content': [
        _review,
        {'id': 'r2', 'bookingId': 'b2', 'customerName': 'Dana', 'rating': 3, 'createdAt': '2026-10-09T10:00:00Z'},
      ],
      'totalElements': 2,
      'totalPages': 1,
      'number': 0,
      'size': 20,
      'first': true,
      'last': true,
    });

    final page = await api.fetchReviews('p1');

    expect(http.calls('GET', '/providers/p1/reviews').single.queryParameters, {'page': 0, 'size': 20});
    expect(page.content.map((r) => r.hasReply), [true, false]);
    expect(page.content[0].businessReply, 'Thank you!');
    expect(page.content[0].businessReplyAt, DateTime.utc(2026, 10, 11, 10));
    expect(page.content[1].comment, isNull);
    expect(page.content[1].businessReplyAt, isNull);
    expect(page.content[1].rating, 3);

    await api.fetchReviews('p1', page: 2, size: 5);
    expect(http.calls('GET', '/providers/p1/reviews').last.queryParameters, {'page': 2, 'size': 5});
  });

  test('replyToReview posts the reply and returns it with the time it was stored', () async {
    http.reply('POST', '/reviews/r2/reply',
        {'businessReply': 'We will do better', 'businessReplyAt': '2026-10-12T09:00:00Z'});

    final result = await api.replyToReview('r2', 'We will do better');

    expect(http.bodyOf('POST', '/reviews/r2/reply'), {'reply': 'We will do better'});
    expect(result.reply, 'We will do better');
    expect(result.repliedAt, DateTime.utc(2026, 10, 12, 9));
  });

  test('HTTP errors become a ReviewsException with the status and the server message', () async {
    http.fail('GET', '/providers/p1/reviews', 403, message: 'Not yours');
    final forbidden = await _failure(() => api.fetchReviews('p1'));
    expect([forbidden.statusCode, forbidden.serverMessage], [403, 'Not yours']);

    http.reply('POST', '/reviews/r1/reply', 'plain text', status: 500);
    final broken = await _failure(() => api.replyToReview('r1', 'x'));
    expect([broken.statusCode, broken.serverMessage], [500, null]);
  });

  test('localized messages: 403 and 404 are fixed, anything else shows the server text when there is one', () {
    final l10n = AppLocalizationsEn();
    String message(int? status, {String? server}) =>
        ReviewsException(statusCode: status, serverMessage: server).localizedMessage(l10n);

    expect(message(403, server: 'raw'), l10n.errorReviewsForbidden);
    expect(message(404, server: 'raw'), l10n.errorReviewsNotFound);
    expect(message(500, server: 'Database down'), 'Database down');
    expect(message(500), l10n.errorReviewsActionFailed);
    expect(message(null), l10n.errorReviewsActionFailed);
    expect(const ReviewsException(statusCode: 404).toString(), contains('404'));
  });

  test('copyWithReply returns the same review with the reply filled in', () {
    final original = ProviderReview.fromJson({..._review, 'businessReply': null, 'businessReplyAt': null});
    expect(original.hasReply, isFalse);

    final replied = original.copyWithReply(businessReply: 'Thanks', businessReplyAt: DateTime.utc(2026, 10, 12));

    expect(replied.hasReply, isTrue);
    expect(replied.businessReply, 'Thanks');
    expect(replied.businessReplyAt, DateTime.utc(2026, 10, 12));
    expect([replied.id, replied.bookingId, replied.customerName, replied.rating, replied.comment, replied.createdAt],
        [original.id, original.bookingId, original.customerName, original.rating, original.comment, original.createdAt]);
  });
}
