import 'package:business_admin/features/backup/data/backup_workbook.dart';
import 'package:business_admin/features/backup/data/business_backup.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = BackupLabels(
  sheetSchedule: 'Schedule',
  sheetCustomers: 'Customers',
  sheetServices: 'Services',
  business: 'Business',
  date: 'Date',
  start: 'Start',
  end: 'End',
  service: 'Service',
  master: 'Master',
  customer: 'Customer',
  phone: 'Phone',
  email: 'Email',
  status: 'Status',
  price: 'Price',
  currency: 'Currency',
  lastVisit: 'Last visit',
  visits: 'Visits',
  spent: 'Spent',
  noShows: 'No-shows',
  duration: 'Minutes',
  active: 'Active',
  yes: 'Yes',
  no: 'No',
  statusLabel: _statusLabel,
);

String _statusLabel(String s) => s == 'CONFIRMED' ? 'Confirmed' : s;

BusinessBackup _backup(
  String name, {
  List<BackupBooking> bookings = const [],
  List<BackupCustomer> customers = const [],
  List<BackupService> services = const [],
}) => BusinessBackup(
  providerId: 'p-$name',
  providerName: name,
  generatedAt: DateTime.utc(2026, 10, 25),
  from: DateTime.utc(2026, 9, 25),
  to: DateTime.utc(2027, 4, 23),
  bookings: bookings,
  customers: customers,
  services: services,
);

BackupBooking _booking({String? customer = 'Ana', String? phone = '+77001112233', DateTime? starts}) => BackupBooking(
  startsAt: starts ?? DateTime(2026, 10, 26, 9, 30),
  endsAt: (starts ?? DateTime(2026, 10, 26, 9, 30)).add(const Duration(hours: 1)),
  status: 'CONFIRMED',
  serviceTitle: 'Haircut',
  staffName: 'Aigerim',
  customerName: customer,
  customerPhone: phone,
  customerEmail: 'ana@x.kz',
  totalPrice: 9000,
  currency: 'KZT',
);

/// The workbook read back as text, row by row, the way a spreadsheet program would show it.
Map<String, List<List<String>>> _read(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  return {
    for (final entry in excel.tables.entries)
      entry.key: [
        for (final row in entry.value.rows) [for (final cell in row) cell?.value?.toString() ?? ''],
      ],
  };
}

