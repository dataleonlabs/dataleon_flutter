import 'package:dataleon_flutter/screens/capture_validations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Réponse de /verifications/personal-data-checking telle que renvoyée par
/// l'API : ni `success` ni `status`, les refus sont dans `validations[].validate`.
Map<String, dynamic> personalDataResponse([Map<String, bool> overrides = const {}]) {
  final values = <String, bool>{
    'FullName': true,
    'Country': true,
    'ExpirationDate': true,
    'Age18': true,
    'MrzChecksum': true,
    ...overrides,
  };
  return {
    'entities': <dynamic>[],
    'validations': values.entries
        .map((e) => {'name': e.key, 'code': e.key, 'validate': e.value})
        .toList(),
  };
}

void main() {
  group('captureValidationDefs', () {
    test('passport front (no back phase) checks the 4 blocking controls', () {
      final defs =
          captureValidationDefs(phase: 'front', hasBackPhase: false, lang: 'fr');
      expect(defs.first.path, contains('personal-data-checking'));
      expect(defs.first.wait, isTrue);
      expect(defs.first.validations,
          ['FullName', 'Country', 'ExpirationDate', 'Age18']);
      expect(defs.last.wait, isFalse);
    });

    test('no validation after the front when a back phase follows', () {
      expect(
          captureValidationDefs(phase: 'front', hasBackPhase: true, lang: 'fr'),
          isEmpty);
    });

    test('face phase checks FaceSimilarity', () {
      final defs =
          captureValidationDefs(phase: 'face', hasBackPhase: false, lang: 'fr');
      expect(defs.first.validations, ['FaceSimilarity']);
      expect(defs.first.wait, isTrue);
    });
  });

  group('captureValidationFailure', () {
    final personal =
        captureValidationDefs(phase: 'front', hasBackPhase: false, lang: 'fr')
            .first;
    final similarity =
        captureValidationDefs(phase: 'face', hasBackPhase: false, lang: 'fr')
            .first;

    test('passes when every expected control is valid', () {
      expect(captureValidationFailure(personalDataResponse(), personal), isNull);
    });

    test('fails on an expired document with the dedicated message', () {
      final failure = captureValidationFailure(
          personalDataResponse({'ExpirationDate': false}), personal);
      expect(failure?.name, 'ExpirationDate');
      expect(failure?.message, personal.errorMessages['ExpirationDate']);
      expect(failure?.message, contains('expiré'));
    });

    test('fails on a name mismatch, a minor and a country mismatch', () {
      expect(
          captureValidationFailure(
                  personalDataResponse({'FullName': false}), personal)
              ?.name,
          'FullName');
      expect(
          captureValidationFailure(personalDataResponse({'Age18': false}), personal)
              ?.name,
          'Age18');
      expect(
          captureValidationFailure(
                  personalDataResponse({'Country': false}), personal)
              ?.name,
          'Country');
    });

    test('reports the first failing control in response order', () {
      final failure = captureValidationFailure(
          personalDataResponse({'FullName': false, 'ExpirationDate': false}),
          personal);
      expect(failure?.name, 'FullName');
    });

    test('ignores failing controls that are not expected by the definition', () {
      expect(
          captureValidationFailure(
              personalDataResponse({'MrzChecksum': false}), personal),
          isNull);
    });

    test('ignores a missing or null validate value', () {
      final r = <String, dynamic>{
        'validations': [
          {'name': 'ExpirationDate'},
          {'name': 'FullName', 'validate': null},
        ],
      };
      expect(captureValidationFailure(r, personal), isNull);
    });

    test('reads validations nested under data', () {
      final r = <String, dynamic>{
        'data': personalDataResponse({'ExpirationDate': false}),
      };
      expect(captureValidationFailure(r, personal)?.name, 'ExpirationDate');
    });

    test('fails on a face mismatch with the generic face message', () {
      final r = <String, dynamic>{
        'validations': [
          {'name': 'FaceSimilarity', 'validate': false},
        ],
      };
      expect(
        captureValidationFailure(r, similarity),
        CaptureValidationFailure(
            name: 'FaceSimilarity', message: similarity.errorMessage),
      );
    });

    test('keeps the historical global flags (success/status/error)', () {
      expect(
        captureValidationFailure({'success': false}, personal),
        CaptureValidationFailure(name: null, message: personal.errorMessage),
      );
      expect(captureValidationFailure({'status': false}, personal), isNotNull);
      expect(captureValidationFailure({'error': 'boom'}, personal), isNotNull);
      expect(
          captureValidationFailure({
            'data': {'success': false}
          }, personal),
          isNotNull);
    });

    test('returns null for an empty or null response', () {
      expect(captureValidationFailure(<String, dynamic>{}, personal), isNull);
      expect(captureValidationFailure(null, personal), isNull);
    });

    test('falls back to French messages for languages without translations', () {
      final de =
          captureValidationDefs(phase: 'front', hasBackPhase: false, lang: 'de')
              .first;
      expect(de.errorMessages['ExpirationDate'],
          personal.errorMessages['ExpirationDate']);
    });
  });
}
