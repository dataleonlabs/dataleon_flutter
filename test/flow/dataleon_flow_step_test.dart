import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_step.dart';

void main() {
  group('DataleonFlowStep', () {
    test('has 13 values', () {
      expect(DataleonFlowStep.values.length, 12);
    });

    test('values are in expected order', () {
      expect(DataleonFlowStep.values, [
        DataleonFlowStep.loading,
        DataleonFlowStep.alreadyProcessed,
        DataleonFlowStep.error,
        DataleonFlowStep.welcome,
        DataleonFlowStep.cameraPermission,
        DataleonFlowStep.documentType,
        DataleonFlowStep.documentCountry,
        DataleonFlowStep.document,
        DataleonFlowStep.selfie,
        DataleonFlowStep.review,
        DataleonFlowStep.submitting,
        DataleonFlowStep.success,
      ]);
    });
  });
}
