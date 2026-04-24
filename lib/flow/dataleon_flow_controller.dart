import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

import '../core/dataleon_config.dart';
import '../core/dataleon_result.dart';
import '../core/dataleon_status.dart';
import '../models/step_result.dart';
import '../services/dataleon_api_service.dart';
import 'dataleon_flow_step.dart';

class DataleonFlowController extends ChangeNotifier {
  DataleonFlowController({
    required DataleonConfig config,
    DataleonApiService? apiService,
    List<DataleonFlowStep>? steps,
  })  : _config = config,
        _apiService = apiService ?? DataleonApiService(config: config),
        _steps = steps ??
            const [
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
            ];

  final DataleonConfig _config;
  final DataleonApiService _apiService;
  final List<DataleonFlowStep> _steps;
  int _currentIndex = 0;
  DataleonResult _result = const DataleonResult(status: DataleonStatus.idle);
  final Map<DataleonFlowStep, DataleonStepResult> _stepResults = {};
  bool _loading = false;
  double _progress = 0;
  Map<String, dynamic>? _requestConfig;
  Map<String, dynamic>? _workspace;
  String _languageCode = 'fr';
  String? _documentType;
  String? _documentCountry;
  Map<String, dynamic>? _selectedCustomDocument;
  final Map<String, Map<String, String>> _uploadedFiles = {};
  String? _configErrorMessage;

