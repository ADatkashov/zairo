class BeautyException implements Exception {
  final String message;

  const BeautyException(this.message);

  @override
  String toString() => message;
}
