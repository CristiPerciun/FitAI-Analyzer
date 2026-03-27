import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitai_analyzer/services/garmin_service.dart'
    show GarminService, normalizeGarminServerBaseUrl;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('normalizeGarminServerBaseUrl', () {
    test('rimuove slash finali e trim', () {
      expect(
        normalizeGarminServerBaseUrl(' http://192.168.1.200/ '),
        'http://192.168.1.200',
      );
      expect(
        normalizeGarminServerBaseUrl('http://h:8080///'),
        'http://h:8080',
      );
    });
  });

  group('GarminService HTTP verso garmin-sync-server', () {
    test('connect invia POST /garmin/connect con uid, email, password', () async {
      late http.BaseRequest captured;
      final mock = MockClient((request) async {
        captured = request;
        expect(request.method, 'POST');
        expect(request.url.toString(), endsWith('/garmin/connect'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid'], 'firebase-uid-1');
        expect(body['email'], 'user@garmin.com');
        expect(body['password'], 'secret');
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok'}),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect(
        uid: 'firebase-uid-1',
        email: 'user@garmin.com',
        password: 'secret',
      );

      expect(result['success'], true);
      expect(captured.headers['content-type'], contains('application/json'));
    });

    test('connect puo forzare fresh_login nel body JSON', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['fresh_login'], true);
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok'}),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect(
        uid: 'firebase-uid-1',
        email: 'user@garmin.com',
        password: 'secret',
        freshLogin: true,
      );

      expect(result['success'], true);
    });

    test(
      'connect: password con # + apice % nel body JSON identica a quella inserita',
      () async {
        // Stesso tipo di caratteri che in password Garmin complesse (UTF-8 / JSON sicuro).
        const trickyPassword = r"a#b+c'd%e%f";
        final mock = MockClient((request) async {
          final map = jsonDecode(request.body) as Map<String, dynamic>;
          expect(map['password'], trickyPassword);
          return http.Response(jsonEncode({'success': true, 'message': 'ok'}), 200);
        });
        final svc = GarminService(
          httpClient: mock,
          serverUrlOverride: 'https://example.test',
        );
        final r = await svc.connect(
          uid: 'u',
          email: 'x@y.z',
          password: trickyPassword,
        );
        expect(r['success'], true);
      },
    );

    test('connect con 401 dal server espone il messaggio (credenziali Garmin)', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Credenziali Garmin non valide'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect(
        uid: 'u',
        email: 'a@b.c',
        password: 'wrong',
      );

      expect(result['success'], false);
      expect(result['message'], contains('Credenziali'));
    });

    test('syncToday invia POST /garmin/sync-today con uid', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/garmin/sync-today');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid'], 'uid-2');
        return http.Response(
          jsonEncode({'success': true, 'message': 'sync ok'}),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://api.example',
      );
      final result = await svc.syncToday(uid: 'uid-2');

      expect(result['success'], true);
    });

    test('deltaSync invia POST /sync/delta con lastSuccessfulSync', () async {
      final expectedMs =
          DateTime.utc(2024, 6, 1, 12).millisecondsSinceEpoch;
      final mock = MockClient((request) async {
        expect(request.url.path, '/sync/delta');
        final m = jsonDecode(request.body) as Map<String, dynamic>;
        expect(m['uid'], 'u1');
        expect(m['sources'], ['garmin', 'strava']);
        expect(m['lastSuccessfulSync'], expectedMs);
        return http.Response(jsonEncode({'success': true, 'message': 'ok'}), 200);
      });
      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://api.example',
      );
      final result = await svc.deltaSync(
        uid: 'u1',
        lastSuccessfulSync: Timestamp.fromDate(DateTime.utc(2024, 6, 1, 12)),
      );
      expect(result['success'], true);
    });

    test('deltaSync senza timestamp non invia lastSuccessfulSync', () async {
      final mock = MockClient((request) async {
        final m = jsonDecode(request.body) as Map<String, dynamic>;
        expect(m.containsKey('lastSuccessfulSync'), false);
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://api.example',
      );
      await svc.deltaSync(uid: 'u1');
    });

    test('registerStravaOnServer invia POST /strava/register-tokens', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/strava/register-tokens');
        final b = jsonDecode(request.body) as Map<String, dynamic>;
        expect(b['uid'], 'uid-s');
        expect(b['access_token'], 'acc');
        expect(b['refresh_token'], 'ref');
        expect(b['expires_at'], 99);
        return http.Response(jsonEncode({'success': true}), 200);
      });
      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://h.test',
      );
      final r = await svc.registerStravaOnServer(
        uid: 'uid-s',
        accessToken: 'acc',
        refreshToken: 'ref',
        expiresAtMs: 99,
      );
      expect(r['success'], true);
    });

    test('disconnect invia POST /garmin/disconnect', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/garmin/disconnect');
        return http.Response(
          jsonEncode({'success': true, 'message': 'disconnected'}),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://h.example',
      );
      final result = await svc.disconnect(uid: 'x');

      expect(result['success'], true);
    });

    test(
        'senza override: probe GET LAN default poi POST /garmin/sync-today',
        () async {
      final calls = <String>[];
      final mock = MockClient((request) async {
        calls.add('${request.method} ${request.url}');
        if (request.method == 'GET' &&
            request.url.host == '192.168.1.200' &&
            request.url.path == '/') {
          return http.Response('{"status":"ok"}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/garmin/sync-today') {
          return http.Response(
            jsonEncode({'success': true, 'message': 'ok'}),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final svc = GarminService(httpClient: mock);
      final result = await svc.syncToday(uid: 'uid-lan');

      expect(result['success'], true);
      expect(calls.length, greaterThanOrEqualTo(2));
      expect(calls.first, contains('GET'));
      expect(calls.first, contains('192.168.1.200'));
      expect(calls.any((c) => c.contains('/garmin/sync-today')), true);
    });
  });
}
