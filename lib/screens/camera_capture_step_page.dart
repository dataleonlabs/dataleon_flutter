import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../flow/dataleon_flow_step.dart';
import '../i18n/dataleon_localizations.dart';
import 'capture_frame_encoder.dart';
import 'capture_loop_policy.dart';
import 'capture_validations.dart';

// ---------------------------------------------------------------------------
//  CameraCaptureStepPage – fullscreen realtime capture like the React version
// ---------------------------------------------------------------------------

class CameraCaptureStepPage extends StatefulWidget {
  const CameraCaptureStepPage({
    super.key,
    required this.controller,
    @visibleForTesting this.clock,
  });
  final DataleonFlowController controller;

  /// Horloge de la boucle de capture (cadence, délai par étape). Tests
  /// uniquement : l'horloge système sinon.
  final DateTime Function()? clock;

  @override
  State<CameraCaptureStepPage> createState() => _CameraCaptureStepPageState();
}

class _CameraCaptureStepPageState extends State<CameraCaptureStepPage> {
  // Camera
  CameraController? _cam;
  bool _camReady = false;

  // Phase state
  int _phaseIndex = 0;
  bool _greenDelay = false;
  bool _pendingConfirm = false;
  Uint8List? _capturedBytes;

  // API loop. Les images viennent du flux vidéo (`startImageStream`, silencieux)
  // quand la plateforme le permet, sinon de `takePicture()` (web). Un seul envoi
  // à la fois (`_sending`), espacés d'au moins `captureFrameInterval`.
  bool _loopRunning = false;
  bool _sending = false;
  bool _streaming = false;
  // Incrémenté à chaque arrêt/relance : un envoi encore en vol au moment d'un
  // arrêt ne doit plus toucher à l'état.
  int _loopGeneration = 0;
  late CaptureLoopTracker _tracker;

  // Délai de l'étape caméra en cours : à échéance, la capture s'arrête même si
  // une requête est en vol (sa réponse est ignorée).
  Timer? _stepDeadline;
  // Message de l'échec qui a arrêté la capture (feuille d'erreur + Réessayer).
  String? _captureError;
  String? _apiStatus;
  String? _apiMessage;
  // Cached photo dimensions (same for all frames with same camera)
  double? _photoW;
  double? _photoH;

  // Confirmation flow
  bool _submitting = false;
  String? _confirmMessage;
  double? _confirmPercent;
  String? _confirmStatus;
  String? _confirmError;