  DataleonConfig get config => _config;
  String? get configErrorMessage => _configErrorMessage;
  DataleonApiService get apiService => _apiService;
  List<DataleonFlowStep> get steps => List.unmodifiable(_steps);
  int get currentIndex => _currentIndex;
  DataleonFlowStep get currentStep => _steps[_currentIndex];
  DataleonResult get result => _result;
  bool get isLastStep => _currentIndex >= _steps.length - 1;
  bool get isLoading => _loading;
  double get progress => _progress;
  Map<String, dynamic>? get requestConfig => _requestConfig;
  Map<String, dynamic> get requestResult =>
      (_requestConfig?['result'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  Map<String, dynamic>? get workspace => _workspace;
  String get languageCode => _languageCode;
  String? get documentType => _documentType;
  String? get documentCountry => _documentCountry;
  Map<String, dynamic>? get selectedCustomDocument => _selectedCustomDocument;
  Map<String, dynamic> get dashboardConfiguration =>
      (_workspace?['dashboardConfiguration'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  Map<String, dynamic> get webviewConfig {
    final preferredKey = _languageCode.toLowerCase().startsWith('en')
        ? 'webviewConfigEN'
        : 'webviewConfig';
    final raw = dashboardConfiguration[preferredKey] as String? ??
        dashboardConfiguration['webviewConfig'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final parsed = loadYaml(raw);
      return _normalizeYaml(parsed) as Map<String, dynamic>;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> get formSteps {
    final form = webviewConfig['form'];
    if (form is! List) {
      return const <Map<String, dynamic>>[];
    }
    return form.whereType<Map>().map((step) {
      return Map<String, dynamic>.from(step);
    }).toList(growable: false);
  }

  Map<String, Map<String, String>> get uploadedFiles =>
      Map.unmodifiable(_uploadedFiles);
  Map<DataleonFlowStep, DataleonStepResult> get stepResults =>
      Map.unmodifiable(_stepResults);

  static dynamic _normalizeYaml(dynamic value) {
    if (value is YamlMap) {
      return value.map(
        (key, dynamic child) => MapEntry(key.toString(), _normalizeYaml(child)),
      );
    }
    if (value is YamlList) {
      return value.map(_normalizeYaml).toList(growable: false);
    }
    return value;
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void updateProgress(double value) {
    _progress = value.clamp(0, 100);
    notifyListeners();
  }

  void setLanguage(String languageCode) {
    _languageCode = languageCode;
    notifyListeners();
  }

  void selectDocumentType(String documentType, {Map<String, dynamic>? customDocument}) {
    _documentType = documentType;
    _selectedCustomDocument = customDocument;
    notifyListeners();
  }

  void selectDocumentCountry(String? documentCountry) {
    _documentCountry = documentCountry;
    notifyListeners();
  }

  void saveUploadedFile({
    required String phase,
    required String url,
    required String name,
    required String key,
  }) {
    _uploadedFiles[phase] = {
      'url': url,
      'name': name,
      'key': key,
    };
    notifyListeners();
  }

  void clearUploadedFiles() {
    _uploadedFiles.clear();
    notifyListeners();
  }

  Map<String, dynamic>? formStepForAction(String action) {
    for (final step in formSteps) {
      if (step['page_action'] == action) {
        return step;
      }
    }
    return null;
  }

  bool hasWorldCountryForDocType(String? docType) {
    if (docType == null || docType.isEmpty) {
      return false;
    }

    final customCountries = _selectedCustomDocument?['countries'];
    final kycCountries = dashboardConfiguration['kycCountries'];
    final dynamic countriesByType = customCountries ??
        (kycCountries is Map<String, dynamic> ? kycCountries[docType] : null);

    if (countriesByType is! List) {
      return false;
    }

    return countriesByType.any(
      (country) => country is Map<String, dynamic> && country['key'] == 'world',
    );
  }

  /// Fetch the request configuration from the backend and
  /// advance to the welcome step once loaded.
  Future<void> fetchConfig() async {
    _loading = true;
    _progress = 0;
    notifyListeners();

    try {
      updateProgress(5);
      await _apiService.fetchToken();
      updateProgress(12);
      final config = await _apiService.fetchRequestConfig();
      updateProgress(72);
      _requestConfig = config;

      // Check if request returned an error (e.g. PROCESSED)
      if (config['error'] == true) {
        _configErrorMessage = config['message'] as String?;
        _loading = false;
        goToStep(DataleonFlowStep.alreadyProcessed);
        return;
      }

      final workspaceString =
          config['result']?['metadata']?['workspace'] as String?;
      if (workspaceString != null && workspaceString.isNotEmpty) {
        _workspace = jsonDecode(workspaceString) as Map<String, dynamic>;
      }
      final language =
          config['result']?['metadata']?['language'] as String? ??
          dashboardConfiguration['languageApp'] as String?;
      if (language != null && language.isNotEmpty) {
        _languageCode = language;
      }
      updateProgress(100);

      // Keep the loader visible after reaching 100%.
      await Future.delayed(const Duration(milliseconds: 2600));

      _loading = false;
      goToStep(DataleonFlowStep.welcome);
    } catch (e) {
      _configErrorMessage = e.toString();
      _loading = false;
      // 403 / PROCESSED → alreadyProcessed, other errors → error page
      if (e is DataleonApiException && e.statusCode == 403) {
        goToStep(DataleonFlowStep.alreadyProcessed);
      } else {
        goToStep(DataleonFlowStep.error);
      }
    }
  }

  void start() {
    _result = const DataleonResult(status: DataleonStatus.started);
    notifyListeners();
  }

  void nextStep() {
    if (_currentIndex >= _steps.length - 1) {
      finish();
      return;
    }

    _currentIndex += 1;
    notifyListeners();
  }

  void previousStep() {
    if (_currentIndex == 0) {
      return;
    }

    _currentIndex -= 1;
    notifyListeners();
  }

  void goToStep(DataleonFlowStep step) {
    final index = _steps.indexOf(step);
    if (index == -1) {
      return;
    }

    _currentIndex = index;
    notifyListeners();
  }

  void finish() {
    _result = const DataleonResult(status: DataleonStatus.finished);
    notifyListeners();
  }

  void cancel() {
    _result = const DataleonResult(status: DataleonStatus.canceled);
    notifyListeners();
  }

  void fail([String? error]) {
    _result = DataleonResult(status: DataleonStatus.failed, error: error);
    notifyListeners();
  }

  void setError(String error) {
    _result = DataleonResult(status: DataleonStatus.error, error: error);
    notifyListeners();
  }

  void abort() {
    _result = const DataleonResult(status: DataleonStatus.aborted);
    notifyListeners();
  }

  /// Save an intermediate step result locally.
  void saveStepResult(DataleonFlowStep step, DataleonStepResult result) {
    _stepResults[step] = result;
    notifyListeners();
  }

  /// Submit the current step data to the backend API.
  Future<Map<String, dynamic>> submitStepData({
    required String stepName,
    required Map<String, dynamic> data,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _apiService.submitStep(
        stepName: stepName,
        data: data,
      );
      _loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Upload a file to the backend for the given step.
  Future<Map<String, dynamic>> uploadFile({
    required String stepName,
    required String fieldName,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _apiService.uploadFile(
        stepName: stepName,
        fieldName: fieldName,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      _loading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Complete the session on the backend and mark the flow as finished.
  Future<void> completeSession() async {
    _loading = true;
    notifyListeners();
    try {
      await _apiService.completeSession();
      _loading = false;
      finish();
    } catch (e) {
      _loading = false;
      fail(e.toString());
    }
  }

  void reset() {
    _currentIndex = 0;
    _result = const DataleonResult(status: DataleonStatus.idle);
    _stepResults.clear();
    _loading = false;
    _documentType = null;
    _documentCountry = null;
    _selectedCustomDocument = null;
    _uploadedFiles.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
