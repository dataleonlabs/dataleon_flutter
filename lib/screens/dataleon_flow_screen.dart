import 'package:flutter/material.dart';

import '../core/dataleon_config.dart';
import '../core/dataleon_result.dart';
import '../core/dataleon_status.dart';
import '../flow/dataleon_flow_controller.dart';
import '../flow/dataleon_flow_step.dart';
import '../widgets/dataleon_primary_button.dart';
import '../widgets/dataleon_step_scaffold.dart';
import 'camera_capture_step_page.dart';
import 'camera_permission_step_page.dart';
import 'dataleon_loading_page.dart';
import 'document_country_step_page.dart';
import 'document_type_step_page.dart';
import 'outro_step_page.dart';
import '../i18n/dataleon_localizations.dart';
import 'welcome_step_page.dart';

typedef DataleonFlowStepBuilder = Widget Function(
  BuildContext context,
  DataleonFlowController controller,
  DataleonFlowStep step,
);

typedef DataleonFlowResultCallback = void Function(DataleonResult result);

/// Embeddable widget — no Scaffold imposed.
/// The client can place this inside a BottomSheet, Dialog, full screen, etc.
class DataleonFlowView extends StatefulWidget {
  final DataleonConfig config;
  final DataleonFlowController? controller;
  final Map<DataleonFlowStep, DataleonFlowStepBuilder>? stepBuilders;
  final DataleonFlowResultCallback? onResult;

  const DataleonFlowView({
    super.key,
    required this.config,
    this.controller,
    this.stepBuilders,
    this.onResult,
  });

  @override
  State<DataleonFlowView> createState() => _DataleonFlowViewState();
}

class _DataleonFlowViewState extends State<DataleonFlowView> {
  late final DataleonFlowController _controller;
  late final bool _ownsController;
  DataleonStatus? _lastReportedStatus;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        DataleonFlowController(config: widget.config);
    _ownsController = widget.controller == null;
    _controller.addListener(_handleControllerChanged);
    _controller.start();
    // Start by fetching config (shows loading page with progress bar)
    _controller.fetchConfig();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    final result = _controller.result;
    if (result.status != DataleonStatus.idle &&
        result.status != DataleonStatus.started &&
        result.status != _lastReportedStatus) {
      _lastReportedStatus = result.status;
      widget.onResult?.call(result);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildStep(context);
  }

  Widget _buildStep(BuildContext context) {
    final step = _controller.currentStep;
    final customBuilder = widget.stepBuilders?[step];

    if (customBuilder != null) {
      return customBuilder(context, _controller, step);
    }

    switch (step) {
      case DataleonFlowStep.loading:
        return DataleonLoadingPage(controller: _controller);
      case DataleonFlowStep.alreadyProcessed:
        return _buildAlreadyProcessed();
      case DataleonFlowStep.error:
        return _buildErrorPage();
      case DataleonFlowStep.welcome:
        return WelcomeStepPage(controller: _controller);
      case DataleonFlowStep.cameraPermission:
        return CameraPermissionStepPage(controller: _controller);
      case DataleonFlowStep.documentType:
        return DocumentTypeStepPage(controller: _controller);
      case DataleonFlowStep.documentCountry:
        return DocumentCountryStepPage(controller: _controller);
      case DataleonFlowStep.document:
        return CameraCaptureStepPage(controller: _controller);
      case DataleonFlowStep.selfie:
        return _defaultStep(
          title: 'Selfie',
          description: 'Take a selfie for verification.',
          cta: 'Continue',
          onPressed: _controller.nextStep,
        );
      case DataleonFlowStep.review:
        return _defaultStep(
          title: 'Review',
          description: 'Review before submitting.',
          cta: 'Submit',
          onPressed: _controller.nextStep,
        );
      case DataleonFlowStep.submitting:
        return _defaultStep(
          title: 'Submitting',
          description: 'Sending data to the server.',
          cta: 'Complete',
          onPressed: _controller.completeSession,
        );
      case DataleonFlowStep.success:
        return OutroStepPage(controller: _controller);
    }
  }

  Widget _buildAlreadyProcessed() {
    final lang = _controller.languageCode;
    String t(String key) => DataleonLocalizations.t(lang, key);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Soft gradient circle with check
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3010B981),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('common.alreadyProcessedTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('common.alreadyProcessedDesc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3010B981),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        t('common.close'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage() {
    final lang = _controller.languageCode;
    String t(String key) => DataleonLocalizations.t(lang, key);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFCA5A5), Color(0xFFDC2626)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x30EF4444),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('common.errorTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('common.errorDesc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF87171), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30EF4444),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        t('common.close'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultStep({
    required String title,
    required String description,
    required String cta,
    required VoidCallback onPressed,
  }) {
    return DataleonStepScaffold(
      title: title,
      description: description,
      child: const SizedBox.shrink(),
      actions: [
        Expanded(
          child: DataleonPrimaryButton(label: cta, onPressed: onPressed),
        ),
      ],
    );
  }
}

/// Convenience full-screen wrapper around [DataleonFlowView].
class DataleonFlowScreen extends StatelessWidget {
  final DataleonConfig config;
  final DataleonFlowController? controller;
  final Map<DataleonFlowStep, DataleonFlowStepBuilder>? stepBuilders;
  final DataleonFlowResultCallback? onResult;
  final String title;

  const DataleonFlowScreen({
    super.key,
    required this.config,
    this.controller,
    this.stepBuilders,
    this.onResult,
    this.title = 'Dataleon',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DataleonFlowView(
        config: config,
        controller: controller,
        stepBuilders: stepBuilders,
        onResult: onResult,
      ),
    );
  }
}

/// Helper to open the flow as a modal bottom sheet.
class DataleonBottomSheet {
  static Future<void> show({
    required BuildContext context,
    required DataleonConfig config,
    DataleonFlowController? controller,
    Map<DataleonFlowStep, DataleonFlowStepBuilder>? stepBuilders,
    DataleonFlowResultCallback? onResult,
    double heightFactor = 0.9,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * heightFactor,
        child: DataleonFlowView(
          config: config,
          controller: controller,
          stepBuilders: stepBuilders,
          onResult: onResult,
        ),
      ),
    );
  }
}
