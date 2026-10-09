import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/city/data/models/city.dart';

City _city({String? nameKk}) =>
    City(code: 'almaty', name: 'Almaty', nameKk: nameKk, countryCode: 'KZ', timezone: 'Asia/Almaty', currency: 'KZT', active: true);

void main() {
  test('Kazakh shows the Kazakh name, other languages the default name', () {
    final city = _city(nameKk: 'Алматы');
    expect(city.nameFor('kk'), 'Алматы');
    expect(city.nameFor('ru'), 'Almaty');
    expect(city.nameFor('en'), 'Almaty');
  });

  test('a missing or empty Kazakh name falls back to the default name', () {
    expect(_city().nameFor('kk'), 'Almaty');
    expect(_city(nameKk: '').nameFor('kk'), 'Almaty');
  });
}
