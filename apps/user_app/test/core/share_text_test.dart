import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/core/share/share_launcher.dart';

void main() {
  test('everything known: name, address, map link, in-app link', () {
    expect(
      providerShareText(id: 'p1', name: 'Glow', address: ' Abay 10 ', latitude: 43.2, longitude: 76.9).split('\n'),
      ['Glow', 'Abay 10', 'https://2gis.kz/geo/76.9,43.2', 'zairo://app/provider/p1'],
    );
  });

  test('without address or coordinates only the name and the in-app link remain', () {
    expect(providerShareText(id: 'p1', name: 'Glow').split('\n'), ['Glow', 'zairo://app/provider/p1']);
    expect(providerShareText(id: 'p1', name: 'Glow', address: '  ', latitude: 1).split('\n'), [
      'Glow',
      'zairo://app/provider/p1',
    ]);
  });
}
