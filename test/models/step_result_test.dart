import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/models/step_result.dart';

void main() {
  group('DataleonStepResult', () {
    test('creates with required fields', () {
      // Use non-const to ensure constructor line is covered
      final result = DataleonStepResult(stepName: 'document', success: true);
      expect(result.stepName, 'document');
      expect(result.success, true);
      expect(result.data, isNull);
      expect(result.errorMessage, isNull);
    });

    test('creates with all fields', () {
      final result = DataleonStepResult(
        stepName: 'selfie',
        success: false,
        data: {'url': 'https://example.com/photo.jpg'},
        errorMessage: 'Face not detected',
      );
      expect(result.stepName, 'selfie');
      expect(result.success, false);
      expect(result.data!['url'], 'https://example.com/photo.jpg');
      expect(result.errorMessage, 'Face not detected');
    });
  });
}
