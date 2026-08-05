import 'dart:async';

import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

/// Branded full-page loader for the KYC flow.
///
/// Two visual phases:
///  * Phase 1 — an indeterminate spinner, shown from app open until the public
///    `/config/chart` branding call resolves.
///  * Phase 2 — a determinate progress bar with the client logo (or app name)
///    above it, filled with the client's principal color, and a single line
///    below showing the per-step message followed by the percentage.
class DataleonLoadingPage extends StatefulWidget {
  final DataleonFlowController controller;

  const DataleonLoadingPage({
    super.key,
    required this.controller,
  });

  @override
  State<DataleonLoadingPage> createState() => _DataleonLoadingPageState();
}

class _DataleonLoadingPageState extends State<DataleonLoadingPage> {
  /// Fixed logo height on the loading screen. The branding `logoHeight` field
  /// is intentionally NOT used here — it is reserved for the header.
  static const double _logoHeight = 48;

  /// Neutral grey fallback for the bar when no principal color is provided.
  static const Color _fallbackBarColor = Color(0xFF6A7282);

  double _displayProgress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    widget.controller.addListener(_controllerListener);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_controllerListener);
    super.dispose();
  }

  void _controllerListener() {
    // Just rebuild on chart resolution / message-phase changes. The easing
    // loop already starts the bar from 0 because numeric progress is reset to
    // 0 by the controller when the chart resolves. (Resetting _displayProgress
    // here would fire on every notification during phase 2 and make the bar
    // repeatedly jump back to 0 and refill.)
    if (mounted) {
      setState(() {});
    }
  }

  void _startAnimation() {
    // ~60fps smooth animation, easing toward actual progress.
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final target = widget.controller.progress;
      setState(() {
        if (target >= 100 && _displayProgress >= 99.5) {
          _displayProgress = 100;
          return;
        }
        _displayProgress += (target - _displayProgress) * 0.1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 1: a small indeterminate loader only (NO progress bar) until the
    // public chart config resolves. The determinate bar appears in phase 2.
    if (!widget.controller.isChartResolved) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_fallbackBarColor),
            ),
          ),
        ),
      );
    }

    // Phase 2: determinate progress bar with branding and a per-step message.
    final controller = widget.controller;
    final lang = controller.languageCode;
    final barColor =
        _parseColor(controller.brandingPrincipalColor, _fallbackBarColor);
    final pct = _displayProgress.round();
    final messageKey = controller.loadingMessageKey;
    final message = messageKey.isEmpty
        ? ''
        : DataleonLocalizations.t(lang, 'loadingScreen.$messageKey');
    // Single line: message first, then percentage.
    final statusLine = message.isEmpty ? '$pct %' : '$message · $pct %';

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Main centered content
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo (fixed height) or app name fallback.
                  _buildBrand(
                    controller.brandingLogoUrl,
                    controller.brandingAppName,
                  ),
                  const SizedBox(height: 22),
                  // Progress bar filled with the client's principal color.
                  SizedBox(
                    width: 200,
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _displayProgress / 100,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Per-step message + percentage on a single line.
                  Text(
                    statusLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom disclaimer. White-label clients never see it; until the
          // workspace resolves the flag is unknown, so we withhold it rather
          // than let it flash on screen mid-loading.
          if (controller.isWorkspaceResolved &&
              !controller.hideDataleonBranding)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text.rich(
                TextSpan(
                  text:
                      'Cette opération est effectuée via la plateforme certifiée et sécurisée ',
                  children: [
                    const TextSpan(
                      text: 'Dataleon',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Logo at a fixed height, or the app name as text when there is no logo
  /// (or it fails to load).
  Widget _buildBrand(String? logoUrl, String? appName) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return SizedBox(
        width: 160,
        height: _logoHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Image.network(
                logoUrl,
                height: _logoHeight,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                loadingBuilder: (context, child, loadingProgress) =>
                    loadingProgress == null
                        ? child
                        : SizedBox(
                            height: _logoHeight,
                            width: 160,
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_not_supported, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          logoUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _appNameText(appName);
  }

  Widget _appNameText(String? appName) {
    final name = appName?.trim() ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Text(
      name,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.trim().isEmpty) return fallback;

  final normalized = rawColor.replaceAll('#', '').trim();
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);

  return value == null ? fallback : Color(value);
}
