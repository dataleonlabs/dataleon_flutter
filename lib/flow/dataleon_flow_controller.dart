import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../core/dataleon_config.dart';
import '../core/dataleon_result.dart';
import '../core/dataleon_status.dart';
import '../models/step_result.dart';
import '../services/dataleon_api_service.dart';
import '../utils/dataleon_font_cache.dart';
import '../utils/dataleon_web_font.dart';
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
              DataleonFlowStep.chainedDocumentIntro,
              DataleonFlowStep.chainedCustomDocument,
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
  Map<String, dynamic> _contentsConfig = const <String, dynamic>{};
  Map<String, dynamic> _contentsRaw = const <String, dynamic>{};
  late String _languageCode = _config.initialLanguage ?? 'fr';

  // Loading-screen branding (from the public /config/chart endpoint).
  bool _chartResolved = false;
  Timer? _messageChangeTimer;
  String? _brandingLogoUrl;
  String? _brandingAppName;
  String? _brandingPrincipalColor;
  bool? _brandingHideDataleon;
  String _loadingMessageKey = '';
  String? _documentType;
  String? _documentCountry;
  Map<String, dynamic>? _selectedCustomDocument;
  Map<String, dynamic>? _activeChainedDocument;
  Map<String, dynamic>? _selectedChainedDocumentOption;
  List<Map<String, dynamic>> _pendingChainedDocuments = const [];
  final List<String> _completedDocumentKeys = [];
  final Map<String, String?> _completedDocumentSelectedOptions = {};
  final Map<String, Map<String, String>> _uploadedFiles = {};
  final Map<String, Map<String, Map<String, String>>> _uploadedFilesByDocument =
      {};
  String? _configErrorMessage;
  bool _chainedDocIntroShown = false;
  bool _hasCompletedChainedCustomDocuments = false;
  String? _customFontFamily;

  // Session-level font bytes cache shared across all controller instances
  // (equivalent to React's module-level workspaceFontLoadCache).
  static final Map<String, Uint8List> _fontMemoryCache = {};

  static const String _customerAssetsBaseUrl =
      'https://customer-assets.eu-west-1.dataleon.ai';

  // ISO3 → ISO2 language mapping for backend language codes.
  static const Map<String, String> _iso3LangToIso2 = <String, String>{
    'fra': 'fr',
    'eng': 'en',
    'ara': 'ar',
    'deu': 'de',
    'ita': 'it',
    'por': 'pt',
    'spa': 'es',
    'nld': 'nl',
  };

  /// Normalize a backend language code to the ISO2 code used by the UI.
  static String normalizeLanguage(String language) {
    final normalized = language.toLowerCase();
    return _iso3LangToIso2[normalized] ?? normalized;
  }

  /// Sanitize a branding logo URL: only http/https is allowed. Relative paths
  /// are resolved against the customer-assets bucket (https). Any other scheme
  /// (javascript:, data:, file:, …) is rejected and returns null.
  static String? sanitizeLogoUrl(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    final uri = Uri.tryParse(clean);
    if (uri == null) return null;

    if (uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'https') return clean;
      if (scheme == 'http') {
        // Prefer HTTPS: convert http:// to https:// to increase chance of
        // successful loading on modern platforms (cleartext may be blocked).
        return clean.replaceFirst(RegExp(r'^http:', caseSensitive: false), 'https:');
      }
      return null;
    }

    final relative = clean.replaceFirst(RegExp(r'^/+'), '');
    return '$_customerAssetsBaseUrl/$relative';
  }

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
  Map<String, dynamic> get contentsConfig => _contentsConfig;
  String get languageCode => _languageCode;

  /// True once the public branding config (/config/chart) has resolved.
  /// While false the loading screen shows the indeterminate spinner; once
  /// true it shows the determinate progress bar.
  bool get isChartResolved => _chartResolved;

  /// Sanitized logo URL (http/https only) for the loading screen, or null.
  String? get brandingLogoUrl => _brandingLogoUrl;

  /// Application name from the branding config, used as a text fallback when
  /// no logo is available on the loading screen.
  String? get brandingAppName => _brandingAppName;

  /// Raw `principalColor` from the branding config used to fill the loading
  /// progress bar (null → caller falls back to a neutral grey).
  String? get brandingPrincipalColor => _brandingPrincipalColor;

  /// Current loading-screen message key (loadingScreen.<key>), or '' when none.
  String get loadingMessageKey => _loadingMessageKey;
  String? get documentType => _documentType;
  String? get documentCountry => _documentCountry;
  Map<String, dynamic>? get selectedCustomDocument => _selectedCustomDocument;
  Map<String, dynamic>? get activeChainedDocument => _activeChainedDocument;
  Map<String, dynamic>? get selectedChainedDocumentOption =>
      _selectedChainedDocumentOption;
  List<Map<String, dynamic>> get pendingChainedDocuments =>
      List.unmodifiable(_pendingChainedDocuments);
  List<String> get completedDocumentKeys =>
      List.unmodifiable(_completedDocumentKeys);
  bool get hasCompletedChainedCustomDocuments =>
      _hasCompletedChainedCustomDocuments;
  String? get customFontFamily => _customFontFamily;

  Map<String, dynamic> get dashboardConfiguration =>
      (_workspace?['dashboardConfiguration'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
  Map<String, dynamic> get webviewConfig {
    final preferredKey = _languageCode.toLowerCase().startsWith('en')
        ? 'webviewConfigEN'
        : 'webviewConfig';
    final raw = dashboardConfiguration[preferredKey] as String? ??
        dashboardConfiguration['webviewConfig'] as String?;

    Map<String, dynamic> base = const <String, dynamic>{};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final parsed = loadYaml(raw);
        base = _normalizeYaml(parsed) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (_contentsConfig.isEmpty) return base;
    return {...base, ..._contentsConfig};
  }

  /// True once the request config has resolved and the workspace is available.
  ///
  /// [hideDataleonBranding] is only meaningful from that point on: before it,
  /// the flag is simply unknown.
  bool get isWorkspaceResolved => _workspace != null;

  /// White-label: hide every mention of Dataleon in the flow (the intro
  /// sentence and the loading-screen disclaimer).
  ///
  /// The workspace configuration is the source of truth. The flag is expected
  /// under `advancedDesignConfiguration` but we also accept it at the root of
  /// `dashboardConfiguration`, and fall back to the public chart config, which
  /// resolves earlier. Booleans are sometimes serialized as strings by the
  /// backend, so `'true'` counts as true.
  bool get hideDataleonBranding {
    final candidates = <dynamic>[
      advancedDesignConfiguration['hideDataleonBranding'],
      dashboardConfiguration['hideDataleonBranding'],
      _brandingHideDataleon,
    ];

    for (final candidate in candidates) {
      final parsed = _parseBoolFlag(candidate);
      if (parsed != null) return parsed;
    }

    return false;
  }

  static bool? _parseBoolFlag(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  Map<String, dynamic> get advancedDesignConfiguration {
    final raw = dashboardConfiguration['advancedDesignConfiguration'];
    if (raw is Map<String, dynamic>) return raw;
    // Backend may send this as a JSON-encoded string (like webviewConfig).
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const <String, dynamic>{};
  }

  /// Identity fields appended to every capture (POST .../capture) body.
  ///
  /// `request_id`, `account_id` and `workspace_id` come straight from the
  /// request config response ([requestResult]); `mode` is derived from the
  /// workspace `kycIndividualFormType`. Only keys that resolve to a value are
  /// included, so absent fields are simply not sent.
  Map<String, dynamic> get captureRequestFields {
    final result = requestResult;
    final requestId = result['id'] as String?;
    final accountId = result['accountId'] as String?;
    final workspaceId = result['workspaceId'] as String?;
    final mode = _kycModeFromFormType(
      dashboardConfiguration['kycIndividualFormType'] as String?,
    );
    return <String, dynamic>{
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
      if (accountId != null && accountId.isNotEmpty) 'account_id': accountId,
      if (workspaceId != null && workspaceId.isNotEmpty)
        'workspace_id': workspaceId,
      if (mode.isNotEmpty) 'mode': mode,
    };
  }

  /// Map the workspace `kycIndividualFormType` to the capture `mode`:
  /// upload → simple, image → advanced, video → full (default advanced).
  String _kycModeFromFormType(String? formType) {
    switch (formType) {
      case 'upload':
        return 'simple';
      case 'image':
        return 'advanced';
      case 'video':
        return 'full';
      default:
        return 'advanced';
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
  Map<String, Map<String, Map<String, String>>> get uploadedFilesByDocument =>
      Map.unmodifiable(_uploadedFilesByDocument);
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

    // If the public chart hasn't resolved yet we keep spinner state (no message).
    if (!_chartResolved) {
      notifyListeners();
      return;
    }

    // Map numeric progress to the loadingScreen message keys so the UI can
    // display a localized message according to the current phase.
    final pct = _progress;
    String newKey;
    if (pct < 60) {
      newKey = 'content';
    } else if (pct < 88) {
      newKey = 'request';
    } else if (pct < 100) {
      newKey = 'theme';
    } else {
      newKey = 'ready';
    }

    if (newKey != _loadingMessageKey) {
      // Switch the message immediately as progress crosses each band.
      _messageChangeTimer?.cancel();
      _loadingMessageKey = newKey;
    }

    // Always notify for progress changes immediately so the bar updates.
    notifyListeners();
  }

  void setLanguage(String languageCode) {
    _languageCode = languageCode;
    notifyListeners();
  }

  void selectDocumentType(String documentType,
      {Map<String, dynamic>? customDocument}) {
    _documentType = documentType;
    _selectedCustomDocument = customDocument;
    notifyListeners();
  }

  void selectChainedDocumentOption(Map<String, dynamic>? option) {
    _selectedChainedDocumentOption =
        option == null ? null : Map<String, dynamic>.from(option);

    final internalName = _selectedChainedDocumentOption?['internalName'];
    if (internalName is String && internalName.isNotEmpty) {
      _documentType = internalName;
    } else {
      final activeKey = _activeChainedDocument?['key'];
      if (activeKey is String && activeKey.isNotEmpty) {
        _documentType = activeKey;
      }
    }

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

    final documentKey = currentDocumentKey;
    if (documentKey != null && documentKey.isNotEmpty) {
      final files = _uploadedFilesByDocument.putIfAbsent(
        documentKey,
        () => <String, Map<String, String>>{},
      );
      files[phase] = {
        'url': url,
        'name': name,
        'key': key,
      };
    }
    notifyListeners();
  }

  void clearUploadedFiles() {
    _uploadedFiles.clear();
    _uploadedFilesByDocument.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> get customDocuments =>
      (dashboardConfiguration['kycCustomDocuments'] as List?)
          ?.whereType<Map>()
          .map((document) => Map<String, dynamic>.from(document))
          .toList(growable: false) ??
      const <Map<String, dynamic>>[];

  List<Map<String, dynamic>> get visibleCustomDocuments => customDocuments
      .where((document) =>
          !isChainedCustomDocument(document) &&
          isCustomDocumentConditionMet(document))
      .toList(
        growable: false,
      );

  /// A custom document is active unless `conditionStatus` is explicitly false.
  /// Absent or true → the document behaves as before.
  bool isCustomDocumentConditionMet(Map<String, dynamic>? document) {
    return document?['conditionStatus'] != false;
  }

  String? get currentDocumentKey {
    final customKey = _selectedCustomDocument?['key'];
    if (customKey is String && customKey.isNotEmpty) {
      return customKey;
    }

    if (_documentType != null && _documentType!.isNotEmpty) {
      return _documentType;
    }

    return null;
  }

  bool isChainedCustomDocument(Map<String, dynamic>? document) {
    if (document == null) {
      return false;
    }

    final previousDocumentKey = document['previousDocumentKey'];
    return document['enableDocumentChain'] == true &&
        previousDocumentKey is String &&
        previousDocumentKey.isNotEmpty;
  }

  /// Parse a previousDocumentKey of the form "__step__:N" and return N or null.
  int? getFlowStepTrigger(String? previousDocumentKey) {
    if (previousDocumentKey == null) {
      return null;
    }
    final prefix = '__step__:';
    if (previousDocumentKey.startsWith(prefix)) {
      final rest = previousDocumentKey.substring(prefix.length);
      final n = int.tryParse(rest);
      return n;
    }
    return null;
  }

  bool matchesPreviousDocumentKey(
    String? previousDocumentKey,
    String completedDocKey,
    int? completedFlowStep,
  ) {
    if (previousDocumentKey == null) return false;

    final stepTrigger = getFlowStepTrigger(previousDocumentKey);
    if (stepTrigger != null) {
      return completedFlowStep != null && completedFlowStep == stepTrigger;
    }

    if (previousDocumentKey == completedDocKey) {
      return true;
    }

    // Allow shorthand 'id' matching for identity-like sets if needed.
    if (previousDocumentKey == 'id') {
      // Example identity set matching: treat some keys as identity docs.
      const identitySet = {'id_card', 'passport', 'identity'};
      return identitySet.contains(completedDocKey);
    }

    return false;
  }

  bool matchesPreviousStepTriggerOptionValues(
    List<dynamic>? previousStepTriggerOptionValues,
    String completedDocKey,
    String? completedSelectedOptionId,
  ) {
    if (previousStepTriggerOptionValues == null ||
        previousStepTriggerOptionValues.isEmpty) {
      return true;
    }

    final selectedId = completedSelectedOptionId ?? '';
    final trigger = '$completedDocKey::$selectedId';
    for (final item in previousStepTriggerOptionValues) {
      if (item is String && item == trigger) {
        return true;
      }
    }
    return false;
  }

  bool hasWorldCountryForCustomDocument(Map<String, dynamic>? document) {
    final countries = document?['countries'];
    if (countries is! List) {
      return false;
    }

    return countries.any(
      (country) => country is Map<String, dynamic> && country['key'] == 'world',
    );
  }

  bool hasSelectableCountryForCustomDocument(Map<String, dynamic>? document) {
    final countries = document?['countries'];
    if (countries is! List) {
      return false;
    }

    for (final group in countries) {
      if (group is! Map<String, dynamic>) {
        continue;
      }

      final groupValue =
          (group['value'] as String?)?.trim().toLowerCase() ?? '';
      if (groupValue.isNotEmpty && groupValue != 'world') {
        return true;
      }

      final nestedCountries = group['countries'];
      if (nestedCountries is! List) {
        continue;
      }

      for (final country in nestedCountries) {
        if (country is! Map<String, dynamic>) {
          continue;
        }
        final countryValue =
            (country['value'] as String?)?.trim().toLowerCase() ?? '';
        if (countryValue.isNotEmpty && countryValue != 'world') {
          return true;
        }
      }
    }

    return false;
  }

  bool shouldSkipCountryStepForCustomDocument(Map<String, dynamic>? document) {
    return hasWorldCountryForCustomDocument(document) &&
        !hasSelectableCountryForCustomDocument(document);
  }

  List<Map<String, dynamic>> getNextChainedDocuments(
    String? completedDocumentKey, {
    List<String> excludedKeys = const [],
    int? completedFlowStep,
    String? completedSelectedOptionId,
  }) {
    if (completedDocumentKey == null || completedDocumentKey.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    return customDocuments.where((document) {
      if (!isChainedCustomDocument(document)) {
        return false;
      }

      final prevKey = document['previousDocumentKey'];
      if (prevKey is! String || prevKey.isEmpty) {
        return false;
      }

      if (!matchesPreviousDocumentKey(prevKey, completedDocumentKey, completedFlowStep)) {
        // allow trigger by previousStepTriggerOptionValues as alternative
        final prevOptions = document['previousStepTriggerOptionValues'] as List?;
        if (!matchesPreviousStepTriggerOptionValues(
            prevOptions, completedDocumentKey, completedSelectedOptionId)) {
          return false;
        }
      }

      final key = document['key'] as String?;
      if (key == null || key.isEmpty) {
        return false;
      }

      return !_completedDocumentKeys.contains(key) && !excludedKeys.contains(key);
    }).toList(growable: false);
  }

  /// Drop from the head of [queue] every document deactivated by
  /// `conditionStatus: false`. A skipped document is still counted as done:
  /// its key is pushed into [_completedDocumentKeys] (which also advances the
  /// `__step__:N` counter) and its own children are queued in its place, so
  /// the chain keeps going instead of falling through to the outro.
  List<Map<String, dynamic>> resolveChainedQueue(
    List<Map<String, dynamic>> queue,
  ) {
    final resolved = List<Map<String, dynamic>>.from(queue);

    while (resolved.isNotEmpty &&
        !isCustomDocumentConditionMet(resolved.first)) {
      final skipped = resolved.removeAt(0);
      final skippedKey = skipped['key'];
      if (skippedKey is! String || skippedKey.isEmpty) {
        continue;
      }

      if (!_completedDocumentKeys.contains(skippedKey)) {
        _completedDocumentKeys.add(skippedKey);
      }

      final excludedKeys = <String>{
        ..._completedDocumentKeys,
        ...resolved.map((document) => document['key']).whereType<String>(),
      };

      final discovered = getNextChainedDocuments(
        skippedKey,
        excludedKeys: excludedKeys.toList(growable: false),
        completedFlowStep: _completedDocumentKeys.length,
        completedSelectedOptionId:
            _completedDocumentSelectedOptions[skippedKey],
      );

      for (final document in discovered) {
        final key = document['key'];
        if (key is! String) {
          continue;
        }
        if (resolved.any((item) => item['key'] == key)) {
          continue;
        }
        resolved.add(document);
      }
    }

    return resolved;
  }

  /// Returns true if the webviewConfig contains a non-empty
  /// `intro_custom_document` content block.
  bool hasChainedDocIntroContent() {
    final content = webviewConfig['intro_custom_document'];
    return content is String && content.trim().isNotEmpty;
  }

  /// Called when the user taps the CTA on the chained document intro page.
  /// Marks the intro as shown and advances to the actual document step.
  void chainedDocumentIntroComplete() {
    _chainedDocIntroShown = true;
    goToStep(DataleonFlowStep.chainedCustomDocument);
    notifyListeners();
  }

  void beginChainedDocument(Map<String, dynamic> document) {
    final normalizedDocument = Map<String, dynamic>.from(document);
    _activeChainedDocument = normalizedDocument;
    _selectedCustomDocument = normalizedDocument;
    _selectedChainedDocumentOption = null;
    _documentType = normalizedDocument['key'] as String?;

    if (_documentCountry == null &&
        shouldSkipCountryStepForCustomDocument(normalizedDocument)) {
      _documentCountry = '';
    }

    if (!_chainedDocIntroShown && hasChainedDocIntroContent()) {
      goToStep(DataleonFlowStep.chainedDocumentIntro);
    } else {
      goToStep(DataleonFlowStep.chainedCustomDocument);
    }
    notifyListeners();
  }

  void startActiveChainedDocumentCapture() {
    final activeDocument = _activeChainedDocument;
    if (activeDocument == null) {
      goToStep(DataleonFlowStep.success);
      notifyListeners();
      return;
    }

    if (_documentCountry != null && _documentCountry!.isNotEmpty) {
      goToStep(DataleonFlowStep.document);
      notifyListeners();
      return;
    }

    if (shouldSkipCountryStepForCustomDocument(activeDocument)) {
      _documentCountry = '';
      goToStep(DataleonFlowStep.document);
      notifyListeners();
      return;
    }

    _documentCountry = null;
    goToStep(DataleonFlowStep.documentCountry);
    notifyListeners();
  }

  bool completeCurrentDocumentAndContinue({String? completedSelectedOptionId, int? completedFlowStep}) {
    if (_activeChainedDocument != null) {
      _hasCompletedChainedCustomDocuments = true;
    }

    final completedKey = currentDocumentKey;
    if (completedKey == null || completedKey.isEmpty) {
      return false;
    }

    if (completedSelectedOptionId != null) {
      _completedDocumentSelectedOptions[completedKey] = completedSelectedOptionId;
    }

    if (!_completedDocumentKeys.contains(completedKey)) {
      _completedDocumentKeys.add(completedKey);
    }

    final remainingQueue =
        _activeChainedDocument != null && _pendingChainedDocuments.isNotEmpty
            ? _pendingChainedDocuments.skip(1).toList(growable: true)
            : <Map<String, dynamic>>[];

    final excludedKeys = <String>{
      ..._completedDocumentKeys,
      ...remainingQueue.map((document) => document['key']).whereType<String>(),
    };

    // completedFlowStep counts how many unique documents have been completed.
    // If not supplied by the caller, derive it from _completedDocumentKeys
    // (already updated above) so __step__:N triggers work correctly.
    final effectiveFlowStep =
        completedFlowStep ?? _completedDocumentKeys.length;

    final discoveredQueue = getNextChainedDocuments(
      completedKey,
      excludedKeys: excludedKeys.toList(growable: false),
      completedFlowStep: effectiveFlowStep,
      completedSelectedOptionId: completedSelectedOptionId ?? _completedDocumentSelectedOptions[completedKey],
    );

    for (final document in discoveredQueue) {
      final key = document['key'];
      if (key is! String) {
        continue;
      }
      final alreadyQueued = remainingQueue.any((item) => item['key'] == key);
      if (!alreadyQueued) {
        remainingQueue.add(document);
      }
    }

    final resolvedQueue = resolveChainedQueue(remainingQueue);

    if (resolvedQueue.isNotEmpty) {
      _pendingChainedDocuments =
          List<Map<String, dynamic>>.from(resolvedQueue);
      beginChainedDocument(_pendingChainedDocuments.first);
      return true;
    }

    _pendingChainedDocuments = const [];
    _activeChainedDocument = null;
    _selectedChainedDocumentOption = null;
    return false;
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

  /// Patches two fields in the OS/2 table of a TTF/OTF font so that
  /// Skia/CanvasKit (Flutter web) correctly maps bytes to the right FontWeight:
  ///   - usWeightClass (offset +4): the numeric weight (300 / 400 / 700 …)
  ///   - fsSelection  (offset +62): bit 5 = BOLD flag
  Uint8List _patchFontWeight(Uint8List bytes, int weight) {
    try {
      final data = ByteData.sublistView(bytes);
      final sfVersion = data.getUint32(0, Endian.big);
      if (sfVersion != 0x00010000 && // TrueType
          sfVersion != 0x4F54544F && // CFF/OTF (OTTO)
          sfVersion != 0x74727565) { // Mac TrueType (true)
        return bytes;
      }
      final numTables = data.getUint16(4, Endian.big);
      for (var i = 0; i < numTables; i++) {
        final rec = 12 + i * 16;
        if (rec + 16 > bytes.length) break;
        final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
        if (tag == 'OS/2') {
          final tableOffset = data.getUint32(rec + 8, Endian.big);
          final patched = Uint8List.fromList(bytes);
          final pd = ByteData.sublistView(patched);

          // usWeightClass at OS/2 +4
          final weightOffset = tableOffset + 4;
          if (weightOffset + 2 <= bytes.length) {
            pd.setUint16(weightOffset, weight, Endian.big);
          }

          // fsSelection at OS/2 +62: bit 5 (0x0020) = BOLD
          final fsOffset = tableOffset + 62;
          if (fsOffset + 2 <= bytes.length) {
            var fs = pd.getUint16(fsOffset, Endian.big);
            if (weight >= 600) {
              fs |= 0x0020; // set BOLD bit
            } else {
              fs &= ~0x0020; // clear BOLD bit
            }
            pd.setUint16(fsOffset, fs, Endian.big);
          }

          return patched;
        }
      }
    } catch (_) {}
    return bytes;
  }

  Future<Uint8List?> _downloadFontBytes(String objectKey) async {
    try {
      String? url;
      try {
        final signed = await _apiService.generateSignedGetUrl(
          objectName: objectKey,
          bucket: _config.customerAssetsBucket,
        );
        url = signed['signed_url'] as String? ??
            signed['signedUrl'] as String? ??
            signed['url'] as String?;
      } catch (_) {}
      url ??= 'https://customer-assets.eu-west-1.dataleon.ai/$objectKey';
      return Uint8List.fromList(await _apiService.downloadBytes(url));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCustomFonts() async {
    final adConfig = advancedDesignConfiguration;
    final enabled = adConfig['customFontEnabled'];
    if (enabled != true && enabled != 'true' && enabled != 1) return;

    // Each font file covers a weight range.
    // All patched copies are batched into ONE FontLoader so that a single
    // load() call registers them all — multiple load() calls for the same
    // family on Flutter Web overwrite the previous registration.
    final variantGroups = <Map<String, Object?>>[
      {
        'key': adConfig['fontTinyKey'] as String?,
        'weights': <int>[100, 200, 300],
        'cssWeight': 300,
      },
      {
        'key': adConfig['fontNormalKey'] as String?,
        'weights': <int>[400, 500],
        'cssWeight': 400,
      },
      {
        'key': adConfig['fontBoldKey'] as String?,
        'weights': <int>[600, 700, 800, 900],
        'cssWeight': 700,
      },
    ];

    const family = 'DataleonCustom';
    final loader = FontLoader(family);
    var loaded = false;

    for (final group in variantGroups) {
      final rawKey = group['key'] as String?;
      final weights = group['weights'] as List<int>;
      final cssWeight = group['cssWeight'] as int;
      if (rawKey == null || rawKey.isEmpty) continue;

      // Prefer TTF; fall back to original format (.woff2 etc.) when absent.
      final ttfKey = rawKey.replaceAll(
        RegExp(r'\.(woff2|woff|eot)$', caseSensitive: false),
        '.ttf',
      );
      try {
        final cacheKey =
            ttfKey.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        Uint8List? bytes = _fontMemoryCache[cacheKey];
        bytes ??= await readCachedFont(cacheKey);

        if (bytes == null) {
          bytes = await _downloadFontBytes(ttfKey);
          if (bytes == null && ttfKey != rawKey) {
            bytes = await _downloadFontBytes(rawKey);
          }
          if (bytes == null) continue;
          await writeCachedFont(cacheKey, bytes);
        }

        _fontMemoryCache[cacheKey] = bytes;

        // Add one patched copy per weight into the same FontLoader so
        // CanvasKit (which reads OS/2 usWeightClass) finds an exact match
        // for every FontWeight value: w100-300 → thin, w400-500 → normal,
        // w600-900 → bold.
        for (final w in weights) {
          loader.addFont(
            Future.value(ByteData.sublistView(_patchFontWeight(bytes, w))),
          );
        }

        // CSS @font-face for the HTML renderer: one rule per file with the
        // canonical weight. The browser's CSS3 algorithm maps nearby weights.
        await registerWebFont(family, _patchFontWeight(bytes, cssWeight), cssWeight);
        loaded = true;
      } catch (_) {}
    }

    if (loaded) {
      await loader.load();
      _customFontFamily = family;
    }
  }

  /// Select the localized slice of the contents config for the current
  /// language. Safe to call repeatedly as the language is refined.
  void _resolveContentsForCurrentLanguage() {
    final data = _contentsRaw;
    if (data.isEmpty) return;
    final langContent = data[_languageCode] ??
        data[_languageCode.split('-').first] ??
        data['fr'];
    if (langContent is Map<String, dynamic>) {
      _contentsConfig = langContent;
    }
  }

  /// Fetch the public branding config (/config/chart) and store the logo,
  /// principal color, app name and an early language. Best-effort: on failure
  /// the loading screen still leaves the spinner (with a default bar color).
  Future<void> _fetchChartConfig() async {
    try {
      final chart = await _apiService.fetchChartConfig();

      // Switch language immediately so loading messages are localized.
      final language = chart['languageApp'];
      if (language is String && language.isNotEmpty) {
        _languageCode = normalizeLanguage(language);
      }

      _brandingLogoUrl = sanitizeLogoUrl(chart['logoURLApp'] as String?);
      final color = chart['principalColor'];
      _brandingPrincipalColor =
          color is String && color.trim().isNotEmpty ? color.trim() : null;
      final name = chart['applicationName'];
      _brandingAppName =
          name is String && name.trim().isNotEmpty ? name.trim() : null;
      _brandingHideDataleon = _parseBoolFlag(chart['hideDataleonBranding']);
      // Debug: surface branding values to console so QA can verify what the
      // SDK received from the public chart endpoint when testing.
      try {
        debugPrint('Dataleon: chart language=${_languageCode}');
        debugPrint('Dataleon: brandingLogoUrl=${_brandingLogoUrl}');
        debugPrint('Dataleon: brandingPrincipalColor=${_brandingPrincipalColor}');
        debugPrint('Dataleon: brandingAppName=${_brandingAppName}');
      } catch (_) {}
    } catch (_) {
      // Best-effort: continue without branding.
    } finally {
      // Always leave the spinner: the determinate bar appears now. Reset
      // numeric progress so the determinate bar appears from 0.
      _chartResolved = true;
      _progress = 0;
      _messageChangeTimer?.cancel();
      _loadingMessageKey = '';
      notifyListeners();
    }
  }

  /// Orchestrate the branded loading sequence and advance to the welcome step.
  ///
  /// Phase 1 (spinner) runs until [_fetchChartConfig] resolves; phase 2 (the
  /// determinate bar) covers the heavier config calls.
  Future<void> fetchConfig() async {
    _loading = true;
    _progress = 0;
    _chartResolved = false;
    _loadingMessageKey = '';
    notifyListeners();

    // Phase 1 → Phase 2: public branding (logo + color + name + early language).
    await _fetchChartConfig();

    try {
        // Contents config. Show the first message immediately so the user
        // always sees a status from the start of the determinate bar.
        _messageChangeTimer?.cancel();
        _loadingMessageKey = 'content';
        notifyListeners();
        updateProgress(15);
      _contentsRaw = await _apiService.fetchContentsConfig();
      _resolveContentsForCurrentLanguage();
      updateProgress(35);

      // Request config (workspace + definitive language).
        _messageChangeTimer?.cancel();
        _loadingMessageKey = 'request';
        notifyListeners();
        updateProgress(60);
      final config = await _apiService.fetchRequestConfig();
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
      final language = config['result']?['metadata']?['language'] as String? ??
          dashboardConfiguration['languageApp'] as String?;
      if (language != null && language.isNotEmpty) {
        _languageCode = normalizeLanguage(language);
      }
      // Re-confirm the contents slice with the definitive language.
      _resolveContentsForCurrentLanguage();

      // Theme: preload fonts while the bar eases 60 → 88.
      _messageChangeTimer?.cancel();
      _loadingMessageKey = 'theme';
      notifyListeners();
      updateProgress(88);
      notifyListeners();
      try {
        await _loadCustomFonts();
      } catch (_) {}
      updateProgress(90);

      // Ready.
      _messageChangeTimer?.cancel();
      _loadingMessageKey = 'ready';
      notifyListeners();
      updateProgress(100);

      // Keep the loader visible briefly after reaching 100%.
      await Future.delayed(const Duration(milliseconds: 900));

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

  void handleCaptureClose() {
    if (_activeChainedDocument != null) {
      goToStep(DataleonFlowStep.chainedCustomDocument);
      return;
    }

    if (_documentType == 'passport' &&
        _documentCountry == '' &&
        hasWorldCountryForDocType(_documentType)) {
      goToStep(DataleonFlowStep.documentType);
      return;
    }

    previousStep();
  }

  void exitChainedDocumentFlow() {
    _activeChainedDocument = null;
    _pendingChainedDocuments = const [];
    _selectedChainedDocumentOption = null;
    _selectedCustomDocument = null;
    _documentType = null;
    _documentCountry = null;
    goToStep(DataleonFlowStep.documentType);
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
    _activeChainedDocument = null;
    _selectedChainedDocumentOption = null;
    _pendingChainedDocuments = const [];
    _completedDocumentKeys.clear();
    _uploadedFiles.clear();
    _uploadedFilesByDocument.clear();
    _chainedDocIntroShown = false;
    _hasCompletedChainedCustomDocuments = false;
    _chartResolved = false;
    _brandingLogoUrl = null;
    _brandingAppName = null;
    _brandingPrincipalColor = null;
    _brandingHideDataleon = null;
    _loadingMessageKey = '';
    _contentsRaw = const <String, dynamic>{};
    _contentsConfig = const <String, dynamic>{};
    _progress = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
