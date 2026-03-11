import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Genera code verifier e code challenge per OAuth 2.0 PKCE.
String generateCodeVerifier() {
  final random = Random.secure();
  final values = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(values).replaceAll('=', '');
}

String generateCodeChallenge(String verifier) {
  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