void main() {
  test('is a workbook of exactly three sheets, and Excel\'s default empty one is gone', () {
    final sheets = _read(buildBackupWorkbook([_backup('Glow')], _labels));

    expect(sheets.keys, unorderedEquals(['Schedule', 'Customers', 'Services']));
  });

  test('the schedule row carries who, when, what, with whom and how to reach them', () {
    final sheets = _read(buildBackupWorkbook([_backup('Glow', bookings: [_booking()])], _labels));
    final rows = sheets['Schedule']!;

    expect(rows.first, ['Business', 'Date', 'Start', 'End', 'Service', 'Master', 'Customer', 'Phone', 'Email', 'Status', 'Price', 'Currency']);
    expect(rows[1], ['Glow', '26.10.2026', '09:30', '10:30', 'Haircut', 'Aigerim', 'Ana', '+77001112233', 'ana@x.kz', 'Confirmed', '9000', 'KZT']);
    expect(rows, hasLength(2));
  });

  test('prices and counts are numbers, so the owner can sum them; phones stay text with their plus', () {
    final bytes = buildBackupWorkbook([
      _backup(
        'Glow',
        bookings: [_booking()],
        customers: const [
          BackupCustomer(name: 'Ana', phone: '+77001112233', totalBookings: 3, totalSpent: 27000.5, currency: 'KZT', noShows: 1),
        ],
        services: const [BackupService(title: 'Haircut', durationMinutes: 60, price: 9000, currency: 'KZT', active: true)],
      ),
    ], _labels);
    final excel = Excel.decodeBytes(bytes);

    CellValue? at(String sheet, int col) => excel.tables[sheet]!.rows[1][col]?.value;
    // A spreadsheet stores numbers without an int/double split: 9000.0 reads back as 9000, which is still a number.
    bool isNumber(CellValue? v) => v is IntCellValue || v is DoubleCellValue;
    expect(isNumber(at('Schedule', 10)), isTrue);
    expect(at('Schedule', 7), isA<TextCellValue>());
    expect(isNumber(at('Customers', 5)), isTrue);
    expect(at('Customers', 6), isA<DoubleCellValue>(), reason: '27000.5 keeps its fraction');
    expect(isNumber(at('Customers', 8)), isTrue);
    expect(isNumber(at('Services', 2)), isTrue);
    expect(isNumber(at('Services', 3)), isTrue);
  });

  test('a customer named like a formula is stored as plain text, never as a formula', () {
    final bytes = buildBackupWorkbook([
      _backup('Glow', bookings: [_booking(customer: '=HYPERLINK("http://evil.example","click")', phone: '+1')]),
    ], _labels);
    final cell = Excel.decodeBytes(bytes).tables['Schedule']!.rows[1][6]!;

    expect(cell.value, isA<TextCellValue>());
    expect(cell.value.toString(), '=HYPERLINK("http://evil.example","click")');
  });

  test('missing names and contacts are empty cells, not the word "null"', () {
    final sheets = _read(buildBackupWorkbook([
      _backup('Glow', bookings: [_booking(customer: null, phone: null)]),
    ], _labels));

    expect(sheets['Schedule']![1][6], '');
    expect(sheets['Schedule']![1][7], '');
    expect(sheets['Schedule']!.expand((r) => r), isNot(contains('null')));
  });

  test('customers: last visit as a date, and none as an empty cell', () {
    final sheets = _read(buildBackupWorkbook([
      _backup(
        'Glow',
        customers: [
          BackupCustomer(name: 'Ana', lastVisitAt: DateTime(2026, 10, 1, 12), totalBookings: 3, totalSpent: 27000, noShows: 1),
          const BackupCustomer(name: 'New', totalBookings: 0, totalSpent: 0, noShows: 0),
        ],
      ),
    ], _labels));
    final rows = sheets['Customers']!;

    expect(rows.first, ['Business', 'Customer', 'Phone', 'Email', 'Last visit', 'Visits', 'Spent', 'Currency', 'No-shows']);
    expect(rows[1][4], '01.10.2026');
    expect(rows[2][4], '');
  });

  test('services: duration, price, and Yes/No for whether it is offered', () {
    final sheets = _read(buildBackupWorkbook([
      _backup(
        'Glow',
        services: const [
          BackupService(title: 'Haircut', durationMinutes: 60, price: 9000, currency: 'KZT', active: true),
          BackupService(title: 'Old wax', durationMinutes: 30, price: 3000, active: false),
        ],
      ),
    ], _labels));
    final rows = sheets['Services']!;

    expect(rows.first, ['Business', 'Service', 'Minutes', 'Price', 'Currency', 'Active']);
    expect(rows[1], ['Glow', 'Haircut', '60', '9000', 'KZT', 'Yes']);
    expect(rows[2][5], 'No');
    expect(rows[2][4], '');
  });

  test('several businesses go into the same sheets, each row naming its business', () {
    final sheets = _read(buildBackupWorkbook([
      _backup('Glow', bookings: [_booking(starts: DateTime(2026, 10, 26, 9))]),
      _backup('Garage', bookings: [_booking(starts: DateTime(2026, 10, 27, 9))]),
    ], _labels));
    final rows = sheets['Schedule']!;

    expect(rows.map((r) => r[0]), ['Business', 'Glow', 'Garage']);
  });

  test('an owner with nothing yet still gets a valid file with just the headers', () {
    final sheets = _read(buildBackupWorkbook([_backup('Glow')], _labels));

    expect(sheets['Schedule'], hasLength(1));
    expect(sheets['Customers'], hasLength(1));
    expect(sheets['Services'], hasLength(1));
    expect(_read(buildBackupWorkbook(const [], _labels))['Schedule'], hasLength(1));
  });

  test('an unknown booking status is shown as the code the server sent', () {
    final booking = BackupBooking(
      startsAt: DateTime(2026, 10, 26, 9),
      endsAt: DateTime(2026, 10, 26, 10),
      status: 'NO_SHOW',
      totalPrice: 1,
    );
    final sheets = _read(buildBackupWorkbook([_backup('Glow', bookings: [booking])], _labels));

    expect(sheets['Schedule']![1][9], 'NO_SHOW');
  });
}
