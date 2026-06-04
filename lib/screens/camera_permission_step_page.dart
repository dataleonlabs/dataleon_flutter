import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';
import '../widgets/dataleon_step_header.dart';

class CameraPermissionStepPage extends StatefulWidget {
  final DataleonFlowController controller;

  const CameraPermissionStepPage({
    super.key,
    required this.controller,
  });

  @override
  State<CameraPermissionStepPage> createState() =>
      _CameraPermissionStepPageState();
}

class _CameraPermissionStepPageState extends State<CameraPermissionStepPage> {
  bool _cameraGranted = false;
  bool _checking = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _cameraImageUrl;
  bool _cameraImageLoading = false;
  String get _lang => widget.controller.languageCode;
  String _t(String key) => DataleonLocalizations.t(_lang, key);

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _fetchCameraActivationImage();
  }

  Future<void> _fetchCameraActivationImage() async {
    final adConfig = widget.controller.advancedDesignConfiguration;

    final imageKey =
        (adConfig['cameraActivationImageKey'] as String?)?.trim() ?? '';

    debugPrint('cameraActivationImageKey: $imageKey');

    if (imageKey.isEmpty) return;

    if (mounted) {
      setState(() => _cameraImageLoading = true);
    }

    if (imageKey.startsWith('http://') || imageKey.startsWith('https://')) {
      if (mounted) {
        setState(() {
          _cameraImageUrl = imageKey;
          _cameraImageLoading = false;
        });
      }
      return;
    }

    try {
      final signed = await widget.controller.apiService.generateSignedGetUrl(
        objectName: imageKey,
        bucket: 'yap-assets-customer',
      );

      final signedUrl =
          signed['signedUrl'] as String? ?? signed['url'] as String?;

      debugPrint('Camera activation image signed URL: $signedUrl');

      if (!mounted) return;

      setState(() {
        _cameraImageUrl = signedUrl;
        _cameraImageLoading = false;
      });
    } catch (e) {
      debugPrint('Camera activation image error: $e');

      if (!mounted) return;

      setState(() {
        _cameraImageLoading = false;
      });
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _cameraGranted = status.isGranted;
        _checking = false;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    setState(() {
      _checking = true;
      _hasError = false;
      _errorMessage = null;
    });
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isGranted) {
        setState(() {
          _cameraGranted = true;
          _checking = false;
        });
        widget.controller.nextStep();
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _checking = false;
          _hasError = true;
          _errorMessage = _t('cameraAccess.errors.denied');
        });
      } else {
        setState(() {
          _checking = false;
          _hasError = true;
          _errorMessage = _t('cameraAccess.errors.denied');
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _hasError = true;
        _errorMessage = _t('cameraAccess.errors.unknown');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.controller.dashboardConfiguration;
    final adConfig = widget.controller.advancedDesignConfiguration;
    final uniformColor = adConfig['uniformPrincipalColor'] == true;
    final accentColor = _parseColor(
      workspace['buttonColor'] as String?,
      const Color(0xFF111827),
    );
    final buttonColor = _parseColor(
      workspace['buttonColor'] as String?,
      const Color(0xFF222222),
    );
    final buttonTextColor = _parseColor(
      workspace['buttonTextColor'] as String?,
      Colors.white,
    );
    final effectiveButtonColor = uniformColor ? accentColor : buttonColor;

    final hasCustomCameraImageKey =
        ((adConfig['cameraActivationImageKey'] as String?)?.trim() ?? '')
            .isNotEmpty;

    final imageUrl = _cameraImageUrl ??
        (hasCustomCameraImageKey
            ? null
            : 'https://customer-assets.eu-west-1.dataleon.ai/AnimationKYC/GIF/Bleu%20Claire/Activer%20la%20cam.gif');

    Widget _buildCameraFallback(bool uniformColor, Color accentColor) {
      return Container(
        width: 120,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.camera_outlined,
          size: 48,
          color: uniformColor ? accentColor : const Color(0xFF374151),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            DataleonStepHeader(
              controller: widget.controller,
              onBack: widget.controller.previousStep,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      _t('cameraAccess.title'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('cameraAccess.description'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _cameraImageLoading
                            ? const SizedBox(
                                height: 210,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    key: ValueKey(imageUrl),
                                    height: 210,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    webHtmlElementStrategy:
                                        WebHtmlElementStrategy.prefer,
                                    errorBuilder: (_, error, ___) {
                                      debugPrint(
                                          'Camera image display error: $error');
                                      return _buildCameraFallback(
                                          uniformColor, accentColor);
                                    },
                                  )
                                : _buildCameraFallback(
                                    uniformColor, accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Privacy notice / error alert
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _hasError
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hasError
                            ? const Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: Color(0xFFDC2626),
                              )
                            : const Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: Colors.black,
                              ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _hasError
                                ? (_errorMessage ??
                                    _t('cameraAccess.errors.unknown'))
                                : _t('cameraAccess.privacy'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _hasError
                                  ? const Color(0xFFDC2626)
                                  : Colors.black,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _checking
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _cameraGranted
                                ? widget.controller.nextStep
                                : _requestCameraPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: effectiveButtonColor,
                              foregroundColor: buttonTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _hasError
                                      ? _t('common.retry')
                                      : _cameraGranted
                                          ? _t('cameraAccess.continue')
                                          : _t('cameraAccess.allowAccess'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 20),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.isEmpty) return fallback;
  final normalized = rawColor.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}
