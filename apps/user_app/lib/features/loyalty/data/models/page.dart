/// A generic wrapper for a Spring Data `Page<T>` JSON response — every
/// paginated Loyalty endpoint (history, redemptions) returns this exact
/// shape (`content`/`totalElements`/`totalPages`/`number`/`size`/`first`/
/// `last`). Not tied to loyalty specifically, but no shared copy of this
/// existed anywhere in `packages/core_network` or another feature to reuse
/// (checked before adding this), so it lives here for now rather than
/// inventing a new shared package for one feature's use.
class Page<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool first;
  final bool last;

  const Page({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.first,
    required this.last,
  });

  factory Page.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return Page(
      content: (json['content'] as List<dynamic>).map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      size: (json['size'] as num).toInt(),
      first: json['first'] as bool,
      last: json['last'] as bool,
    );
  }

  static Page<T> empty<T>({int size = 20}) => Page<T>(
        content: const [],
        totalElements: 0,
        totalPages: 0,
        number: 0,
        size: size,
        first: true,
        last: true,
      );
}
