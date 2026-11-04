import '../../features/maps/data/map_provider.dart';

/// Links handed to the phone's own calendar / maps apps (via `launchUrl`),
/// built without any extra plugin: both are plain https URLs that open the
/// installed app when there is one and the website otherwise.
abstract final class ExternalLinks {
  /// Google Calendar's "new event" template, pre-filled. Opens the Calendar
  /// app on Android and the web editor elsewhere; the user taps Save.
  static Uri addToCalendar({
    required String title,
    required DateTime startsAt,
    required Duration duration,
    String? details,
    String? location,
  }) {
    String stamp(DateTime t) {
      final u = t.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
          'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
    }

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${stamp(startsAt)}/${stamp(startsAt.add(duration))}',
      if (details != null && details.isNotEmpty) 'details': details,
      if (location != null && location.isNotEmpty) 'location': location,
    });
  }

  /// Dials [phone] in the phone app. Spaces, dashes and brackets are dropped; a leading `+` is kept.
  static Uri call(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), ''));

  /// Turn-by-turn directions to a point, from wherever the user is. 2GIS by
  /// default (the map people in Kazakhstan actually use); Google Maps is the
  /// alternative. Both are https links that open the installed app if there
  /// is one and the website otherwise.
  static Uri directionsTo({
    required double latitude,
    required double longitude,
    MapProvider provider = MapProvider.twoGis,
  }) => switch (provider) {
    // 2GIS puts longitude first.
    MapProvider.twoGis => Uri.https('2gis.kz', '/routeSearch/rsType/car/to/$longitude,$latitude'),
    MapProvider.google => Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    }),
  };

  /// The point itself on the map (no routing).
  static Uri showOnMap({
    required double latitude,
    required double longitude,
    MapProvider provider = MapProvider.twoGis,
  }) => switch (provider) {
    MapProvider.twoGis => Uri.https('2gis.kz', '/geo/$longitude,$latitude'),
    MapProvider.google => Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    }),
  };
}
