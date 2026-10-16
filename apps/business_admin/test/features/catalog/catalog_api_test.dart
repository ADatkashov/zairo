import 'package:business_admin/features/catalog/data/catalog_api.dart';
import 'package:business_admin/features/catalog/data/models/business_type.dart';
import 'package:business_admin/features/catalog/data/models/catalog_service.dart';
import 'package:business_admin/features/catalog/data/models/category.dart';
import 'package:business_admin/features/catalog/data/models/subsphere.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

Map<String, Object?> _names(String code) => {
      'code': code,
      'nameKk': 'kk-$code',
      'nameRu': 'ru-$code',
      'nameEn': 'en-$code',
      'sortOrder': 3,
      'status': 'ACTIVE',
    };

void main() {
  late FakeHttp http;
  late CatalogApi api;

  setUp(() {
    http = FakeHttp();
    api = CatalogApi(http.client());
  });

  test('listCategories parses names, icon and order', () async {
    http.reply('GET', '/categories', [
      {'id': 'c1', ..._names('beauty'), 'icon': 'spa'},
      {'id': 'c2', ..._names('auto')},
    ]);

    final categories = await api.listCategories();

    expect(categories.map((c) => c.code), ['beauty', 'auto']);
    expect(categories.map((c) => c.icon), ['spa', null]);
    expect(categories.first.sortOrder, 3);
    expect(categories.first.status, 'ACTIVE');
  });

  test('listBusinessTypes and listSubspheres call the nested endpoints', () async {
    http
      ..reply('GET', '/categories/c1/business-types', [
        {'id': 'bt1', 'categoryId': 'c1', ..._names('salon')},
      ])
      ..reply('GET', '/business-types/bt1/subspheres', [
        {'id': 'ss1', 'businessTypeId': 'bt1', ..._names('hair')},
      ]);

    final types = await api.listBusinessTypes('c1');
    final subspheres = await api.listSubspheres('bt1');

    expect([types.single.id, types.single.categoryId, types.single.code], ['bt1', 'c1', 'salon']);
    expect([subspheres.single.id, subspheres.single.businessTypeId, subspheres.single.code], ['ss1', 'bt1', 'hair']);
  });

  test('listServicesByBusinessType parses services with and without a subsphere', () async {
    http.reply('GET', '/business-types/bt1/services', [
      {
        'id': 'sv1',
        'businessTypeId': 'bt1',
        'subsphereId': 'ss1',
        'nameKk': 'a',
        'nameRu': 'b',
        'nameEn': 'c',
        'sortOrder': 1,
        'status': 'ACTIVE',
      },
      {
        'id': 'sv2',
        'businessTypeId': 'bt1',
        'nameKk': 'a',
        'nameRu': 'b',
        'nameEn': 'c',
        'sortOrder': 2,
        'status': 'INACTIVE',
      },
    ]);

    final services = await api.listServicesByBusinessType('bt1');

    expect(services.map((s) => s.subsphereId), ['ss1', null]);
    expect(services.map((s) => s.status), ['ACTIVE', 'INACTIVE']);
  });

  test('every taxonomy level picks the name for the language, falling back to English', () {
    final category = Category.fromJson({'id': 'c1', ..._names('beauty')});
    final type = BusinessType.fromJson({'id': 'bt1', 'categoryId': 'c1', ..._names('salon')});
    final subsphere = Subsphere.fromJson({'id': 'ss1', 'businessTypeId': 'bt1', ..._names('hair')});
    final service = CatalogServiceModel.fromJson({
      'id': 'sv1',
      'businessTypeId': 'bt1',
      'nameKk': 'kk-s',
      'nameRu': 'ru-s',
      'nameEn': 'en-s',
      'sortOrder': 1,
      'status': 'ACTIVE',
    });

    expect(category.nameFor('kk'), 'kk-beauty');
    expect(category.nameFor('ru'), 'ru-beauty');
    expect(category.nameFor('en'), 'en-beauty');
    expect(category.nameFor('de'), 'en-beauty');
    expect([type.nameFor('kk'), type.nameFor('ru'), type.nameFor('xx')], ['kk-salon', 'ru-salon', 'en-salon']);
    expect([subsphere.nameFor('kk'), subsphere.nameFor('ru'), subsphere.nameFor('xx')],
        ['kk-hair', 'ru-hair', 'en-hair']);
    expect([service.nameFor('kk'), service.nameFor('ru'), service.nameFor('xx')], ['kk-s', 'ru-s', 'en-s']);
  });
}
