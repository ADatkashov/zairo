import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'business_backup.dart';

/// Every word the file contains, already in the owner's language. The workbook builder takes them as data so it
/// stays free of Flutter and can be tested on its own.
class BackupLabels {
  const BackupLabels({
    required this.sheetSchedule,
    required this.sheetCustomers,
    required this.sheetServices,
    required this.business,
    required this.date,
    required this.start,
    required this.end,
    required this.service,
    required this.master,
    required this.customer,
    required this.phone,
    required this.email,
    required this.status,
    required this.price,
    required this.currency,
    required this.lastVisit,
    required this.visits,
    required this.spent,
    required this.noShows,
    required this.duration,
    required this.active,
    required this.yes,
    required this.no,
    required this.statusLabel,
  });

  final String sheetSchedule;
  final String sheetCustomers;
  final String sheetServices;
  final String business;
  final String date;
  final String start;
  final String end;
  final String service;
  final String master;
  final String customer;
  final String phone;
  final String email;
  final String status;
  final String price;
  final String currency;
  final String lastVisit;
  final String visits;
  final String spent;
  final String noShows;
  final String duration;
  final String active;
  final String yes;
  final String no;

  /// A booking status code ("CONFIRMED") in words.
  final String Function(String status) statusLabel;
}

final _day = DateFormat('dd.MM.yyyy');
final _time = DateFormat('HH:mm');

/// One .xlsx with three sheets — schedule (oldest first, each booking with its customer's name and phone),
/// customers (most recent visit first) and services with prices — for one or several businesses; each row says
/// which business it is of.
///
/// Every text goes in as a text cell, so a customer called `=HYPERLINK(...)` shows as that text and never runs as
/// a formula. Prices and counts are numbers (the owner can sum them); phones stay text, keeping their leading `+`.
/// Dates and times are the device's local ones, written out ("25.10.2026", "14:30").
Uint8List buildBackupWorkbook(List<BusinessBackup> backups, BackupLabels l) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();

  final schedule = excel[l.sheetSchedule];
  _header(schedule, [
    l.business,
    l.date,
    l.start,
    l.end,
    l.service,
    l.master,
    l.customer,
    l.phone,
    l.email,
    l.status,
    l.price,
    l.currency,
  ]);
  for (final b in backups) {
    for (final r in b.bookings) {
      final starts = r.startsAt.toLocal();
      schedule.appendRow([
        _t(b.providerName),
        _t(_day.format(starts)),
        _t(_time.format(starts)),
        _t(_time.format(r.endsAt.toLocal())),
        _t(r.serviceTitle),
        _t(r.staffName),
        _t(r.customerName),
        _t(r.customerPhone),
        _t(r.customerEmail),
        _t(l.statusLabel(r.status)),
        DoubleCellValue(r.totalPrice),
        _t(r.currency),
      ]);
    }
  }
  _widths(schedule, [22, 12, 8, 8, 26, 18, 24, 18, 26, 14, 12, 10]);

  final customers = excel[l.sheetCustomers];
  _header(customers, [l.business, l.customer, l.phone, l.email, l.lastVisit, l.visits, l.spent, l.currency, l.noShows]);
  for (final b in backups) {
    for (final c in b.customers) {
      customers.appendRow([
        _t(b.providerName),
        _t(c.name),
        _t(c.phone),
        _t(c.email),
        _t(c.lastVisitAt == null ? null : _day.format(c.lastVisitAt!.toLocal())),
        IntCellValue(c.totalBookings),
        DoubleCellValue(c.totalSpent),
        _t(c.currency),
        IntCellValue(c.noShows),
      ]);
    }
  }
  _widths(customers, [22, 24, 18, 26, 14, 10, 14, 10, 10]);

  final services = excel[l.sheetServices];
  _header(services, [l.business, l.service, l.duration, l.price, l.currency, l.active]);
  for (final b in backups) {
    for (final s in b.services) {
      services.appendRow([
        _t(b.providerName),
        _t(s.title),
        IntCellValue(s.durationMinutes),
        DoubleCellValue(s.price),
        _t(s.currency),
        _t(s.active ? l.yes : l.no),
      ]);
    }
  }
  _widths(services, [22, 30, 12, 12, 10, 10]);

  // The workbook starts with an empty "Sheet1" of its own; the three above are the file.
  if (defaultSheet != null && ![l.sheetSchedule, l.sheetCustomers, l.sheetServices].contains(defaultSheet)) {
    excel.delete(defaultSheet);
  }
  excel.setDefaultSheet(l.sheetSchedule);
  return Uint8List.fromList(excel.encode()!);
}

CellValue _t(String? text) => TextCellValue(text ?? '');

void _header(Sheet sheet, List<String> titles) {
  sheet.appendRow([for (final t in titles) TextCellValue(t)]);
  for (var c = 0; c < titles.length; c++) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = CellStyle(bold: true);
  }
}

void _widths(Sheet sheet, List<double> widths) {
  for (var c = 0; c < widths.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
  }
}
