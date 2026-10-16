/// Mirrors the backend's `WorkerDirectoryDtos.BookingWorkerResponse` — who a
/// booking is with.
class BookingWorker {
  final String id;
  final String kind;
  final String displayName;
  final String? photoUrl;

  const BookingWorker({required this.id, required this.kind, required this.displayName, this.photoUrl});

  factory BookingWorker.fromJson(Map<String, dynamic> json) {
    return BookingWorker(
      id: json['id'] as String,
      kind: json['kind'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
