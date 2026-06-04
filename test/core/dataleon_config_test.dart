import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/core/dataleon_config.dart';

void main() {
  group('DataleonConfig', () {
    test('requires sessionId and token', () {
      final config = DataleonConfig(
        sessionId: 'test-session',
        token: 'jwt-token',
      );
      expect(config.sessionId, 'test-session');
      expect(config.token, 'jwt-token');
    });

    test('appVersion defaults to 2.0.0-beta', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
      );
      expect(config.appVersion, '2.0.0-beta');
    });

    test('appVersion can be overridden', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
        appVersion: '2.0.0',
      );
      expect(config.appVersion, '2.0.0');
    });

    group('baseUrl', () {
      test('returns default URL when apiBaseUrl is null', () {
        final config = DataleonConfig(sessionId: 's', token: 'jwt');
        expect(config.baseUrl, 'https://iron-gpu.dataleon.ai');
      });

      test('returns default URL when apiBaseUrl is empty', () {
        final config = DataleonConfig(
          sessionId: 's',
          token: 'jwt',
          apiBaseUrl: '',
        );
        expect(config.baseUrl, 'https://iron-gpu.dataleon.ai');
      });

      test('returns custom URL when apiBaseUrl is provided', () {
        final config = DataleonConfig(
          sessionId: 's',
          token: 'jwt',
          apiBaseUrl: 'https://custom.api.com',
        );
        expect(config.baseUrl, 'https://custom.api.com');
      });
    });

    test('sessionToken returns provided token', () {
      final config = DataleonConfig(
        sessionId: 'my-uuid',
        token: 'jwt-token-xyz',
      );
      expect(config.sessionToken, 'jwt-token-xyz');
    });

    test('accountTenant is null by default', () {
      final config = DataleonConfig(sessionId: 's', token: 'jwt');
      expect(config.accountTenant, isNull);
      expect(config.accountTenantHeader, isNull);
    });

    test('accountTenantHeader returns tenant when provided', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
        accountTenant: 'tenant-123',
      );
      expect(config.accountTenant, 'tenant-123');
      expect(config.accountTenantHeader, 'tenant-123');
    });

    test('accountTenantHeader returns null when accountTenant is empty', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
        accountTenant: '',
      );
      expect(config.accountTenantHeader, isNull);
    });

    test('uploadBucket is null by default', () {
      final config = DataleonConfig(sessionId: 's', token: 'jwt');
      expect(config.uploadBucket, isNull);
    });

    test('uploadBucket can be set', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
        uploadBucket: 'my-bucket',
      );
      expect(config.uploadBucket, 'my-bucket');
    });
  });
}
