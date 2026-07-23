import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dataleon_flutter/core/dataleon_config.dart';
import 'package:dataleon_flutter/core/dataleon_status.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_controller.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_step.dart';
import 'package:dataleon_flutter/models/step_result.dart';
import 'package:dataleon_flutter/services/dataleon_api_service.dart';

void main() {
  late DataleonConfig config;
  late DataleonFlowController controller;

  setUp(() {
    config = DataleonConfig(sessionId: 'sid', token: 'jwt');
  });

  tearDown(() {
    controller.dispose();
  });

  DataleonFlowController createController({
    DataleonApiService? apiService,
    List<DataleonFlowStep>? steps,
  }) {
    controller = DataleonFlowController(
      config: config,
      apiService: apiService,
      steps: steps,
    );
    return controller;
  }

  group('Initial state', () {
    test('starts at loading step', () {
      createController();
      expect(controller.currentStep, DataleonFlowStep.loading);
      expect(controller.currentIndex, 0);
    });

    test('result is idle', () {
      createController();
      expect(controller.result.status, DataleonStatus.idle);
      expect(controller.result.error, isNull);
    });

    test('is not loading', () {
      createController();
      expect(controller.isLoading, false);
    });

    test('progress is 0', () {
      createController();
      expect(controller.progress, 0);
    });

    test('documentType is null', () {
      createController();
      expect(controller.documentType, isNull);
    });

    test('documentCountry is null', () {
      createController();
      expect(controller.documentCountry, isNull);
    });

    test('default steps list has all steps', () {
      createController();
      expect(controller.steps.length, 14);
      expect(controller.steps.first, DataleonFlowStep.loading);
      expect(controller.steps.last, DataleonFlowStep.success);
    });

    test('uses custom steps when provided', () {
      createController(steps: [
        DataleonFlowStep.welcome,
        DataleonFlowStep.document,
        DataleonFlowStep.success,
      ]);
      expect(controller.steps.length, 3);
    });

    test('exposes config', () {
      createController();
      expect(controller.config.sessionId, 'sid');
    });

    test('exposes apiService', () {
      final client = MockClient((request) async => http.Response('', 200));
      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);
      expect(controller.apiService, same(apiService));
    });

    test('progress starts at 0', () {
      createController();
      expect(controller.progress, 0.0);
    });
  });

  group('Navigation', () {
    test('nextStep advances by one', () {
      createController();
      controller.nextStep();
      expect(controller.currentIndex, 1);
      expect(controller.currentStep, DataleonFlowStep.alreadyProcessed);
    });

    test('nextStep at last step calls finish', () {
      createController(steps: [
        DataleonFlowStep.welcome,
        DataleonFlowStep.success,
      ]);
      controller.nextStep(); // go to success (index 1)
      controller.nextStep(); // at last step, should finish
      expect(controller.result.status, DataleonStatus.finished);
    });

    test('previousStep goes back by one', () {
      createController();
      controller.nextStep();
      controller.nextStep();
      expect(controller.currentIndex, 2);
      controller.previousStep();
      expect(controller.currentIndex, 1);
    });

    test('previousStep at first step does nothing', () {
      createController();
      controller.previousStep();
      expect(controller.currentIndex, 0);
    });

    test('goToStep navigates to correct step', () {
      createController();
      controller.goToStep(DataleonFlowStep.welcome);
      expect(controller.currentStep, DataleonFlowStep.welcome);
    });

    test('goToStep with invalid step does nothing', () {
      createController(steps: [
        DataleonFlowStep.welcome,
        DataleonFlowStep.success,
      ]);
      controller.goToStep(DataleonFlowStep.selfie); // not in the list
      expect(controller.currentIndex, 0);
    });

    test('isLastStep returns true at last step', () {
      createController(steps: [
        DataleonFlowStep.welcome,
        DataleonFlowStep.success,
      ]);
      expect(controller.isLastStep, false);
      controller.nextStep();
      expect(controller.isLastStep, true);
    });
  });

  group('Status transitions', () {
    test('start sets status to started', () {
      createController();
      controller.start();
      expect(controller.result.status, DataleonStatus.started);
    });

    test('finish sets status to finished', () {
      createController();
      controller.finish();
      expect(controller.result.status, DataleonStatus.finished);
    });

    test('cancel sets status to canceled', () {
      createController();
      controller.cancel();
      expect(controller.result.status, DataleonStatus.canceled);
    });

    test('fail sets status to failed with error', () {
      createController();
      controller.fail('something broke');
      expect(controller.result.status, DataleonStatus.failed);
      expect(controller.result.error, 'something broke');
    });

    test('fail without error message', () {
      createController();
      controller.fail();
      expect(controller.result.status, DataleonStatus.failed);
      expect(controller.result.error, isNull);
    });

    test('setError sets status to error', () {
      createController();
      controller.setError('network down');
      expect(controller.result.status, DataleonStatus.error);
      expect(controller.result.error, 'network down');
    });

    test('abort sets status to aborted', () {
      createController();
      controller.abort();
      expect(controller.result.status, DataleonStatus.aborted);
    });
  });

  group('Loading & progress', () {
    test('setLoading updates loading state', () {
      createController();
      controller.setLoading(true);
      expect(controller.isLoading, true);
      controller.setLoading(false);
      expect(controller.isLoading, false);
    });

    test('updateProgress clamps to 0-100', () {
      createController();
      controller.updateProgress(50);
      expect(controller.progress, 50);

      controller.updateProgress(-10);
      expect(controller.progress, 0);

      controller.updateProgress(150);
      expect(controller.progress, 100);
    });
  });

  group('Document selection', () {
    test('selectDocumentType sets type', () {
      createController();
      controller.selectDocumentType('passport');
      expect(controller.documentType, 'passport');
      expect(controller.selectedCustomDocument, isNull);
    });

    test('selectDocumentType with custom document', () {
      createController();
      controller
          .selectDocumentType('custom', customDocument: {'key': 'invoice'});
      expect(controller.documentType, 'custom');
      expect(controller.selectedCustomDocument!['key'], 'invoice');
    });

    test('selectDocumentCountry sets country', () {
      createController();
      controller.selectDocumentCountry('FR');
      expect(controller.documentCountry, 'FR');
    });

    test('selectDocumentCountry with null', () {
      createController();
      controller.selectDocumentCountry('FR');
      controller.selectDocumentCountry(null);
      expect(controller.documentCountry, isNull);
    });
  });

  group('Uploaded files', () {
    test('saveUploadedFile stores file info', () {
      createController();
      controller.saveUploadedFile(
        phase: 'front',
        url: 'https://s3/front.jpg',
        name: 'front.jpg',
        key: 'front-key',
      );
      expect(controller.uploadedFiles['front']!['url'], 'https://s3/front.jpg');
      expect(controller.uploadedFiles['front']!['name'], 'front.jpg');
      expect(controller.uploadedFiles['front']!['key'], 'front-key');
    });

    test('clearUploadedFiles empties the map', () {
      createController();
      controller.saveUploadedFile(
        phase: 'front',
        url: 'url',
        name: 'name',
        key: 'key',
      );
      controller.clearUploadedFiles();
      expect(controller.uploadedFiles, isEmpty);
    });
  });

  group('Step results', () {
    test('saveStepResult stores result', () {
      createController();
      const stepResult = DataleonStepResult(
        stepName: 'document',
        success: true,
        data: {'pages': 2},
      );
      controller.saveStepResult(DataleonFlowStep.document, stepResult);
      expect(controller.stepResults[DataleonFlowStep.document]!.success, true);
    });
  });

  group('reset', () {
    test('resets all state', () {
      createController();
      controller.start();
      controller.nextStep();
      controller.nextStep();
      controller.selectDocumentType('passport');
      controller.selectDocumentCountry('FR');
      controller.saveUploadedFile(
        phase: 'front',
        url: 'url',
        name: 'name',
        key: 'key',
      );

      controller.reset();

      expect(controller.currentIndex, 0);
      expect(controller.result.status, DataleonStatus.idle);
      expect(controller.isLoading, false);
      expect(controller.documentType, isNull);
      expect(controller.documentCountry, isNull);
      expect(controller.selectedCustomDocument, isNull);
      expect(controller.uploadedFiles, isEmpty);
      expect(controller.stepResults, isEmpty);
    });
  });

  group('Notifier', () {
    test('nextStep notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.nextStep();
      expect(notified, true);
    });

    test('start notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.start();
      expect(notified, true);
    });

    test('setLoading notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.setLoading(true);
      expect(notified, true);
    });

    test('updateProgress notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.updateProgress(42);
      expect(notified, true);
    });
  });

  group('hasWorldCountryForDocType', () {
    test('returns false for null docType', () {
      createController();
      expect(controller.hasWorldCountryForDocType(null), false);
    });

    test('returns false for empty docType', () {
      createController();
      expect(controller.hasWorldCountryForDocType(''), false);
    });

    test('returns false when no dashboard config', () {
      createController();
      expect(controller.hasWorldCountryForDocType('passport'), false);
    });

    test('returns true when countries list contains world', () async {
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'kycCountries': {
            'passport': [
              {'key': 'FR', 'label': 'France'},
              {'key': 'world', 'label': 'Monde'},
            ],
          },
        },
      });

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {'workspace': workspace},
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);
      await controller.fetchConfig();

      expect(controller.hasWorldCountryForDocType('passport'), true);
    });

    test('returns false when countries list has no world', () async {
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'kycCountries': {
            'passport': [
              {'key': 'FR', 'label': 'France'},
            ],
          },
        },
      });

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {'workspace': workspace},
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);
      await controller.fetchConfig();

      expect(controller.hasWorldCountryForDocType('passport'), false);
    });
  });

  group('formStepForAction', () {
    test('returns null when no form steps', () {
      createController();
      expect(controller.formStepForAction('capture'), isNull);
    });
  });

  group('fetchConfig', () {
    test('navigates to welcome on successful config', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {
                'language': 'fr',
              },
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.currentStep, DataleonFlowStep.welcome);
      expect(controller.isLoading, false);
      expect(controller.languageCode, 'fr');
    });

    test('navigates to alreadyProcessed when config has error true', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': true,
            'message': 'Already processed',
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.currentStep, DataleonFlowStep.alreadyProcessed);
      expect(controller.configErrorMessage, 'Already processed');
    });

    test('navigates to alreadyProcessed on 403 error', () async {
      final client = MockClient((request) async {
        return http.Response('Forbidden', 403);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.currentStep, DataleonFlowStep.alreadyProcessed);
    });

    test('navigates to error on non-403 API error', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.currentStep, DataleonFlowStep.error);
    });

    test('parses workspace from metadata', () async {
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'languageApp': 'en',
        },
      });

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {
                'workspace': workspace,
              },
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.workspace, isNotNull);
      expect(
        controller.dashboardConfiguration['languageApp'],
        'en',
      );
    });

    test('parses webviewConfig YAML from workspace', () async {
      final yamlConfig =
          'form:\n  - page_action: capture\n    title: Photo\n  - page_action: review\n    title: Review';
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'webviewConfig': yamlConfig,
        },
      });

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {
                'workspace': workspace,
              },
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.webviewConfig, isNotEmpty);
      expect(controller.webviewConfig['form'], isList);
      expect(controller.formSteps.length, 2);
      expect(controller.formSteps[0]['page_action'], 'capture');
      expect(controller.formStepForAction('capture'), isNotNull);
      expect(controller.formStepForAction('nonexistent'), isNull);
    });

    test('uses webviewConfigEN for English language', () async {
      final yamlConfig =
          'form:\n  - page_action: capture_en\n    title: Photo EN';
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'webviewConfigEN': yamlConfig,
          'webviewConfig': 'form:\n  - page_action: capture_fr',
        },
      });

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {
                'workspace': workspace,
                'language': 'en',
              },
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.languageCode, 'en');
      expect(controller.webviewConfig['form'], isList);
      final actions =
          controller.formSteps.map((s) => s['page_action']).toList();
      expect(actions, contains('capture_en'));
    });
  });

  group('sanitizeLogoUrl', () {
    test('accepts https URLs', () {
      createController();
      expect(
        DataleonFlowController.sanitizeLogoUrl('https://cdn.example.com/l.png'),
        'https://cdn.example.com/l.png',
      );
    });

    test('upgrades http URLs to https', () {
      createController();
      // sanitizeLogoUrl réécrit délibérément http:// en https:// : le cleartext
      // est bloqué par défaut sur les plateformes modernes.
      expect(
        DataleonFlowController.sanitizeLogoUrl('http://example.com/l.png'),
        'https://example.com/l.png',
      );
    });

    test('rejects javascript: scheme', () {
      createController();
      expect(
        DataleonFlowController.sanitizeLogoUrl('javascript:alert(1)'),
        isNull,
      );
    });

    test('rejects data: scheme', () {
      createController();
      expect(
        DataleonFlowController.sanitizeLogoUrl('data:image/png;base64,AAAA'),
        isNull,
      );
    });

    test('resolves relative paths against the customer-assets bucket', () {
      createController();
      expect(
        DataleonFlowController.sanitizeLogoUrl('logos/acme.png'),
        'https://customer-assets.eu-west-1.dataleon.ai/logos/acme.png',
      );
    });

    test('returns null for null/empty', () {
      createController();
      expect(DataleonFlowController.sanitizeLogoUrl(null), isNull);
      expect(DataleonFlowController.sanitizeLogoUrl('   '), isNull);
    });
  });

  group('normalizeLanguage', () {
    test('maps ISO3 to ISO2', () {
      createController();
      expect(DataleonFlowController.normalizeLanguage('eng'), 'en');
      expect(DataleonFlowController.normalizeLanguage('fra'), 'fr');
      expect(DataleonFlowController.normalizeLanguage('deu'), 'de');
      expect(DataleonFlowController.normalizeLanguage('nld'), 'nl');
    });

    test('passes through ISO2 codes (lowercased)', () {
      createController();
      expect(DataleonFlowController.normalizeLanguage('EN'), 'en');
      expect(DataleonFlowController.normalizeLanguage('pt'), 'pt');
    });
  });

  group('loading branding / chart config', () {
    test('chart is unresolved before fetchConfig', () {
      createController();
      expect(controller.isChartResolved, isFalse);
      expect(controller.brandingLogoUrl, isNull);
      expect(controller.brandingAppName, isNull);
      expect(controller.brandingPrincipalColor, isNull);
    });

    test('stores sanitized branding and early language from chart', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/config/chart')) {
          return http.Response(
            jsonEncode({
              'applicationName': 'Acme',
              'principalColor': '#123456',
              'logoURLApp': 'https://cdn.example.com/logo.png',
              'languageApp': 'eng',
            }),
            200,
          );
        }
        // request/contents config
        return http.Response(
          jsonEncode({
            'result': {'metadata': {}},
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.isChartResolved, isTrue);
      expect(controller.brandingAppName, 'Acme');
      expect(controller.brandingPrincipalColor, '#123456');
      expect(controller.brandingLogoUrl, 'https://cdn.example.com/logo.png');
      // Definitive language unset by request config → keeps the chart language.
      expect(controller.languageCode, 'en');
      expect(controller.currentStep, DataleonFlowStep.welcome);
    });

    test('resolves the chart (exits spinner) even when chart call fails',
        () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/config/chart')) {
          return http.Response('Server Error', 500);
        }
        return http.Response(
          jsonEncode({
            'result': {'metadata': {}},
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.isChartResolved, isTrue);
      expect(controller.brandingLogoUrl, isNull);
      expect(controller.brandingPrincipalColor, isNull);
      expect(controller.currentStep, DataleonFlowStep.welcome);
    });

    test('drops unsafe logo URLs from the chart config', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/config/chart')) {
          return http.Response(
            jsonEncode({'logoURLApp': 'javascript:alert(1)'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': {'metadata': {}},
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.brandingLogoUrl, isNull);
    });

    test('request config language overrides the chart language', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/config/chart')) {
          return http.Response(jsonEncode({'languageApp': 'fra'}), 200);
        }
        return http.Response(
          jsonEncode({
            'result': {
              'metadata': {'language': 'eng'},
            },
          }),
          200,
        );
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.languageCode, 'en');
    });
  });

  group('submitStepData', () {
    test('returns response on success', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      final result = await controller.submitStepData(
        stepName: 'document',
        data: {'type': 'passport'},
      );

      expect(result['ok'], true);
      expect(controller.isLoading, false);
    });

    test('rethrows on failure and stops loading', () async {
      final client = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      expect(
        () => controller.submitStepData(stepName: 'doc', data: {}),
        throwsA(isA<DataleonApiException>()),
      );
    });
  });

  group('completeSession', () {
    test('finishes on success', () async {
      final client = MockClient((request) async {
        return http.Response('', 200);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.completeSession();

      expect(controller.result.status, DataleonStatus.finished);
      expect(controller.isLoading, false);
    });

    test('fails on error', () async {
      final client = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.completeSession();

      expect(controller.result.status, DataleonStatus.failed);
    });
  });

  group('webviewConfig', () {
    test('returns empty map when no dashboard config', () {
      createController();
      expect(controller.webviewConfig, isEmpty);
    });

    test('returns empty map when webviewConfig is empty string', () {
      createController();
      // No workspace set → dashboardConfiguration is empty
      expect(controller.webviewConfig, isEmpty);
    });
  });

  group('setLanguage', () {
    test('updates language code', () {
      createController();
      controller.setLanguage('en');
      expect(controller.languageCode, 'en');
    });

    test('notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.setLanguage('es');
      expect(notified, true);
    });
  });

  group('configErrorMessage', () {
    test('is null initially', () {
      createController();
      expect(controller.configErrorMessage, isNull);
    });
  });

  group('uploadFile', () {
    test('returns response on success', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'fileUrl': 'https://s3/file.jpg'}), 200);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      final result = await controller.uploadFile(
        stepName: 'document',
        fieldName: 'front',
        fileBytes: [1, 2, 3],
        fileName: 'front.jpg',
      );

      expect(result['fileUrl'], 'https://s3/file.jpg');
      expect(controller.isLoading, false);
    });

    test('rethrows on failure and stops loading', () async {
      final client = MockClient((request) async {
        return http.Response('Error', 500);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      expect(
        () => controller.uploadFile(
          stepName: 'doc',
          fieldName: 'front',
          fileBytes: [1, 2, 3],
          fileName: 'file.jpg',
        ),
        throwsA(isA<DataleonApiException>()),
      );
    });
  });

  group('requestResult', () {
    test('returns empty map when no config', () {
      createController();
      expect(controller.requestResult, isEmpty);
    });
  });

  group('Getters coverage', () {
    test('contentsConfig is empty by default', () {
      createController();
      expect(controller.contentsConfig, isEmpty);
    });

    test('activeChainedDocument is null by default', () {
      createController();
      expect(controller.activeChainedDocument, isNull);
    });

    test('selectedChainedDocumentOption is null by default', () {
      createController();
      expect(controller.selectedChainedDocumentOption, isNull);
    });

    test('pendingChainedDocuments is empty by default', () {
      createController();
      expect(controller.pendingChainedDocuments, isEmpty);
    });

    test('completedDocumentKeys is empty by default', () {
      createController();
      expect(controller.completedDocumentKeys, isEmpty);
    });

    test('hasCompletedChainedCustomDocuments is false by default', () {
      createController();
      expect(controller.hasCompletedChainedCustomDocuments, false);
    });

    test('customFontFamily is null by default', () {
      createController();
      expect(controller.customFontFamily, isNull);
    });

    test('customDocuments is empty by default', () {
      createController();
      expect(controller.customDocuments, isEmpty);
    });

    test('visibleCustomDocuments is empty by default', () {
      createController();
      expect(controller.visibleCustomDocuments, isEmpty);
    });
  });

  group('currentDocumentKey', () {
    test('returns null when no document selected', () {
      createController();
      expect(controller.currentDocumentKey, isNull);
    });

    test('returns documentType when set', () {
      createController();
      controller.selectDocumentType('passport');
      expect(controller.currentDocumentKey, 'passport');
    });

    test('returns customDocument key when present', () {
      createController();
      controller.selectDocumentType('custom', customDocument: {'key': 'invoice'});
      expect(controller.currentDocumentKey, 'invoice');
    });
  });

  group('selectChainedDocumentOption', () {
    test('sets null clears option', () {
      createController();
      controller.selectChainedDocumentOption(null);
      expect(controller.selectedChainedDocumentOption, isNull);
    });

    test('sets option with internalName updates documentType', () {
      createController();
      controller.selectChainedDocumentOption({
        'internalName': 'passport_internal',
      });
      expect(controller.documentType, 'passport_internal');
    });

    test('falls back to activeChainedDocument key when no internalName', () {
      createController();
      // Simulate active chained document via beginChainedDocument
      controller.beginChainedDocument({'key': 'kyb_doc'});
      controller.selectChainedDocumentOption({'label': 'Option A'});
      expect(controller.documentType, 'kyb_doc');
    });

    test('notifies listeners', () {
      createController();
      var notified = false;
      controller.addListener(() => notified = true);
      controller.selectChainedDocumentOption(null);
      expect(notified, true);
    });
  });

  group('isChainedCustomDocument', () {
    test('returns false for null document', () {
      createController();
      expect(controller.isChainedCustomDocument(null), false);
    });

    test('returns false when enableDocumentChain is missing', () {
      createController();
      expect(
        controller.isChainedCustomDocument({'key': 'invoice'}),
        false,
      );
    });

    test('returns false when previousDocumentKey is missing', () {
      createController();
      expect(
        controller.isChainedCustomDocument({'enableDocumentChain': true}),
        false,
      );
    });

    test('returns true when enableDocumentChain and previousDocumentKey set', () {
      createController();
      expect(
        controller.isChainedCustomDocument({
          'enableDocumentChain': true,
          'previousDocumentKey': 'id_card',
        }),
        true,
      );
    });

    test('returns false when previousDocumentKey is empty string', () {
      createController();
      expect(
        controller.isChainedCustomDocument({
          'enableDocumentChain': true,
          'previousDocumentKey': '',
        }),
        false,
      );
    });
  });

  group('getFlowStepTrigger', () {
    test('returns null for null input', () {
      createController();
      expect(controller.getFlowStepTrigger(null), isNull);
    });

    test('returns null for plain key without prefix', () {
      createController();
      expect(controller.getFlowStepTrigger('id_card'), isNull);
    });

    test('returns integer for __step__:N format', () {
      createController();
      expect(controller.getFlowStepTrigger('__step__:2'), 2);
    });

    test('returns null for __step__: with non-integer', () {
      createController();
      expect(controller.getFlowStepTrigger('__step__:abc'), isNull);
    });
  });

  group('matchesPreviousDocumentKey', () {
    test('returns false for null previousDocumentKey', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey(null, 'passport', null),
        false,
      );
    });

    test('returns true when keys match exactly', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('passport', 'passport', null),
        true,
      );
    });

    test('returns false when keys differ', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('id_card', 'passport', null),
        false,
      );
    });

    test('returns true when step trigger matches', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('__step__:1', 'id_card', 1),
        true,
      );
    });

    test('returns false when step trigger does not match', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('__step__:2', 'id_card', 1),
        false,
      );
    });

    test('returns true for id shorthand with passport', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('id', 'passport', null),
        true,
      );
    });

    test('returns false for id shorthand with unknown doc', () {
      createController();
      expect(
        controller.matchesPreviousDocumentKey('id', 'invoice', null),
        false,
      );
    });
  });

  group('matchesPreviousStepTriggerOptionValues', () {
    test('returns true when list is null', () {
      createController();
      expect(
        controller.matchesPreviousStepTriggerOptionValues(null, 'doc', null),
        true,
      );
    });

    test('returns true when list is empty', () {
      createController();
      expect(
        controller.matchesPreviousStepTriggerOptionValues([], 'doc', null),
        true,
      );
    });

    test('returns true when trigger matches', () {
      createController();
      expect(
        controller.matchesPreviousStepTriggerOptionValues(
          ['invoice::option_a'],
          'invoice',
          'option_a',
        ),
        true,
      );
    });

    test('returns false when trigger does not match', () {
      createController();
      expect(
        controller.matchesPreviousStepTriggerOptionValues(
          ['invoice::option_b'],
          'invoice',
          'option_a',
        ),
        false,
      );
    });
  });

  group('hasWorldCountryForCustomDocument', () {
    test('returns false for null document', () {
      createController();
      expect(controller.hasWorldCountryForCustomDocument(null), false);
    });

    test('returns false when countries not a list', () {
      createController();
      expect(
        controller.hasWorldCountryForCustomDocument({'countries': 'FR'}),
        false,
      );
    });

    test('returns true when countries contains world', () {
      createController();
      expect(
        controller.hasWorldCountryForCustomDocument({
          'countries': [
            {'key': 'FR'},
            {'key': 'world'},
          ],
        }),
        true,
      );
    });

    test('returns false when countries has no world', () {
      createController();
      expect(
        controller.hasWorldCountryForCustomDocument({
          'countries': [
            {'key': 'FR'},
            {'key': 'DE'},
          ],
        }),
        false,
      );
    });
  });

  group('shouldSkipCountryStepForCustomDocument', () {
    test('returns true when only world country', () {
      createController();
      expect(
        controller.shouldSkipCountryStepForCustomDocument({
          'countries': [
            {'key': 'world'},
          ],
        }),
        true,
      );
    });

    test('returns false when has selectable countries', () {
      createController();
      expect(
        controller.shouldSkipCountryStepForCustomDocument({
          'countries': [
            {'key': 'world'},
            {'value': 'fr'},
          ],
        }),
        false,
      );
    });
  });

  group('handleCaptureClose', () {
    test('goes to chainedCustomDocument when active chained doc set', () {
      createController();
      controller.beginChainedDocument({'key': 'kyb_doc'});
      controller.handleCaptureClose();
      expect(controller.currentStep, DataleonFlowStep.chainedCustomDocument);
    });

    test('calls previousStep when no active chained doc and no passport', () {
      createController();
      controller.selectDocumentType('id_card');
      controller.nextStep(); // go to index 1
      controller.handleCaptureClose();
      expect(controller.currentIndex, 0);
    });
  });

  group('exitChainedDocumentFlow', () {
    test('clears all chained state and goes to documentType', () {
      createController();
      controller.beginChainedDocument({'key': 'kyb_doc'});
      controller.exitChainedDocumentFlow();
      expect(controller.activeChainedDocument, isNull);
      expect(controller.pendingChainedDocuments, isEmpty);
      expect(controller.selectedChainedDocumentOption, isNull);
      expect(controller.selectedCustomDocument, isNull);
      expect(controller.documentType, isNull);
      expect(controller.documentCountry, isNull);
      expect(controller.currentStep, DataleonFlowStep.documentType);
    });
  });

  group('beginChainedDocument', () {
    test('sets active chained document and navigates', () {
      createController();
      controller.beginChainedDocument({
        'key': 'kyb_doc',
        'countries': [{'key': 'world'}],
      });
      expect(controller.activeChainedDocument, isNotNull);
      expect(controller.documentType, 'kyb_doc');
    });

    test('goes to chainedDocumentIntro when intro content exists', () async {
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'webviewConfig': 'intro_custom_document: "Please upload your KYB"',
        },
      });
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {'metadata': {'workspace': workspace}},
          }),
          200,
        );
      });
      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);
      await controller.fetchConfig();

      controller.beginChainedDocument({'key': 'kyb_doc'});
      expect(controller.currentStep, DataleonFlowStep.chainedDocumentIntro);
    });
  });

  group('chainedDocumentIntroComplete', () {
    test('marks intro shown and advances to chainedCustomDocument', () {
      createController();
      controller.chainedDocumentIntroComplete();
      expect(controller.currentStep, DataleonFlowStep.chainedCustomDocument);
    });
  });

  group('advancedDesignConfiguration', () {
    test('returns empty map when no workspace', () {
      createController();
      expect(controller.advancedDesignConfiguration, isEmpty);
    });

    test('parses JSON string from dashboardConfiguration', () async {
      final advConfig = jsonEncode({'customFontEnabled': true});
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'advancedDesignConfiguration': advConfig,
        },
      });
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {'metadata': {'workspace': workspace}},
          }),
          200,
        );
      });
      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);
      await controller.fetchConfig();

      expect(controller.advancedDesignConfiguration['customFontEnabled'], true);
    });
  });

  group('getNextChainedDocuments', () {
    test('returns empty list for null completedDocumentKey', () {
      createController();
      expect(controller.getNextChainedDocuments(null), isEmpty);
    });

    test('returns empty list for empty completedDocumentKey', () {
      createController();
      expect(controller.getNextChainedDocuments(''), isEmpty);
    });

    test('returns empty list when no customDocuments in workspace', () {
      createController();
      expect(controller.getNextChainedDocuments('passport'), isEmpty);
    });
  });

  group('conditionStatus', () {
    Future<void> loadCustomDocuments(List<Map<String, dynamic>> docs) async {
      final workspace = jsonEncode({
        'dashboardConfiguration': {'kycCustomDocuments': docs},
      });
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {'metadata': {'workspace': workspace}},
          }),
          200,
        );
      });
      createController(apiService: DataleonApiService(config: config, client: client));
      await controller.fetchConfig();
    }

    test('isCustomDocumentConditionMet only false when explicitly false', () {
      createController();
      expect(controller.isCustomDocumentConditionMet(null), isTrue);
      expect(controller.isCustomDocumentConditionMet({'key': 'a'}), isTrue);
      expect(
        controller.isCustomDocumentConditionMet({'conditionStatus': true}),
        isTrue,
      );
      expect(
        controller.isCustomDocumentConditionMet({'conditionStatus': false}),
        isFalse,
      );
    });

    test('visibleCustomDocuments hides deactivated documents', () async {
      await loadCustomDocuments([
        {'key': 'proof_address'},
        {'key': 'payslip', 'conditionStatus': false},
        {'key': 'tax_notice', 'conditionStatus': true},
      ]);

      expect(
        controller.visibleCustomDocuments.map((d) => d['key']),
        ['proof_address', 'tax_notice'],
      );
      // The raw list is untouched.
      expect(controller.customDocuments, hasLength(3));
    });

    test('skips a deactivated chained document and queues its children',
        () async {
      await loadCustomDocuments([
        {
          'key': 'payslip',
          'enableDocumentChain': true,
          'previousDocumentKey': 'passport',
          'conditionStatus': false,
        },
        {
          'key': 'tax_notice',
          'enableDocumentChain': true,
          'previousDocumentKey': 'payslip',
        },
      ]);

      controller.selectDocumentType('passport');
      final started = controller.completeCurrentDocumentAndContinue();

      expect(started, isTrue);
      expect(controller.activeChainedDocument?['key'], 'tax_notice');
      // The skipped document counts as completed so the chain keeps going.
      expect(controller.completedDocumentKeys, ['passport', 'payslip']);
    });

    test('skipped document still advances the __step__ counter', () async {
      await loadCustomDocuments([
        {
          'key': 'payslip',
          'enableDocumentChain': true,
          'previousDocumentKey': 'passport',
          'conditionStatus': false,
        },
        {
          'key': 'bank_details',
          'enableDocumentChain': true,
          'previousDocumentKey': '__step__:2',
        },
      ]);

      controller.selectDocumentType('passport');
      final started = controller.completeCurrentDocumentAndContinue();

      expect(started, isTrue);
      expect(controller.activeChainedDocument?['key'], 'bank_details');
    });

    test('ends the chain when every queued document is deactivated', () async {
      await loadCustomDocuments([
        {
          'key': 'payslip',
          'enableDocumentChain': true,
          'previousDocumentKey': 'passport',
          'conditionStatus': false,
        },
        {
          'key': 'tax_notice',
          'enableDocumentChain': true,
          'previousDocumentKey': 'payslip',
          'conditionStatus': false,
        },
      ]);

      controller.selectDocumentType('passport');
      final started = controller.completeCurrentDocumentAndContinue();

      expect(started, isFalse);
      expect(controller.activeChainedDocument, isNull);
      expect(controller.pendingChainedDocuments, isEmpty);
      expect(
        controller.completedDocumentKeys,
        ['passport', 'payslip', 'tax_notice'],
      );
    });
  });

  group('saveUploadedFile with documentKey', () {
    test('stores file by document key when documentType is set', () {
      createController();
      controller.selectDocumentType('passport');
      controller.saveUploadedFile(
        phase: 'front',
        url: 'https://s3/front.jpg',
        name: 'front.jpg',
        key: 'front-key',
      );
      expect(controller.uploadedFilesByDocument['passport'], isNotNull);
      expect(
        controller.uploadedFilesByDocument['passport']!['front']!['url'],
        'https://s3/front.jpg',
      );
    });
  });
}
