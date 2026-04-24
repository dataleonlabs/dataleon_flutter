import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../flow/dataleon_flow_step.dart';
import '../i18n/dataleon_localizations.dart';

// ---------------------------------------------------------------------------
//  CameraCaptureStepPage – fullscreen realtime capture like the React version
// ---------------------------------------------------------------------------

class CameraCaptureStepPage extends StatefulWidget {
  const CameraCaptureStepPage({super.key, required this.controller});
  final DataleonFlowController controller;

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
  XFile? _capturedFile;

  // API loop
  bool _loopRunning = false;
  bool _sending = false;
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

  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _initCamera();
  }

  @override
  void dispose() {
    _stopLoop();
    _cam?.dispose();
    super.dispose();
  }

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
    return selfie
        ? const ['front', 'back', 'face']
        : const ['front', 'back'];
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
    if (custom != null) {
      return DataleonLocalizations.customDocLabel(_lang, custom);
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

  // ---- camera ----

  Future<void> _initCamera() async {
    setState(() {
      _camReady = false;
      _apiStatus = null;
      _apiMessage = null;
    });

    try {
      await _cam?.dispose();
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final lens =
          _isFace ? CameraLensDirection.front : CameraLensDirection.back;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
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
    _stopLoop();
    _loopRunning = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_loopRunning && mounted) {
      await _captureAndSend();
    }
  }

  void _stopLoop() {
    _loopRunning = false;
  }

  Future<void> _captureAndSend() async {
    if (_sending || !_camReady || _pendingConfirm || _greenDelay) return;
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;

    _sending = true;
    try {
      final file = await cam.takePicture();
      final bytes = await file.readAsBytes();
      final base64Img = base64Encode(bytes);

      // Get actual photo dimensions (decode once, cache for subsequent frames)
      if (_photoW == null || _photoH == null) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _photoW = frame.image.width.toDouble();
        _photoH = frame.image.height.toDouble();
        frame.image.dispose();
        codec.dispose();
      }
      final double pw = _photoW!;
      final double ph = _photoH!;

      // Overlay as proportions — same ratios as the visual guide on screen.
      // Applied directly to the actual photo dimensions so overlay matches image.
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

      final payload = <String, dynamic>{
        'image': base64Img,
        'step': _phase,
        'document_type': _ctrl.documentType ?? 'id',
        'document_country': (_ctrl.documentCountry ?? '').toUpperCase(),
        'language': _ctrl.languageCode,
        'session_id': _sessionId,
        'screen_w': pw.round(),
        'screen_h': ph.round(),
        'overlay_x': overlayX,
        'overlay_y': overlayY,
        'overlay_w': overlayW,
        'overlay_h': overlayH,
      };

      final data =
          await _ctrl.apiService.sendCaptureFrame(payload: payload);
      if (!mounted) return;

      final status = data['status'] as String?;
      final message = data['message'] as String?;

      setState(() {
        _apiStatus = status;
        _apiMessage = message;
      });

      if (status == 'ok') {
        _stopLoop();
        setState(() {
          _greenDelay = true;
          _capturedBytes = bytes;
          _capturedFile = file;
        });

        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
        setState(() {
          _greenDelay = false;
          _pendingConfirm = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiStatus = 'ko';
          _apiMessage = e.toString();
        });
      }
    } finally {
      _sending = false;
    }
  }

  // ---- confirmation flow ----

  Future<void> _handleConfirm() async {
    final bytes = _capturedBytes;
    final file = _capturedFile;
    if (bytes == null || file == null || _submitting) return;

    setState(() {
      _submitting = true;
      _confirmStatus = 'progress';
      _confirmMessage = _t('cameraCapture.dataPreparation');
      _confirmPercent = 0.15;
      _confirmError = null;
    });

    try {
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}-$_phase.jpg';

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
      final validations = _validationDefs(
        phase: _phase,
        hasBackPhase: _phases.contains('back'),
        lang: _lang,
      );
      for (var i = 0; i < validations.length; i++) {
        if (!mounted) return;
        final v = validations[i];
        setState(() {
          _confirmMessage = v.label;
          _confirmPercent =
              0.5 + ((i + 1) / (validations.length + 1)) * 0.5;
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
          if (_hasValidationFailure(resp) && v.wait) {
            setState(() {
              _confirmStatus = 'error';
              _confirmError = v.errorMessage;
              _confirmPercent = null;
            });
            return;
          }
        } catch (_) {
          if (v.wait) {
            setState(() {
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
        _ctrl.goToStep(DataleonFlowStep.success);
        return;
      }

      setState(() {
        _phaseIndex += 1;
        _pendingConfirm = false;
        _capturedBytes = null;
        _capturedFile = null;
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
      _capturedFile = null;
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
    _ctrl.previousStep();
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

  bool _hasValidationFailure(Map<String, dynamic> r) {
    if (r['success'] == false ||
        r['status'] == false ||
        r['error'] != null) {
      return true;
    }
    final d = r['data'];
    if (d is Map<String, dynamic> &&
        (d['success'] == false ||
            d['status'] == false ||
            d['error'] != null)) {
      return true;
    }
    return false;
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
    final guideColor =
        overlayOk ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final mq = MediaQuery.of(context);

    // Guide dimensions
    final double guideW, guideH;
    double guideOy;
    if (_isFace) {
      // Capsule like React selfieRect
      final bool isLandscape = mq.size.width > mq.size.height;
      guideW = isLandscape ? mq.size.height * 0.48 : mq.size.width * 0.65;
      guideH = isLandscape ? mq.size.height * 0.72 : mq.size.height * 0.6;
      guideOy = (mq.size.height - guideH) / 2;
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
              child:
                  const Icon(Icons.close, color: Colors.white, size: 26),
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
                    (i == _phaseIndex &&
                        (_apiStatus == 'ok' || _greenDelay));
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

    return Container(
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
                          Icon(item.icon,
                              color: Colors.white70, size: 20),
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
                  if (_confirmStatus == 'error' &&
                      _confirmError != null)
                    _buildErrorSheet()
                  else if (_confirmStatus != null)
                    _buildProgressBar()
                  else
                    _buildConfirmButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final barColor =
        isSuccess ? const Color(0xFF22C55E) : Colors.white;

    return Column(
      children: [
        Text(
          '${_confirmMessage ?? ''}${_confirmStatus == 'progress' ? '...' : ''}',
          textAlign: TextAlign.center,
          style:
              const TextStyle(color: Colors.white70, fontSize: 14),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            if (isSuccess) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                color: Color(0xFF22C55E),
                size: 18,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildErrorSheet() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFEF4444),
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          _confirmError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleRetake,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: _btnColor,
              foregroundColor: _btnTextColor,
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Validation definitions (same as React getPhaseValidations)
// ---------------------------------------------------------------------------

class _ValidationDef {
  const _ValidationDef({
    required this.path,
    required this.label,
    required this.errorMessage,
    required this.step,
    required this.wait,
  });

  final String path;
  final String label;
  final String errorMessage;
  final int step;
  final bool wait;
}

List<_ValidationDef> _validationDefs({
  required String phase,
  required bool hasBackPhase,
  required String lang,
}) {
  String t(String key) => DataleonLocalizations.t(lang, key);

  if (phase == 'back' || (phase == 'front' && !hasBackPhase)) {
    return [
      _ValidationDef(
        path: '/individuals/<id>/verifications/personal-data-checking',
        label: t('validations.personalData'),
        errorMessage: t('validations.personalDataError'),
        step: 1,
        wait: true,
      ),
      _ValidationDef(
        path: '/individuals/<id>/verifications/blacklist-detection',
        label: t('validations.blacklist'),
        errorMessage: t('validations.blacklistError'),
        step: 1,
        wait: false,
      ),
    ];
  }
  if (phase == 'face') {
    return [
      _ValidationDef(
        path: '/individuals/<id>/verifications/similarity-document',
        label: t('validations.faceSimilarity'),
        errorMessage: t('validations.faceSimilarityError'),
        step: 3,
        wait: true,
      ),
      _ValidationDef(
        path: '/individuals/<id>/verifications/facial-classification',
        label: t('validations.facialClassification'),
        errorMessage: t('validations.facialClassificationError'),
        step: 3,
        wait: false,
      ),
    ];
  }
  return const [];
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
    final dimPath = Path.combine(PathOperation.difference, fullPath, cutoutPath);
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
