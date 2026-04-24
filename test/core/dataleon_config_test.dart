import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/core/dataleon_config.dart';

void main() {
  group('DataleonConfig', () {
    test('requires sessionId and apiKey', () {
      final config = DataleonConfig(
        sessionId: 'test-session',
        apiKey: 'test-key',
      );
      expect(config.sessionId, 'test-session');
      expect(config.apiKey, 'test-key');
    });

    test('appVersion defaults to 2.0.0-beta', () {
      final config = DataleonConfig(
        sessionId: 's',
        apiKey: 'k',
      );
      expect(config.appVersion, '2.0.0-beta');
    });

    test('appVersion can be overridden', () {
      final config = DataleonConfig(
        sessionId: 's',
        apiKey: 'k',
        appVersion: '2.0.0',
      );
      expect(config.appVersion, '2.0.0');
    });

    group('baseUrl', () {
      test('returns default URL when apiBaseUrl is null', () {
        final config = DataleonConfig(sessionId: 's', apiKey: 'k');
        expect(config.baseUrl, 'https://inference.eu-west-1.dataleon.ai');
      });

      test('returns default URL when apiBaseUrl is empty', () {
        final config = DataleonConfig(
          sessionId: 's',
          apiKey: 'k',
          apiBaseUrl: '',
        );
        expect(config.baseUrl, 'https://inference.eu-west-1.dataleon.ai');
      });

      test('returns custom URL when apiBaseUrl is provided', () {
        final config = DataleonConfig(
          sessionId: 's',
          apiKey: 'k',
          apiBaseUrl: 'https://custom.api.com',
        );
        expect(config.baseUrl, 'https://custom.api.com');
      });
    });

    group('sessionToken', () {
      test('returns sessionId when no token has been set', () {
        final config = DataleonConfig(sessionId: 'my-uuid', apiKey: 'k');
        expect(config.sessionToken, 'my-uuid');
      });

      test('returns JWT after setting sessionToken', () {
        final config = DataleonConfig(sessionId: 'my-uuid', apiKey: 'k');
        config.sessionToken = 'jwt-token-xyz';
        expect(config.sessionToken, 'jwt-token-xyz');
      });

      test('sessionId remains unchanged after setting token', () {
        final config = DataleonConfig(sessionId: 'my-uuid', apiKey: 'k');
        config.sessionToken = 'jwt-token-xyz';
        expect(config.sessionId, 'my-uuid');
      });
    });

    test('uploadBucket is null by default', () {
      final config = DataleonConfig(sessionId: 's', apiKey: 'k');
      expect(config.uploadBucket, isNull);
    });

    test('uploadBucket can be set', () {
      final config = DataleonConfig(
        sessionId: 's',
        apiKey: 'k',
        uploadBucket: 'my-bucket',
      );
      expect(config.uploadBucket, 'my-bucket');
    });
  });
}
