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
      expect(normalizeGarminServerBaseUrl('http://h:8080///'), 'http://h:8080');
    });
  });

  group('GarminService HTTP verso garmin-sync-server', () {
    test('connect2Start invia POST /garmin/connect2/start', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/garmin/connect2/start');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid'], 'u2');
        expect(body['email'], 'user@garmin.com');
        expect(body['password'], 'secret2');
        return http.Response(
          jsonEncode({
            'success': false,
            'mfaRequired': true,
            'loginSessionId': 'abc',
          }),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect2Start(
        uid: 'u2',
        email: 'user@garmin.com',
        password: 'secret2',
      );

      expect(result['mfaRequired'], true);
      expect(result['loginSessionId'], 'abc');
    });

    test('connect2Start estrae il loginUrl Garmin da un 429', () async {
      final garminSigninUrl =
          'https://sso.garmin.com/sso/signin?id=gauth-widget&service=https%3A%2F%2Fsso.garmin.com%2Fsso%2Fembed';
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'Error in request: 429 Client Error: Too Many Requests for url: $garminSigninUrl',
          }),
          429,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect2Start(
        uid: 'u2',
        email: 'user@garmin.com',
        password: 'secret2',
      );

      expect(result['success'], false);
      expect(result['loginUrl'], garminSigninUrl);
    });

    test('connect2VerifyMfa invia POST /garmin/connect2/verify-mfa', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/garmin/connect2/verify-mfa');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['uid'], 'u3');
        expect(body['login_session_id'], 'sess-1');
        expect(body['mfa_code'], '123456');
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok'}),
          200,
        );
      });

      final svc = GarminService(
        httpClient: mock,
        serverUrlOverride: 'https://example.test',
      );
      final result = await svc.connect2VerifyMfa(
        uid: 'u3',
        loginSessionId: 'sess-1',
        mfaCode: '123456',
      );

      expect(result['success'], true);
    });

    test(
      'connect3ExchangeTicket invia POST /garmin/connect3/exchange-ticket',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/garmin/connect3/exchange-ticket');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['uid'], 'u4');
          expect(body['ticket_or_url'], contains('ticket=ST-'));
          expect(body['email'], 'user@garmin.com');
          return http.Response(
            jsonEncode({'success': true, 'message': 'ok'}),
            200,
          );
        });

        final svc = GarminService(
          httpClient: mock,
          serverUrlOverride: 'https://example.test',
        );
        final result = await svc.connect3ExchangeTicket(
          uid: 'u4',
          ticketOrUrl: 'https://sso.garmin.com/sso/embed?ticket=ST-abc',
          email: 'user@garmin.com',
        );

        expect(result['success'], true);
      },
    );

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
      final expectedMs = DateTime.utc(2024, 6, 1, 12).millisecondsSinceEpoch;
      final mock = MockClient((request) async {
        expect(request.url.path, '/sync/delta');
        final m = jsonDecode(request.body) as Map<String, dynamic>;
        expect(m['uid'], 'u1');
        expect(m['sources'], ['garmin', 'strava']);
        expect(m['lastSuccessfulSync'], expectedMs);
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok'}),
          200,
        );
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
      },
    );
  });
}
