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
    config = DataleonConfig(sessionId: 'sid', apiKey: 'key');
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
      expect(controller.steps.length, 12);
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
      controller.selectDocumentType('custom', customDocument: {'key': 'invoice'});
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
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
        if (request.url.path.contains('/token/')) {
          return http.Response('Forbidden', 403);
        }
        return http.Response('', 200);
      });

      final apiService = DataleonApiService(config: config, client: client);
      createController(apiService: apiService);

      await controller.fetchConfig();

      expect(controller.currentStep, DataleonFlowStep.alreadyProcessed);
    });

    test('navigates to error on non-403 API error', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/token/')) {
          return http.Response('Server Error', 500);
        }
        return http.Response('', 200);
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
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
      final yamlConfig = 'form:\n  - page_action: capture\n    title: Photo\n  - page_action: review\n    title: Review';
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'webviewConfig': yamlConfig,
        },
      });

      final client = MockClient((request) async {
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
      final yamlConfig = 'form:\n  - page_action: capture_en\n    title: Photo EN';
      final workspace = jsonEncode({
        'dashboardConfiguration': {
          'webviewConfigEN': yamlConfig,
          'webviewConfig': 'form:\n  - page_action: capture_fr',
        },
      });

      final client = MockClient((request) async {
        if (request.url.path.contains('/token/')) {
          return http.Response(jsonEncode({'token': 'jwt'}), 200);
        }
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
      final actions = controller.formSteps.map((s) => s['page_action']).toList();
      expect(actions, contains('capture_en'));
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
        return http.Response(jsonEncode({'fileUrl': 'https://s3/file.jpg'}), 200);
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
}
