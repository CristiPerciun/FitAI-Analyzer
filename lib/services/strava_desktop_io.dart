import 'dart:async';
import 'dart:io' show ContentType, HttpServer;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:url_launcher/url_launcher.dart';

/// Esegue OAuth Strava su desktop con loopback HTTP locale.
/// url_launcher apre il browser (FlutterWebAuth2 su desktop richiede http://localhost).
Future<String> runDesktopStravaOAuth(
  String authUrlBase,
  Map<String, String> params,
) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  final loopbackUri = 'http://127.0.0.1:${server.port}/callback';
  params['redirect_uri'] = loopbackUri;

  final authUrl = Uri.parse(authUrlBase).replace(queryParameters: params).toString();
  debugPrint('Flutter su desktop → uso loopback: $loopbackUri');

  await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);

  String? code;
  String? error;
  final completer = Completer<void>();

  server.listen((request) async {
    try {
      final path = request.uri.path;
      debugPrint('Strava callback ricevuto: $path');
      if (path == '/callback' || path == 'callback') {
        code = request.uri.queryParameters['code'];
        error = request.uri.queryParameters['error'];

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body><h2>Autorizzazione Strava completata!</h2><p>Puoi chiudere questa finestra e tornare all\'app.</p></body></html>',
          )
          ..close();

        await server.close(force: true);
        completer.complete();
      }
    } catch (e) {
      debugPrint('Errore gestione callback: $e');
      completer.completeError(e);
    }
  });

  await completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () {
      server.close(force: true);
      throw TimeoutException('Timeout attesa autorizzazione Strava (5 min)');
    },
  );

  if (code != null) return code!;
  if (error != null) throw Exception('Errore Strava: $error');
  throw Exception('Nessun code né errore nel redirect desktop');
}
