// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Uri? garminWebCurrentUri() {
  try {
    final href = html.window.location.href;
    if (href.isEmpty) return null;
    return Uri.parse(href);
  } on Object {
    return null;
  }
}

void garminWebAssignLocation(String url) {
  html.window.location.assign(url);
}

void garminWebReplaceCleanUrl(Uri clean) {
  html.window.history.replaceState(null, '', clean.toString());
}

void garminWebSessionSet(String key, String value) {
  html.window.sessionStorage[key] = value;
}

String? garminWebSessionGet(String key) {
  return html.window.sessionStorage[key];
}

void garminWebSessionRemove(String key) {
  html.window.sessionStorage.remove(key);
}
