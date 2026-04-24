import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

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

  String get _lang => widget.controller.languageCode;
  String _t(String key) => DataleonLocalizations.t(_lang, key);

  @override
  void initState() {
    super.initState();
    _checkPermission();
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
    setState(() => _checking = true);
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraGranted = status.isGranted;
        _checking = false;
      });
      if (status.isGranted) {
        widget.controller.nextStep();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.controller.dashboardConfiguration;
    final logoUrl = workspace['logo'] as String?
        ?? workspace['logoURLApp'] as String?;
    final logoHeight = (workspace['logoHeight'] as num?)?.toDouble() ?? 24;
    final buttonColor = _parseColor(
      workspace['buttonColor'] as String?,
      const Color(0xFF222222),
    );
    final buttonTextColor = _parseColor(
      workspace['buttonTextColor'] as String?,
      Colors.white,
    );

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.controller.previousStep,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 4),
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Image.network(
                      logoUrl,
                      height: logoHeight,
                      errorBuilder: (_, __, ___) => const _HeaderLogoFallback(),
                    )
                  else
                    const _HeaderLogoFallback(),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      _t('cameraAccess.title'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      _t('cameraAccess.description'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Camera GIF illustration
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://customer-assets.eu-west-1.dataleon.ai/AnimationKYC/GIF/Bleu%20Claire/Activer%20la%20cam.gif',
                          height: 210,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 48,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Security notice
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 22,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('cameraAccess.privacy'),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CTA button
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
                              backgroundColor: buttonColor,
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
                                  _cameraGranted
                                      ? _t('cameraAccess.continue')
                                      : _t('cameraAccess.allowAccess'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20),
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

class _HeaderLogoFallback extends StatelessWidget {
  const _HeaderLogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(Icons.bolt, size: 14, color: Colors.white),
      ),
    );
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
