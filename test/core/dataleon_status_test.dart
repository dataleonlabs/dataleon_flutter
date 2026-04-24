import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/core/dataleon_status.dart';

void main() {
  group('DataleonStatus', () {
    test('has 7 values', () {
      expect(DataleonStatus.values.length, 7);
    });

    test('.value returns correct strings', () {
      expect(DataleonStatus.idle.value, 'IDLE');
      expect(DataleonStatus.started.value, 'STARTED');
      expect(DataleonStatus.finished.value, 'FINISHED');
      expect(DataleonStatus.canceled.value, 'CANCELED');
      expect(DataleonStatus.failed.value, 'FAILED');
      expect(DataleonStatus.error.value, 'ERROR');
      expect(DataleonStatus.aborted.value, 'ABORTED');
    });
  });
}
