import 'dart:convert';

import 'package:fitai_analyzer/services/garmin_oauth1_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GarminOAuth1Client.oauth1Signature', () {
    // Vettore ufficiale Twitter/RFC 5849 per HMAC‑SHA1: se la nostra firma lo
    // riproduce, percent‑encoding, ordinamento, base string e signing key sono
    // corretti (è il punto che, se sbagliato, fa fallire `preauthorized` con 401).
    test('riproduce il vettore OAuth1 noto', () {
      final sig = GarminOAuth1Client.oauth1Signature(
        method: 'POST',
        baseUrl: 'https://api.twitter.com/1/statuses/update.json',
        params: {
          'status': 'Hello Ladies + Gentlemen, a signed OAuth request!',
          'include_entities': 'true',
          'oauth_consumer_key': 'xvz1evFS4wEEPTGEFPHBog',
          'oauth_nonce': 'kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg',
          'oauth_signature_method': 'HMAC-SHA1',
          'oauth_timestamp': '1318622958',
          'oauth_token': '370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb',
          'oauth_version': '1.0',
        },
        consumerSecret: 'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Y7uw',
        tokenSecret: 'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE',
      );
      // HMAC‑SHA1 canonico della base string documentata di questo vettore.
      expect(sig, 'PJEmSpxP7orpc98C3iDu9/aNHJk=');
    });

    test('firma 2‑legged (token secret vuoto) è deterministica', () {
      final params = {
        'ticket': 'ST-123',
        'login-url': 'https://sso.garmin.com/sso/embed',
        'accepts-mfa-tokens': 'true',
        'oauth_consumer_key': 'ck',
        'oauth_nonce': 'nonce123',
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': '1700000000',
        'oauth_version': '1.0',
      };
      final a = GarminOAuth1Client.oauth1Signature(
        method: 'GET',
        baseUrl:
            'https://connectapi.garmin.com/oauth-service/oauth/preauthorized',
        params: params,
        consumerSecret: 'cs',
        tokenSecret: '',
      );
      final b = GarminOAuth1Client.oauth1Signature(
        method: 'GET',
        baseUrl:
            'https://connectapi.garmin.com/oauth-service/oauth/preauthorized',
        params: params,
        consumerSecret: 'cs',
        tokenSecret: '',
      );
      expect(a, b);
      expect(a, isNotEmpty);
    });
  });

  group('GarminOAuth1Client.buildGarthTokenB64', () {
    test('produce [oauth1, oauth2] con i campi attesi da garth.loads()', () {
      final client = GarminOAuth1Client();
      final tokenB64 = client.buildGarthTokenB64(
        oauth1: {'oauth_token': 'OT', 'oauth_token_secret': 'OTS'},
        oauth2Raw: {
          'scope': 'CONNECT_READ',
          'jti': 'JTI',
          'token_type': 'Bearer',
          'access_token': 'AT',
          'refresh_token': 'RT',
          'expires_in': 3600,
          'refresh_token_expires_in': 7200,
          // Chiave extra: deve essere scartata, altrimenti OAuth2Token(**oauth2)
          // sul server fallirebbe.
          'customerId': 'da-scartare',
        },
      );

      final decoded = jsonDecode(utf8.decode(base64.decode(tokenB64))) as List;
      expect(decoded.length, 2);

      final o1 = decoded[0] as Map<String, dynamic>;
      expect(o1.keys.toSet(), {
        'oauth_token',
        'oauth_token_secret',
        'mfa_token',
        'mfa_expiration_timestamp',
        'domain',
      });
      expect(o1['oauth_token'], 'OT');
      expect(o1['oauth_token_secret'], 'OTS');
      expect(o1['mfa_token'], isNull);
      expect(o1['mfa_expiration_timestamp'], isNull);
      expect(o1['domain'], 'garmin.com');

      final o2 = decoded[1] as Map<String, dynamic>;
      expect(o2.keys.toSet(), {
        'scope',
        'jti',
        'token_type',
        'access_token',
        'refresh_token',
        'expires_in',
        'expires_at',
        'refresh_token_expires_in',
        'refresh_token_expires_at',
      });
      expect(o2.containsKey('customerId'), isFalse);
      expect(o2['expires_in'], 3600);
      expect(o2['refresh_token_expires_in'], 7200);
      // expires_at/refresh_token_expires_at calcolati (now + expires_in).
      expect(o2['expires_at'], greaterThan(o2['expires_in'] as int));
      expect(
        o2['refresh_token_expires_at'],
        greaterThan(o2['expires_at'] as int),
      );
    });

    test('propaga mfa_token e usa expires_at dal server se presente', () {
      final client = GarminOAuth1Client();
      final tokenB64 = client.buildGarthTokenB64(
        oauth1: {
          'oauth_token': 'OT',
          'oauth_token_secret': 'OTS',
          'mfa_token': 'MFA',
        },
        oauth2Raw: {
          'scope': 'CONNECT_READ',
          'jti': 'JTI',
          'token_type': 'Bearer',
          'access_token': 'AT',
          'refresh_token': 'RT',
          'expires_in': 3600,
          'expires_at': 99999999999,
          'refresh_token_expires_in': 7200,
          'refresh_token_expires_at': 99999999999,
        },
      );
      final decoded = jsonDecode(utf8.decode(base64.decode(tokenB64))) as List;
      expect((decoded[0] as Map)['mfa_token'], 'MFA');
      expect((decoded[1] as Map)['expires_at'], 99999999999);
      expect((decoded[1] as Map)['refresh_token_expires_at'], 99999999999);
    });
  });
}
