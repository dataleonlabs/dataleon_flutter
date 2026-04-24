import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/models/session.dart';

void main() {
  group('DataleonSession', () {
    test('fromJson with complete data', () {
      final session = DataleonSession.fromJson({
        'id': 'abc-123',
        'status': 'active',
        'metadata': {'key': 'value'},
      });
      expect(session.id, 'abc-123');
      expect(session.status, 'active');
      expect(session.metadata, {'key': 'value'});
    });

    test('fromJson with missing id defaults to empty string', () {
      final session = DataleonSession.fromJson({'status': 'done'});
      expect(session.id, '');
    });

    test('fromJson with missing status defaults to unknown', () {
      final session = DataleonSession.fromJson({'id': 'abc'});
      expect(session.status, 'unknown');
    });

    test('fromJson with null metadata', () {
      final session = DataleonSession.fromJson({
        'id': 'abc',
        'status': 'active',
      });
      expect(session.metadata, isNull);
    });

    test('fromJson with empty map', () {
      final session = DataleonSession.fromJson({});
      expect(session.id, '');
      expect(session.status, 'unknown');
      expect(session.metadata, isNull);
    });

    test('constructor creates directly', () {
      const session = DataleonSession(id: 'x', status: 'ready');
      expect(session.id, 'x');
      expect(session.status, 'ready');
    });
  });
}
