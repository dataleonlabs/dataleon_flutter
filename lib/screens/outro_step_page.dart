import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';
import '../widgets/dataleon_step_header.dart';

class OutroStepPage extends StatefulWidget {
  const OutroStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  @override
  State<OutroStepPage> createState() => _OutroStepPageState();
}

class _OutroStepPageState extends State<OutroStepPage> {
  bool _submitting = true;
  bool _submitted = false;
  String? _errorMessage;
  Timer? _redirectTimer;
  int? _remainingSeconds;

  DataleonFlowController get _controller => widget.controller;

  Map<String, dynamic> get _dashboardConfiguration =>
      _controller.dashboardConfiguration;

  String get _lang => _controller.languageCode;
  String _t(String key, {Map<String, String>? params}) =>
      DataleonLocalizations.t(_lang, key, params: params);

  @override
  void initState() {
    super.initState();
    unawaited(_submitFinalDocuments());
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitFinalDocuments() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final payload = _buildFinalPayload();
      await _controller.apiService.submitFinishedDocuments(data: payload);
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _submitted = true;
      });
      _startRedirectIfNeeded();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  Map<String, dynamic> _buildFinalPayload() {
    final request = _controller.requestResult;
    final urls = <String>[];
    final names = <String>[];
    final forceTotalDocument = <String>[];

    final filesByDocument = _controller.uploadedFilesByDocument;
    if (filesByDocument.isNotEmpty) {
      for (final documentFiles in filesByDocument.values) {
        for (final phase in const ['front', 'back', 'face']) {
          final file = documentFiles[phase];
          if (file == null) {
            continue;
          }
          final originalName = file['name'] ?? '';
          final url = file['url'] ?? '';
          final documentName = _documentNameForPhase(phase);
          urls.add('$url?filename=$originalName');
          names.add(documentName);
          forceTotalDocument.add(documentName);
        }
      }
    } else {
      for (final phase in const ['front', 'back', 'face']) {
        final file = _controller.uploadedFiles[phase];
        if (file == null) {
          continue;
        }
        final originalName = file['name'] ?? '';
        final url = file['url'] ?? '';
        final documentName = _documentNameForPhase(phase);
        urls.add('$url?filename=$originalName');
        names.add(documentName);
        forceTotalDocument.add(documentName);
      }
    }

    final payload = <String, dynamic>{
      'url': urls,
      'names': names,
      'force_total_document': forceTotalDocument,
      'request_type': 'webview',
    };

    final requestId = request['id'];
    if (requestId != null) {
      payload['task_id'] = '$requestId';
      payload['request_follow_id'] = '$requestId';
    }

    final requestApiRaw = request['requestAPI'];
    if (requestApiRaw is String && requestApiRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(requestApiRaw) as Map<String, dynamic>;
        final form = decoded['form'];
        if (form is Map<String, dynamic>) {
          form.forEach((key, value) {
            if (key == 'callback_url') {
              payload['callback_url_rt'] = value;
            } else {
              payload[key] = value;
            }
          });
        }
      } catch (_) {
        // Keep a minimal final payload if requestAPI is malformed.
      }
    }

    payload.remove('callback_url');
    return payload;
  }

  void _startRedirectIfNeeded() {
    final redirectEnabled =
        _dashboardConfiguration['enableRedirection'] == true;
    final redirectUrl = _dashboardConfiguration['configUrlRedirect'] as String?;
    final delay = (_dashboardConfiguration['redirectionTime'] as num?)?.toInt();

    if (!redirectEnabled || redirectUrl == null || redirectUrl.isEmpty) {
      return;
    }

    final finalRedirectUri = _buildRedirectUri(redirectUrl);
    if (finalRedirectUri == null) {
      return;
    }

    final seconds = delay == null || delay <= 0 ? 5 : delay;
    setState(() {
      _remainingSeconds = seconds;
    });

    _redirectTimer?.cancel();
    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = _remainingSeconds;
      if (remaining == null) {
        timer.cancel();
        return;
      }

      if (remaining <= 1) {
        timer.cancel();
        await launchUrl(finalRedirectUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (mounted) {
        setState(() {
          _remainingSeconds = remaining - 1;
        });
      }
    });
  }

  Uri? _buildRedirectUri(String redirectUrl) {
    final parsedUri = Uri.tryParse(redirectUrl);
    if (parsedUri == null) {
      return null;
    }

    final queryParameters = <String, String>{
      ...parsedUri.queryParameters,
    };

    final sessionId = _controller.config.sessionId;
    if (sessionId.isNotEmpty) {
      queryParameters['id'] = sessionId;
    }

    final sourceId = _controller.requestResult['source_id'];
    if (sourceId != null && '$sourceId'.isNotEmpty) {
      queryParameters['source_id'] = '$sourceId';
    }

    return parsedUri.replace(queryParameters: queryParameters);
  }

  String _wcString(String key) {
    final val = _controller.webviewConfig[key];
    return val is String ? val.trim() : '';
  }

  String get _outroTitle {
    final hasChained = _controller.hasCompletedChainedCustomDocuments;
    if (hasChained) {
      if (_wcString('chainedDocument_outro_title').isNotEmpty) {
        return _wcString('chainedDocument_outro_title');
      }
      if (_wcString('outro_title').isNotEmpty) return _wcString('outro_title');
      return _t('outroStep.title');
    }
    // contentTitle (workspaceContent) > outro_title (config) > fallback
    final wc = _controller.webviewConfig;
    final outro = wc['outro'];
    if (outro is Map) {
      final t = outro['title'];
      if (t is String && t.isNotEmpty) return t;
    }
    if (_wcString('outro_title').isNotEmpty) return _wcString('outro_title');
    return _t('outroStep.title');
  }

  String get _outroDescription {
    final hasChained = _controller.hasCompletedChainedCustomDocuments;
    if (hasChained) {
      if (_wcString('chainedDocument_outro_description').isNotEmpty) {
        return _wcString('chainedDocument_outro_description');
      }
      if (_wcString('outro_description').isNotEmpty) {
        return _wcString('outro_description');
      }
      return _t('outroStep.description');
    }
    if (_wcString('outro_description').isNotEmpty) {
      return _wcString('outro_description');
    }
    final wc = _controller.webviewConfig;
    final outro = wc['outro'];
    if (outro is Map) {
      final d = outro['description'];
      if (d is String && d.isNotEmpty) return d;
    }
    return _t('outroStep.description');
  }

  @override
  Widget build(BuildContext context) {
    final adConfig = _controller.advancedDesignConfiguration;
    final uniformColor = adConfig['uniformPrincipalColor'] == true;
    final rawButtonColor = _dashboardConfiguration['buttonColor'] as String?;
    final buttonColor = _parseColor(
      rawButtonColor,
      const Color(0xFF111827),
    );
    final effectiveButtonColor =
        uniformColor ? _parseColor(rawButtonColor, const Color(0xFF111827)) : buttonColor;
    final buttonTextColor = _parseColor(
      _dashboardConfiguration['buttonTextColor'] as String?,
      Colors.white,
    );

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DataleonStepHeader(
              controller: _controller,
              onBack: _controller.previousStep,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Spacer(),
              // ---- icon ----
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: uniformColor
                        ? effectiveButtonColor.withValues(alpha: 0.12)
                        : const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 44,
                    color: uniformColor
                        ? effectiveButtonColor
                        : const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // ---- title ----
              Center(
                child: Text(
                  _outroTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // ---- description ----
              Center(
                child: Text(
                  _submitting ? _t('outroStep.submitting') : _outroDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ---- status ----
              if (_submitting)
                Center(
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: uniformColor ? effectiveButtonColor : null,
                    backgroundColor: uniformColor
                        ? effectiveButtonColor.withValues(alpha: 0.2)
                        : null,
                  ),
                )
              else if (_errorMessage != null)
                Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              if (_remainingSeconds != null && _submitted) ...[
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    _t('outroStep.redirect',
                        params: {'seconds': '$_remainingSeconds'}),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // ---- buttons ----
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _submitFinalDocuments,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_t('outroStep.retry')),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _controller.finish,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: effectiveButtonColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_t('outroStep.close')),
                ),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _documentNameForPhase(String phase) {
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

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.isEmpty) {
    return fallback;
  }

  final normalized = rawColor.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}
