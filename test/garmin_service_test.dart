import 'dart:convert';

import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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

    test('syncNow invia POST /garmin/sync-vitals con uid', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/garmin/sync-vitals');
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
      final result = await svc.syncNow(uid: 'uid-2');

      expect(result['success'], true);
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
  });
}
