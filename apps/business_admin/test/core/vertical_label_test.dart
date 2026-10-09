import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/core/formatting/vertical_label.dart';
import 'package:business_admin/l10n/app_localizations_en.dart';
import 'package:business_admin/l10n/app_localizations_kk.dart';
import 'package:business_admin/l10n/app_localizations_ru.dart';

void main() {
  test('a vertical is shown in the screen language, not as the raw backend code', () {
    expect(verticalLabel(AppLocalizationsEn(), 'beauty'), 'Beauty');
    expect(verticalLabel(AppLocalizationsRu(), 'beauty'), 'Красота');
    expect(verticalLabel(AppLocalizationsKk(), 'beauty'), 'Сұлулық');
    expect(verticalLabel(AppLocalizationsRu(), 'auto'), 'Авто');
    expect(verticalLabel(AppLocalizationsRu(), 'cleaning'), 'Клининг');
  });

  test('an unknown vertical falls back to its capitalized code', () {
    expect(verticalLabel(AppLocalizationsRu(), 'gardening'), 'Gardening');
    expect(verticalLabel(AppLocalizationsRu(), ''), '');
  });

  test('the booked slot suffix is translated', () {
    expect(AppLocalizationsRu().slotStatusBooked, 'Занято');
    expect(AppLocalizationsKk().slotStatusBooked, 'Брондалған');
  });
}
