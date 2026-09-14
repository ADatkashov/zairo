/// Mirrors Spring Data's `Page<T>` JSON shape -- every paginated Loyalty
/// admin endpoint (customers, redemptions) returns this exact envelope.
/// Generic over the item type so both list screens share one parser instead
/// of hand-rolling the same five fields twice.
class LoyaltyPage<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool first;
  final bool last;

  const LoyaltyPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.first,
    required this.last,
  });

  factory LoyaltyPage.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) itemFromJson) {
    return LoyaltyPage(
      content: (json['content'] as List<dynamic>).map((e) => itemFromJson(e as Map<String, dynamic>)).toList(),
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      size: (json['size'] as num).toInt(),
      first: json['first'] as bool,
      last: json['last'] as bool,
    );
  }
}