  // Renouvelé quand l'utilisateur relance une capture arrêtée : le serveur
  // plafonne les images par session et par étape.
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _tracker = CaptureLoopTracker(_loopSettings, clock: widget.clock);
    _initCamera();
  }

  @override
  void dispose() {
    final cam = _cam;
    final wasStreaming = _streaming;
    _cam = null;
    _loopRunning = false;
    _streaming = false;
    _loopGeneration += 1;
    _stepDeadline?.cancel();
    Future<void>(() async {
      if (wasStreaming) {
        try {
          await cam?.stopImageStream();
        } catch (_) {}
      }
      await cam?.dispose();
    });
    super.dispose();
  }

  CaptureLoopSettings get _loopSettings => CaptureLoopSettings(
        minFrameInterval: _ctrl.config.captureFrameInterval,
        maxAttempts: _ctrl.config.captureMaxAttempts,
        timeout: _ctrl.config.captureTimeout,
      );

  DataleonFlowController get _ctrl => widget.controller;
  Map<String, dynamic> get _dash => _ctrl.dashboardConfiguration;

  String get _lang => _ctrl.languageCode;
  String _t(String key, {Map<String, String>? params, String? fallback}) =>
      DataleonLocalizations.t(_lang, key, params: params, fallback: fallback);

  List<String> get _phases {
    final docType = _ctrl.documentType;
    final custom = _ctrl.selectedCustomDocument;
    final activation =
        (_dash['kycDocumentTypeActivation'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final selfie = activation['selfie'] == true;
    if (docType == 'passport') {
      return selfie ? const ['front', 'face'] : const ['front'];
    }
    if (custom != null) {
      final hasVerso = custom['verso'] == true;
      if (hasVerso) {
        return selfie
            ? const ['front', 'back', 'face']
            : const ['front', 'back'];
      }
      return selfie ? const ['front', 'face'] : const ['front'];
    }
    return selfie ? const ['front', 'back', 'face'] : const ['front', 'back'];
  }

  String get _phase => _phases[_phaseIndex];
  bool get _isFace => _phase == 'face';
  bool get _isLastPhase => _phaseIndex >= _phases.length - 1;

  Color get _btnColor =>
      _parseColor(_dash['buttonColor'] as String?, const Color(0xFF111827));
  Color get _btnTextColor =>
      _parseColor(_dash['buttonTextColor'] as String?, Colors.white);
  String get _docName {
    final docType = _ctrl.documentType ?? 'id';
    final custom = _ctrl.selectedCustomDocument;
    final chainedOptionLabel = _ctrl.selectedChainedDocumentOption?['label'];
    final customDocKey = (custom?['key'] as String?) ?? docType;
    final customLabelKey = custom?['labelKey'] as String?;
    final customTranslationKey =
        'documentListType.${customLabelKey ?? customDocKey}';
    final validatorMeta =
        (_ctrl.requestConfig?['properties_validators'] as List?)
            ?.whereType<Map>()
            .cast<Map<dynamic, dynamic>>()
            .firstWhere(
              (item) => item['key'] == customDocKey,
              orElse: () => const <dynamic, dynamic>{},
            )
            .cast<String, dynamic>();

    if (chainedOptionLabel is String && chainedOptionLabel.trim().isNotEmpty) {
      return chainedOptionLabel.trim();
    }

    if (custom != null) {
      final translatedCustomLabel = _t(customTranslationKey);
      if (translatedCustomLabel != customTranslationKey) {
        return translatedCustomLabel;
      }

      final source = validatorMeta == null || validatorMeta.isEmpty
          ? custom
          : validatorMeta;

      if (_lang == 'fr') {
        final fr = source['displayNameFR'] as String?;
        if (fr != null && fr.trim().isNotEmpty) {
          return fr.trim();
        }
      }

      if (_lang == 'en') {
        final en = source['displayNameEN'] as String?;
        if (en != null && en.trim().isNotEmpty) {
          return en.trim();
        }
      }

      final name = source['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }

      final key = source['key'] as String?;
      if (key != null && key.isNotEmpty) {
        return key;
      }

      return customDocKey;
    }

    return _t('cameraCapture.docName_$docType',
        fallback: _t('documentTypeStep.documents.$docType', fallback: docType));
  }

  String get _phaseLabel {
    switch (_phase) {
      case 'front':
        return _ctrl.documentType == 'passport'
            ? _t('cameraCapture.passportLabel')
            : _t('cameraCapture.frontLabel', params: {'document': _docName});
      case 'back':
        return _t('cameraCapture.backLabel', params: {'document': _docName});
      case 'face':
        return _t('cameraCapture.selfieLabel');
      default:
        return 'Capture';
    }
  }

  /// Message « délai écoulé » propre à l'étape (recto, verso, passeport, selfie).
  String get _timeoutMessageKey {
    switch (_phase) {
      case 'back':
        return 'cameraCapture.captureTimeoutBack';
      case 'face':
        return 'cameraCapture.captureTimeoutFace';
      default:
        return _ctrl.documentType == 'passport'
            ? 'cameraCapture.captureTimeoutPassport'
            : 'cameraCapture.captureTimeoutFront';
    }
  }

  bool get _isCardDocument {
    final rawValue = _ctrl.selectedCustomDocument?['isCardDocument'];
    if (rawValue is bool) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue == 1;
    }
    if (rawValue is String) {
      final normalizedValue = rawValue.trim().toLowerCase();
      return const ['true', '1', 'yes', 'on'].contains(normalizedValue);
    }
    return false;
  }

  bool get _enabledDocumentCapture =>
      _ctrl.selectedCustomDocument != null && _isCardDocument;

  // ---- camera ----

  /// Flux vidéo disponible (iOS, Android) : pas de son d'obturateur.
  bool _canStream(CameraController cam) => !kIsWeb && cam.supportsImageStreaming();

  ImageFormatGroup get _streamFormatGroup =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420;

  Future<void> _initCamera() async {
    await _stopLoop();
    if (!mounted) return;
    setState(() {
      _camReady = false;
      _apiStatus = null;
      _apiMessage = null;
      _captureError = null;
    });

    try {
      final previous = _cam;
      _cam = null;
      await previous?.dispose();
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final lens =
          _isFace ? CameraLensDirection.front : CameraLensDirection.back;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => cameras.first,
      );

      // Flux (iOS/Android) : 1280x720 pour les documents comme pour le selfie.
      // Chaque image est convertie en JPEG sur l'appareil, et l'image acceptée
      // est celle qui part en vérification (OCR, MRZ) : 720p garde la lecture
      // fiable sans saturer les téléphones d'entrée de gamme. Photo (web) :
      // 1920x1080 pour les documents, 1280x720 pour le selfie, comme avant.
      final stream = !kIsWeb;
      final preset = stream || _isFace
          ? ResolutionPreset.high
          : ResolutionPreset.veryHigh;
      final ctrl = CameraController(
        cam,
        preset,
        enableAudio: false,
        imageFormatGroup: stream ? _streamFormatGroup : null,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }

      setState(() {
        _cam = ctrl;
        _camReady = true;
        _photoW = null;
        _photoH = null;
      });
      _startLoop();
    } catch (_) {
      if (mounted) setState(() => _camReady = false);
    }
  }

  // ---- realtime API loop ----

  void _startLoop() {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    _loopGeneration += 1;
    final generation = _loopGeneration;
    _loopRunning = true;
    _sending = false;
    // Nouvelle étape caméra (ou nouvel essai) : compteurs à zéro et 2 minutes
    // (captureTimeout) qui partent maintenant, caméra prête.
    _tracker = CaptureLoopTracker(_loopSettings, clock: widget.clock)..start();
    _stepDeadline?.cancel();
    _stepDeadline = Timer(_tracker.remaining, () {
      if (_isCurrent(generation)) _failCapture(CaptureErrorCode.timeout);
    });
    if (_canStream(cam)) {
      _startStream(cam, generation);
    } else {
      _runPhotoLoop(generation);
    }
  }

  Future<void> _stopLoop() async {
    _loopRunning = false;
    _loopGeneration += 1;
    _stepDeadline?.cancel();
    _stepDeadline = null;
    final cam = _cam;
    if (_streaming) {
      _streaming = false;
      try {
        await cam?.stopImageStream();
      } catch (_) {}
    }
  }

  bool _isCurrent(int generation) =>
      mounted && _loopRunning && generation == _loopGeneration;

  bool get _paused => _pendingConfirm || _greenDelay || _captureError != null;

  Future<void> _startStream(CameraController cam, int generation) async {
    _streaming = true;
    try {
      await cam.startImageStream(
          (image) => _onStreamFrame(cam, image, generation));
    } catch (_) {
      // Flux refusé par l'appareil : repli sur les photos.
      _streaming = false;
      if (_isCurrent(generation)) _runPhotoLoop(generation);
    }
  }

  void _onStreamFrame(CameraController cam, CameraImage image, int generation) {
    if (!_isCurrent(generation) || _sending || _paused) return;
    if (!_tracker.canSendNow) return;
    final limit = _tracker.limitReached();
    if (limit != null) {
      _failCapture(limit);
      return;
    }

    _sending = true;
    _tracker.recordSend();
    if (image.format.group == ImageFormatGroup.jpeg) {
      final bytes = Uint8List.fromList(image.planes.first.bytes);
      _sendFrame(generation, () async => bytes,
          width: image.width, height: image.height);
      return;
    }
    // Copie immédiate : le tampon natif est réutilisé après ce callback.
    final frame = _captureFrameFrom(cam, image);
    _sendFrame(generation, () => compute(encodeCaptureFrame, frame),
        width: frame.outputWidth, height: frame.outputHeight);
  }

  CaptureFrame _captureFrameFrom(CameraController cam, CameraImage image) {
    final CaptureFrameFormat format;
    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        format = CaptureFrameFormat.bgra8888;
        break;
      case ImageFormatGroup.nv21:
        format = CaptureFrameFormat.nv21;
        break;
      default:
        format = CaptureFrameFormat.yuv420;
    }
    return CaptureFrame(
      width: image.width,
      height: image.height,
      format: format,
      planes: [
        for (final p in image.planes)
          CaptureFramePlane(
            bytes: Uint8List.fromList(p.bytes),
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
          ),
      ],
      rotation: captureFrameRotation(
        isAndroid: defaultTargetPlatform == TargetPlatform.android,
        sensorOrientation: cam.description.sensorOrientation,
        width: image.width,
        height: image.height,
      ),
    );
  }

  /// Repli sans flux (web) : une photo par tour, à la même cadence.
  Future<void> _runPhotoLoop(int generation) async {
    while (_isCurrent(generation)) {
      if (_paused) return;
      final wait = _tracker.delayBeforeNextSend();
      if (wait > Duration.zero) {
        await Future.delayed(wait);
        continue;
      }
      final limit = _tracker.limitReached();
      if (limit != null) {
        _failCapture(limit);
        return;
      }
      final cam = _cam;
      if (cam == null || !cam.value.isInitialized) return;

      _sending = true;
      _tracker.recordSend();
      await _sendFrame(generation, () async {
        final file = await cam.takePicture();
        return file.readAsBytes();
      });
    }
  }

  /// Envoie une image à l'analyse temps réel et applique la réponse.
  Future<void> _sendFrame(
    int generation,
    Future<Uint8List> Function() produce, {
    int? width,
    int? height,
  }) async {
    try {
      final bytes = await produce();
      if (!_isCurrent(generation)) return;

      final double pw, ph;
      if (width != null && height != null) {
        pw = width.toDouble();
        ph = height.toDouble();
      } else {
        // Photo : dimensions décodées une fois, identiques pour toute l'étape.
        if (_photoW == null || _photoH == null) {
          final codec = await ui.instantiateImageCodec(bytes);
          final decoded = await codec.getNextFrame();
          _photoW = decoded.image.width.toDouble();
          _photoH = decoded.image.height.toDouble();
          decoded.image.dispose();
          codec.dispose();
        }
        pw = _photoW!;
        ph = _photoH!;
      }

      final data = await _ctrl.apiService
          .sendCaptureFrame(payload: _framePayload(bytes, pw, ph));
      if (!_isCurrent(generation)) return;
      _applyOutcome(classifyCaptureResponse(data), bytes);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      final stop = _tracker.recordNetworkError();
      if (stop != null) {
        _failCapture(stop);
      } else {
        setState(() {
          _apiStatus = 'ko';
          _apiMessage = _t('cameraCapture.networkError');
        });
      }
    } finally {
      if (generation == _loopGeneration) _sending = false;
    }
  }

  Map<String, dynamic> _framePayload(Uint8List bytes, double pw, double ph) {
    // Overlay as proportions — same ratios as the visual guide on screen.
    // Applied directly to the actual image dimensions so overlay matches image.
    final double owRatio, ohRatio;
    if (_isFace) {
      owRatio = 0.65;
      ohRatio = 0.45;
    } else {
      owRatio = 0.85;
      ohRatio = 0.28;
    }
    final overlayW = (pw * owRatio).round();
    final overlayH = (ph * ohRatio).round();
    final overlayX = ((pw - overlayW) / 2).round();
    final overlayY = ((ph - overlayH) / 2).round();

    return <String, dynamic>{
      'image': base64Encode(bytes),
      'step': _phase,
      'document_type': _ctrl.documentType ?? 'id',
      'document_country': (_ctrl.documentCountry ?? '').toUpperCase(),
      'enabled_document_capture': _enabledDocumentCapture,
      'language': _ctrl.languageCode,
      'session_id': _sessionId,
      'screen_w': pw.round(),
      'screen_h': ph.round(),
      'overlay_x': overlayX,
      'overlay_y': overlayY,
      'overlay_w': overlayW,
      'overlay_h': overlayH,
      // request_id / account_id / workspace_id / mode — centralized in the
      // controller and appended to every capture (recto, verso, face/selfie).
      ..._ctrl.captureRequestFields,
    };
  }

  void _applyOutcome(CaptureFrameOutcome outcome, Uint8List bytes) {
    final stop = _tracker.recordOutcome(outcome);
    if (outcome.action == CaptureFrameAction.accept) {
      _acceptFrame(bytes);
      return;
    }
    if (stop != null) {
      _failCapture(stop, apiMessage: outcome.message);
      return;
    }
    setState(() {
      // Statut vide ou inconnu : lu comme `pending`. Sans message, le conseil
      // déjà affiché reste.
      _apiStatus = outcome.status;
      if (outcome.message != null) _apiMessage = outcome.message;
    });
  }

  Future<void> _acceptFrame(Uint8List bytes) async {
    await _stopLoop();
    if (!mounted) return;
    setState(() {
      _apiStatus = 'ok';
      _greenDelay = true;
      _capturedBytes = bytes;
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _greenDelay = false;
      _pendingConfirm = true;
    });
  }

  /// Arrêt sans succès : feuille d'erreur avec « Réessayer », et `onResult`
  /// reçoit `DataleonStatus.error` avec [code].
  void _failCapture(String code, {String? apiMessage}) {
    _stopLoop();
    if (!mounted) return;
    final String message;
    if (code == CaptureErrorCode.tooManyAttempts && apiMessage != null) {
      message = apiMessage.replaceAll(RegExp(r'</?k>'), '');
    } else if (code == CaptureErrorCode.timeout) {
      message = _t(_timeoutMessageKey);
    } else {
      message = _t('cameraCapture.captureFailed');
    }
    setState(() {
      _captureError = message;
      _apiStatus = null;
    });
    _ctrl.reportCaptureError(code);
  }

  void _handleCaptureRetry() {
    if (!mounted) return;
    setState(() {
      _captureError = null;
      _apiStatus = null;
      _apiMessage = null;
    });
    // Nouvelle session : le serveur a pu fermer l'étape de l'ancienne.
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _ctrl.resumeAfterCaptureError();
    _startLoop();
  }

  // ---- confirmation flow ----

  Future<void> _handleConfirm() async {
    final bytes = _capturedBytes;
    if (bytes == null || _submitting) return;

    setState(() {
      _submitting = true;
      _confirmStatus = 'progress';
      _confirmMessage = _t('cameraCapture.dataPreparation');
      _confirmPercent = 0.15;
      _confirmError = null;
    });

    try {
      final filename = '${DateTime.now().millisecondsSinceEpoch}-$_phase.jpg';

      // 1. Upload to S3
      setState(() {
        _confirmMessage = _t('cameraCapture.sendingDocument');
        _confirmPercent = 0.3;
      });
      final signed = await _ctrl.apiService.generateSignedUploadUrl(
        objectName: filename,
        contentType: 'image/jpeg',
      );
      final signedUrl = signed['signedUrl'] as String? ?? '';
      if (signedUrl.isEmpty) throw StateError('URL signée introuvable.');

      final publicUrl = await _ctrl.apiService.uploadBytesToSignedUrl(
        signedUrl: signedUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      );
      final key = (signed['key'] as String?) ?? filename;
      _ctrl.saveUploadedFile(
        phase: _phase,
        url: publicUrl,
        name: filename,
        key: key,
      );

      // 2. Save document
      setState(() {
        _confirmMessage = _t('cameraCapture.savingDocument');
        _confirmPercent = 0.5;
      });
      await _saveDocument(
        phase: _phase,
        fileUrl: publicUrl,
        filename: filename,
      );

      // 3. Run validations
      final validations = captureValidationDefs(
        phase: _phase,
        hasBackPhase: _phases.contains('back'),
        lang: _lang,
      );
      for (var i = 0; i < validations.length; i++) {
        if (!mounted) return;
        final v = validations[i];
        setState(() {
          _confirmMessage = v.label;
          _confirmPercent = 0.5 + ((i + 1) / (validations.length + 1)) * 0.5;
        });

        final vPayload = _buildValidationPayload(
          step: v.step,
          phase: _phase,
          includeAll: true,
        );
        try {
          final resp = await _ctrl.apiService.applyRequestService(
            path: v.path.replaceAll('<id>', _ctrl.config.sessionId),
            data: vPayload,
            headers: _requestHeaders(),
          );
          final failure = captureValidationFailure(resp, v);
          if (failure != null && v.wait) {
            // `_submitting` doit retomber : sinon `_handleRetake` ignore le
            // clic sur « Reprendre » et l'utilisateur reste bloqué.
            setState(() {
              _submitting = false;
              _confirmStatus = 'error';
              _confirmError = failure.message;
              _confirmPercent = null;
            });
            return;
          }
        } catch (_) {
          if (v.wait) {
            setState(() {
              _submitting = false;
              _confirmStatus = 'error';
              _confirmError = v.errorMessage;
              _confirmPercent = null;
            });
            return;
          }
        }
      }

      // 4. Success
      setState(() {
        _confirmStatus = 'success';
        _confirmMessage = validations.isNotEmpty
            ? _t('cameraCapture.validationSuccess')
            : _t('cameraCapture.documentSaved');
        _confirmPercent = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      if (_isLastPhase) {
        final startedChainedDocument = _ctrl.completeCurrentDocumentAndContinue(
          completedSelectedOptionId: _ctrl.selectedChainedDocumentOption?['id']?.toString(),
        );
        if (!startedChainedDocument) {
          _ctrl.goToStep(DataleonFlowStep.success);
        }
        return;
      }

      setState(() {
        _phaseIndex += 1;
        _pendingConfirm = false;
        _capturedBytes = null;
        _submitting = false;
        _confirmStatus = null;
        _confirmMessage = null;
        _confirmPercent = null;
        _confirmError = null;
        _apiStatus = null;
        _apiMessage = null;
      });
      await _initCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _confirmStatus = 'error';
        _confirmError = e.toString();
        _confirmPercent = null;
      });
    }
  }

  void _handleRetake() {
    if (_submitting) return;
    final shouldRestartFromFront = _phase == 'back';

    setState(() {
      _pendingConfirm = false;
      _capturedBytes = null;
      _confirmStatus = null;
      _confirmMessage = null;
      _confirmPercent = null;
      _confirmError = null;
      _apiStatus = null;
      _apiMessage = null;
      _submitting = false;
      if (shouldRestartFromFront) _phaseIndex = 0;
    });
    _initCamera();
  }

  void _handleClose() {
    _stopLoop();
    _ctrl.handleCaptureClose();
  }

  // ---- API helpers ----

  Future<void> _saveDocument({
    required String phase,
    required String fileUrl,
    required String filename,
  }) async {
    final payload = _buildBasePayload(
      step: phase == 'face' ? 3 : 1,
      phase: phase,
      filename: filename,
    )..['url'] = '$fileUrl?filename=$filename';
    await _ctrl.apiService.applyRequestService(
      path:
          '/individuals/${_ctrl.config.sessionId}/verifications/save-document',
      data: payload,
      headers: _requestHeaders(),
    );
  }

  Map<String, String> _requestHeaders() {
    final h = <String, String>{'X-Session-ID': _sessionId};
    if (_ctrl.selectedCustomDocument != null) {
      h['X-Custom-Document'] = 'true';
    }
    return h;
  }

  Map<String, dynamic> _buildBasePayload({
    required int step,
    required String phase,
    required String filename,
  }) {
    final request = _ctrl.requestResult;
    final p = <String, dynamic>{
      'disable_auto_save_doc': 'true',
      'step': 'step-$step',
      'page_face': phase,
      'document_face': phase,
      'filename': filename,
      'form_document_type': _ctrl.documentType ?? '',
      'form_document_country': _ctrl.documentCountry ?? '',
      'session_id': _sessionId,
      'enable_card_detect': _isCardDocument.toString(),
      'request_type': 'webview',
    };
    final requestId = request['id'];
    if (requestId != null) {
      p['task_id'] = '$requestId';
      p['request_follow_id'] = '$requestId';
    }
    _parseRequestApiForm().forEach((k, v) {
      if (k == 'callback_url') {
        p['callback_url_rt'] = v;
      } else {
        p[k] = v;
      }
    });
    p.remove('callback_url');
    return p;
  }

  Map<String, dynamic> _buildValidationPayload({
    required int step,
    required String phase,
    required bool includeAll,
  }) {
    final p = _buildBasePayload(step: step, phase: phase, filename: '')
      ..['save_only_response'] = 'true';
    if (includeAll) {
      final docs = _orderedDocs();
      p['url'] = docs.map((d) => d['url']).toList();
      p['names'] = docs.map((d) => d['name']).toList();
      p['keyname'] = docs.map((d) => d['key']).toList();
    }
    return p;
  }

  Map<String, dynamic> _parseRequestApiForm() {
    final raw = _ctrl.requestResult['requestAPI'];
    if (raw is! String || raw.isEmpty) return const {};
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final f = d['form'];
      if (f is Map<String, dynamic>) return f;
    } catch (_) {}
    return const {};
  }

  List<Map<String, String>> _orderedDocs() {
    final docs = <Map<String, String>>[];
    for (final phase in const ['front', 'back', 'face']) {
      final f = _ctrl.uploadedFiles[phase];
      if (f == null) continue;
      docs.add({
        'url': f['url'] ?? '',
        'name': _docNameForPhase(phase),
        'key': f['key'] ?? '',
      });
    }
    return docs;
  }

  // ---- render helpers ----

  Widget _renderApiMessage(String msg) {
    final regex = RegExp(r'<k>(.*?)</k>');
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final m in regex.allMatches(msg)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: msg.substring(lastEnd, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(
          color: Color(0xFF4ADE80),
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < msg.length) {
      spans.add(TextSpan(text: msg.substring(lastEnd)));
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 14,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    if (_pendingConfirm) return _buildConfirmation();
    return _buildLiveCamera();
  }

  // ===================== LIVE CAMERA VIEW =====================

  Widget _buildLiveCamera() {
    final overlayOk = _apiStatus == 'ok' || _greenDelay;
    final guideColor = overlayOk ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF);
    final mq = MediaQuery.of(context);

    // Guide dimensions
    final double guideW, guideH;
    double guideOy;
    if (_isFace) {
      // Capsule like React selfieRect
      final bool isLandscape = mq.size.width > mq.size.height;
      guideW = isLandscape ? mq.size.height * 0.48 : mq.size.width * 0.65;
      guideH = isLandscape ? mq.size.height * 0.65 : mq.size.height * 0.52;
      guideOy = (mq.size.height - guideH) / 2 + mq.size.height * 0.04;
    } else {
      guideW = mq.size.width * 0.85;
      guideH = mq.size.height * 0.28;
      guideOy = (mq.size.height - guideH) / 2;
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_camReady && _cam != null && _cam!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cam!.value.previewSize!.height,
                  height: _cam!.value.previewSize!.width,
                  child: CameraPreview(_cam!),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Dimmed overlay with transparent cutout + border
          Positioned.fill(
            child: CustomPaint(
              painter: _GuideOverlayPainter(
                guideWidth: guideW,
                guideHeight: guideH,
                guideOffsetY: guideOy,
                borderColor: guideColor,
                isEllipse: _isFace,
              ),
            ),
          ),

          // Top: REC badge
          Positioned(
            top: mq.padding.top + 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Close button
          Positioned(
            top: mq.padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: _handleClose,
              child: const Icon(Icons.close, color: Colors.white, size: 26),
            ),
          ),

          // Title overlay
          Positioned(
            top: mq.padding.top + 50,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                  _phaseLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (_apiMessage != null)
                  _renderApiMessage(_apiMessage!)
                else
                  Text(
                    _t('cameraCapture.analyzing'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xAAFFFFFF),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),

          // Phase dots at bottom
          Positioned(
            bottom: mq.padding.bottom + 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_phases.length, (i) {
                final done = i < _phaseIndex ||
                    (i == _phaseIndex && (_apiStatus == 'ok' || _greenDelay));
                final active = i == _phaseIndex && !done;
                return Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFF22C55E)
                        : active
                            ? Colors.white
                            : Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          // Capture arrêtée sans succès (limite atteinte, étape fermée par le
          // serveur, erreurs répétées) : même feuille que la confirmation.
          if (_captureError != null) ...[
            const Positioned.fill(
              child: ColoredBox(color: Color(0x59000000)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildErrorSheet(
                message: _captureError!,
                buttonLabel: _t('cameraCapture.captureRetry'),
                onPressed: _handleCaptureRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================== CONFIRMATION VIEW =====================

  Widget _buildConfirmation() {
    final checklistItems = _isFace
        ? [
            _CheckItem(
              icon: Icons.wb_sunny_outlined,
              text: _t('cameraStatus.lightEnough'),
            ),
            _CheckItem(
              icon: Icons.visibility_outlined,
              text: _t('cameraStatus.eyesVisible'),
            ),
            _CheckItem(
              icon: Icons.face_outlined,
              text: _t('cameraStatus.faceVisible'),
            ),
          ]
        : [
            _CheckItem(
              icon: Icons.text_fields,
              text: _t('cameraStatus.text'),
            ),
            _CheckItem(
              icon: Icons.back_hand_outlined,
              text: _t('cameraStatus.cardOcclusion'),
            ),
            _CheckItem(
              icon: Icons.crop_free,
              text: _t('cameraStatus.corners'),
            ),
          ];

    final hasError = _confirmStatus == 'error' && _confirmError != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black,
          child: SafeArea(
            child: Column(
              children: [
                // Captured image
                Expanded(
                  child: Center(
                    child: _capturedBytes != null
                        ? Image.memory(_capturedBytes!, fit: BoxFit.contain)
                        : const SizedBox.shrink(),
                  ),
                ),

                // Bottom panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...checklistItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Icon(item.icon, color: Colors.white70, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // En erreur, la feuille blanche recouvre ce panneau :
                      // on garde la barre de progression dessous, comme la
                      // webview.
                      if (_confirmStatus != null)
                        _buildProgressBar()
                      else
                        _buildConfirmButtons(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          // Voile sombre : la feuille d'erreur passe au-dessus de tout l'écran.
          const Positioned.fill(
            child: ColoredBox(color: Color(0x59000000)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildErrorSheet(
              message: _confirmError!,
              buttonLabel: _t('cameraCapture.retake'),
              onPressed: _handleRetake,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _handleRetake,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: Colors.white70),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _t('cameraCapture.retake'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _handleConfirm,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: _btnColor,
              foregroundColor: _btnTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _t('cameraCapture.confirm'),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final isSuccess = _confirmStatus == 'success';
    final barColor = isSuccess ? const Color(0xFF22C55E) : Colors.white;
    const iconColor = Color(0xFF22C55E);

    return Column(
      children: [
        Text(
          '${_confirmMessage ?? ''}${_confirmStatus == 'progress' ? '...' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _confirmPercent ?? 0,
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            if (isSuccess) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: iconColor, size: 18),
            ],
          ],
        ),
      ],
    );
  }

  /// Feuille d'erreur blanche qui monte du bas et recouvre l'écran, à
  /// l'identique de la webview (icône dans un rond rouge pâle, texte sombre,
  /// bouton aux couleurs du workspace).
  Widget _buildErrorSheet({
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, offset, child) => FractionalTranslation(
        translation: Offset(0, offset),
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 50,
              offset: Offset(0, 25),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2), // red-50
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), // red-500
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827), // gray-900
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _btnColor,
                  foregroundColor: _btnTextColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _docNameForPhase(String phase) {
  switch (phase) {
    case 'front':
      return 'recto';
    case 'back':
      return 'verso';
    case 'face':
      return 'face';
    default:
      return phase;
  }
}

Color _parseColor(String? raw, Color fallback) {
  if (raw == null || raw.isEmpty) return fallback;
  final n = raw.replaceAll('#', '');
  final hex = n.length == 6 ? 'FF$n' : n;
  final v = int.tryParse(hex, radix: 16);
  return v == null ? fallback : Color(v);
}

class _GuideOverlayPainter extends CustomPainter {
  _GuideOverlayPainter({
    required this.guideWidth,
    required this.guideHeight,
    required this.guideOffsetY,
    required this.borderColor,
    required this.isEllipse,
  });

  final double guideWidth;
  final double guideHeight;
  final double guideOffsetY;
  final Color borderColor;
  final bool isEllipse;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final guideRect = Rect.fromLTWH(
      cx - guideWidth / 2,
      guideOffsetY,
      guideWidth,
      guideHeight,
    );

    // Full-screen path
    final fullPath = Path()..addRect(Offset.zero & size);

    // Cutout path — selfie uses capsule (rx=min(w/2,h/2)), doc uses rounded rect
    final cutoutPath = Path();
    final Radius cutoutRadius;
    if (isEllipse) {
      final r = guideWidth < guideHeight ? guideWidth / 2 : guideHeight / 2;
      cutoutRadius = Radius.circular(r);
    } else {
      cutoutRadius = const Radius.circular(16);
    }
    cutoutPath.addRRect(RRect.fromRectAndRadius(guideRect, cutoutRadius));

    // Dimmed area = full screen minus cutout
    final dimPath =
        Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(
      dimPath,
      Paint()..color = const Color(0x80000000), // 50% black
    );

    // Border around the cutout
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, cutoutRadius),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_GuideOverlayPainter old) =>
      old.guideWidth != guideWidth ||
      old.guideHeight != guideHeight ||
      old.borderColor != borderColor ||
      old.isEllipse != isEllipse;
}

class _CheckItem {
  const _CheckItem({required this.icon, required this.text});
  final IconData icon;
  final String text;
}
