/// Groups [items] by the local calendar day of [startsAt], days ascending and
/// items within a day ascending — the shape every "pick a day, then a time"
/// view of availability needs. Keys are midnight local time.
Map<DateTime, List<T>> groupByLocalDay<T>(Iterable<T> items, DateTime Function(T) startsAt) {
  final sorted = items.toList()..sort((a, b) => startsAt(a).compareTo(startsAt(b)));
  final grouped = <DateTime, List<T>>{};
  for (final item in sorted) {
    final local = startsAt(item).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    (grouped[day] ??= <T>[]).add(item);
  }
  return grouped;
}
