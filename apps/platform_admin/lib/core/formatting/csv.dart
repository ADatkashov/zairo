/// Comma-separated text for a spreadsheet (RFC 4180): cells with a comma, quote or line break are quoted, quotes are
/// doubled. A cell that starts with `=`, `+`, `-` or `@` would be run as a formula by Excel/Sheets, so it gets a
/// leading apostrophe — a business named `=HYPERLINK(...)` must not become a live formula on the admin's machine.
String toCsv(List<String> header, List<List<String>> rows) {
  String cell(String value) {
    var text = value;
    if (text.isNotEmpty && '=+-@'.contains(text[0])) text = "'$text";
    if (text.contains(RegExp('[",\r\n]'))) text = '"${text.replaceAll('"', '""')}"';
    return text;
  }

  return [header, ...rows].map((row) => row.map(cell).join(',')).join('\r\n');
}
