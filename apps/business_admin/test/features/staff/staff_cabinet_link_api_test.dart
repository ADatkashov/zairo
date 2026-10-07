import 'dart:convert';
import 'dart:typed_data';

import 'package:business_admin/features/staff/data/staff_cabinet_link_api.dart';
import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this._body);

  final Object _body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode(_body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

StaffCabinetLinkApi _api(Object body) {
  final dio = Dio()..httpClientAdapter = _JsonAdapter(body);
  return StaffCabinetLinkApi(DioClient(dio));
}

void main() {
  test('null for someone who is not staff anywhere (the link stays hidden)', () async {
    expect(await _api(const []).pendingAppointments(), isNull);
  });

  test('sums appointments waiting for acceptance across every business', () async {
    final api = _api([
      {'staffId': 's1', 'pendingCount': 2},
      {'staffId': 's2', 'pendingCount': 0},
      {'staffId': 's3', 'pendingCount': 3},
    ]);
    expect(await api.pendingAppointments(), 5);
  });

  test('is staff but nothing pending: 0, not null (the link still shows)', () async {
    expect(await _api([
      {'staffId': 's1', 'pendingCount': 0},
    ]).pendingAppointments(), 0);
  });
}
