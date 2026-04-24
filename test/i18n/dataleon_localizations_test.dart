import 'package:flutter_test/flutter_test.dart';
import 'package:dataleon_flutter/i18n/dataleon_localizations.dart';

void main() {
  group('DataleonLocalizations', () {
    group('t() - basic translation lookup', () {
      test('returns French translation for valid key', () {
        final result = DataleonLocalizations.t('fr', 'common.close');
        expect(result, 'Fermer');
      });

      test('returns English translation', () {
        final result = DataleonLocalizations.t('en', 'common.close');
        expect(result, 'Close');
      });

      test('falls back to French when language not found', () {
        final result = DataleonLocalizations.t('zz', 'common.close');
        expect(result, 'Fermer');
      });

      test('returns key when translation not found', () {
        final result = DataleonLocalizations.t('fr', 'nonexistent.key');
        expect(result, 'nonexistent.key');
      });

      test('returns fallback when provided and key not found', () {
        final result = DataleonLocalizations.t(
          'fr',
          'nonexistent.key',
          fallback: 'default text',
        );
        expect(result, 'default text');
      });

      test('nested key resolution works', () {
        final result = DataleonLocalizations.t('fr', 'common.alreadyProcessedTitle');
        expect(result, 'Vérification terminée');
      });
    });

    group('t() - parameter interpolation', () {
      test('replaces {{param}} placeholders', () {
        // cameraCapture.frontLabel uses {{document}}
        final result = DataleonLocalizations.t(
          'fr',
          'cameraCapture.frontLabel',
          params: {'document': 'passeport'},
        );
        expect(result, contains('passeport'));
        expect(result, isNot(contains('{{document}}')));
      });

      test('multiple params are replaced', () {
        final result = DataleonLocalizations.t(
          'fr',
          'cameraCapture.frontLabel',
          params: {'document': 'carte'},
        );
        expect(result, contains('carte'));
      });

      test('empty params returns result as-is', () {
        final result = DataleonLocalizations.t(
          'fr',
          'common.close',
          params: {},
        );
        expect(result, 'Fermer');
      });
    });

    group('customDocLabel', () {
      test('returns translated label when label matches i18n key', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'label': 'common.close',
        });
        expect(label, 'Fermer');
      });

      test('skips label when translation equals label (no match)', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'label': 'some_unknown_label',
          'name': 'Fallback Name',
        });
        expect(label, 'Fallback Name');
      });

      test('returns name when present and no displayName', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'name': 'Mon Document',
        });
        expect(label, 'Mon Document');
      });

      test('returns displayNameFR for French', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'displayNameFR': 'Facture',
          'displayNameEN': 'Invoice',
        });
        expect(label, 'Facture');
      });

      test('returns displayNameEN for English', () {
        final label = DataleonLocalizations.customDocLabel('en', {
          'displayNameFR': 'Facture',
          'displayNameEN': 'Invoice',
        });
        expect(label, 'Invoice');
      });

      test('EN falls back to FR when EN is empty', () {
        final label = DataleonLocalizations.customDocLabel('en', {
          'displayNameFR': 'Facture',
          'displayNameEN': '',
        });
        expect(label, 'Facture');
      });

      test('falls back to displayNameEN when FR is empty', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'displayNameFR': '',
          'displayNameEN': 'Invoice',
        });
        expect(label, 'Invoice');
      });

      test('other language tries FR first then EN', () {
        final label = DataleonLocalizations.customDocLabel('es', {
          'displayNameFR': 'Facture ES',
          'displayNameEN': 'Invoice ES',
        });
        expect(label, 'Facture ES');
      });

      test('other language falls back to EN when FR empty', () {
        final label = DataleonLocalizations.customDocLabel('de', {
          'displayNameFR': '',
          'displayNameEN': 'Invoice DE',
        });
        expect(label, 'Invoice DE');
      });

      test('falls back to labelKey translation', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'labelKey': 'documentListType.invoice',
        });
        expect(label, 'Facture');
      });

      test('falls back to key when nothing else available', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'key': 'invoice_custom',
        });
        expect(label, 'invoice_custom');
      });

      test('returns empty string when doc is empty', () {
        final label = DataleonLocalizations.customDocLabel('fr', {});
        expect(label, '');
      });

      test('prefers displayNameFR over name for fr', () {
        final label = DataleonLocalizations.customDocLabel('fr', {
          'displayNameFR': 'Facture FR',
          'name': 'Generic Invoice',
        });
        expect(label, 'Facture FR');
      });
    });

    group('Error translations', () {
      test('French error title exists', () {
        final result = DataleonLocalizations.t('fr', 'common.errorTitle');
        expect(result, 'Une erreur est survenue');
      });

      test('English error title exists', () {
        final result = DataleonLocalizations.t('en', 'common.errorTitle');
        expect(result, 'An error occurred');
      });

      test('French error description exists', () {
        final result = DataleonLocalizations.t('fr', 'common.errorDesc');
        expect(result, isNotEmpty);
        expect(result, isNot('common.errorDesc'));
      });

      test('French retry text exists', () {
        final result = DataleonLocalizations.t('fr', 'common.retry');
        expect(result, 'Réessayer');
      });
    });

    group('standardDocLabelKeys', () {
      test('contains expected standard document types', () {
        expect(
          DataleonLocalizations.standardDocLabelKeys.containsKey('invoice'),
          true,
        );
        expect(
          DataleonLocalizations.standardDocLabelKeys.containsKey('kbis'),
          true,
        );
        expect(
          DataleonLocalizations.standardDocLabelKeys.containsKey('rib'),
          true,
        );
      });
    });

    group('enrichCustomDoc', () {
      test('adds labelKey for standard doc', () {
        final enriched = DataleonLocalizations.enrichCustomDoc(
          {'key': 'invoice', 'name': 'My Invoice'},
          [],
        );
        expect(enriched['labelKey'], 'documentListType.invoice');
        expect(enriched['name'], 'My Invoice');
      });

      test('merges properties_validators by key', () {
        final enriched = DataleonLocalizations.enrichCustomDoc(
          {'key': 'invoice'},
          [
            {'key': 'invoice', 'maxPages': 5},
            {'key': 'receipt', 'maxPages': 1},
          ],
        );
        expect(enriched['maxPages'], 5);
      });

      test('does not add labelKey for unknown doc', () {
        final enriched = DataleonLocalizations.enrichCustomDoc(
          {'key': 'unknown_doc'},
          [],
        );
        expect(enriched.containsKey('labelKey'), false);
        expect(enriched['key'], 'unknown_doc');
      });

      test('works with empty key', () {
        final enriched = DataleonLocalizations.enrichCustomDoc(
          {},
          [],
        );
        expect(enriched.containsKey('labelKey'), false);
      });

      test('validator overrides doc fields', () {
        final enriched = DataleonLocalizations.enrichCustomDoc(
          {'key': 'invoice', 'maxPages': 1},
          [
            {'key': 'invoice', 'maxPages': 10},
          ],
        );
        expect(enriched['maxPages'], 10);
      });
    });
  });
}
