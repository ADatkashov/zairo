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

  /// Turn-by-turn directions to a point, from wherever the user is.
  static Uri directionsTo({required double latitude, required double longitude}) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      });
}
