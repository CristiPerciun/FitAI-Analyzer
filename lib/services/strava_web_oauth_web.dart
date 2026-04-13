// OAuth redirect su web: solo questo file importa dart:html (import condizionale).
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:math';

Uri? stravaWebCurrentUri() {
  try {
    final href = html.window.location.href;
    if (href.isEmpty) return null;
    return Uri.parse(href);
  } on Object {
    return null;
  }
}

void stravaWebAssignLocation(String url) {
  html.window.location.assign(url);
}

void stravaWebReplaceCleanUrl(Uri clean) {
  html.window.history.replaceState(null, '', clean.toString());
}

void stravaWebSessionSet(String key, String value) {
  html.window.sessionStorage[key] = value;
}

String? stravaWebSessionGet(String key) {
  return html.window.sessionStorage[key];
}

void stravaWebSessionRemove(String key) {
  html.window.sessionStorage.remove(key);
}

String stravaWebNewOAuthState() {
  final n = Random.secure().nextInt(0x7fffffff);
  return n.toRadixString(16);
}
