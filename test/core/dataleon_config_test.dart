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

    test('appVersion defaults to 2.0.8', () {
      final config = DataleonConfig(sessionId: 's', token: 'jwt');
      expect(config.appVersion, '2.0.8');
    });

    test('appVersion can be overridden', () {
      final config = DataleonConfig(
        sessionId: 's',
        token: 'jwt',
        appVersion: '3.0.0',
      );
      expect(config.appVersion, '3.0.0');
    });

    group('baseUrl', () {
      test('always returns the hardcoded Dataleon URL', () {
        final config = DataleonConfig(sessionId: 's', token: 'jwt');
        expect(config.baseUrl, 'https://inference.eu-west-1.dataleon.ai');
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

    group('customerAssetsBucket', () {
      test('defaults to yap-assets-customer', () {
        final config = DataleonConfig(sessionId: 's', token: 'jwt');
        expect(config.customerAssetsBucket, 'yap-assets-customer');
      });

      test('can be overridden', () {
        final config = DataleonConfig(
          sessionId: 's',
          token: 'jwt',
          customerAssetsBucket: 'my-assets-bucket',
        );
        expect(config.customerAssetsBucket, 'my-assets-bucket');
      });
    });

    group('initialLanguage', () {
      test('is null by default', () {
        final config = DataleonConfig(sessionId: 's', token: 'jwt');
        expect(config.initialLanguage, isNull);
      });

      test('can be set', () {
        final config = DataleonConfig(
          sessionId: 's',
          token: 'jwt',
          initialLanguage: 'en',
        );
        expect(config.initialLanguage, 'en');
      });
    });

    test('dispose() can be called without error', () {
      final config = DataleonConfig(sessionId: 's', token: 'jwt');
      expect(() => config.dispose(), returnsNormally);
    });
  });
}
