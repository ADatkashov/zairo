import 'dart:convert';

/// When a JWT stops being valid, read from its `exp` claim — used only to
/// decide whether a stored token is worth trying on startup. The backend
/// remains the authority: a token this says is fine can still be rejected.
DateTime? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
