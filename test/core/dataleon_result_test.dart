import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/core/dataleon_result.dart';
import 'package:dataleon_flutter/core/dataleon_status.dart';

void main() {
  group('DataleonResult', () {
    test('creates with status only', () {
      const result = DataleonResult(status: DataleonStatus.finished);
      expect(result.status, DataleonStatus.finished);
      expect(result.error, isNull);
    });

    test('creates with status and error', () {
      const result = DataleonResult(
        status: DataleonStatus.error,
        error: 'Something went wrong',
      );
      expect(result.status, DataleonStatus.error);
      expect(result.error, 'Something went wrong');
    });

    test('idle is the initial status', () {
      const result = DataleonResult(status: DataleonStatus.idle);
      expect(result.status, DataleonStatus.idle);
    });
  });
}
