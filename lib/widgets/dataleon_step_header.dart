import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

class DataleonStepHeader extends StatelessWidget {
  const DataleonStepHeader({
    super.key,
    required this.controller,
    this.onBack,
  });

  final DataleonFlowController controller;
  final VoidCallback? onBack;

  static const String _customerAssetsBaseUrl =
      'https://customer-assets.eu-west-1.dataleon.ai';

  @override
  Widget build(BuildContext context) {
    final dash = controller.dashboardConfiguration;
    final adConfig = controller.advancedDesignConfiguration;
    final lang = controller.languageCode;

    final logoRaw = dash['logoAppURL'] as String? ??
        dash['logoAppUrl'] as String? ??
        dash['logoAoppURL'] as String? ??
        dash['logoAoppUrl'] as String? ??
        dash['logoURLApp'] as String? ??
        dash['faviconURLApp'] as String? ??
        dash['logo'] as String?;

    final logoUrl = _resolveCustomerAssetUrl(logoRaw);

    debugPrint('Resolved logo raw: $logoRaw');
    debugPrint('Resolved logo URL: $logoUrl');

    final rawLogoHeight = (dash['logoHeight'] as num?)?.toDouble() ??
        (dash['logoAppHeight'] as num?)?.toDouble();

    final logoHeight =
        rawLogoHeight == null || rawLogoHeight <= 0 ? 34.0 : rawLogoHeight;

    final rawLogoWidth = (dash['logoWidth'] as num?)?.toDouble() ??
        (dash['logoAppWidth'] as num?)?.toDouble();

    final logoWidth =
        rawLogoWidth == null || rawLogoWidth <= 0 ? 82.0 : rawLogoWidth;

    final progressEnabled = adConfig['progressBarEnabled'] == true;

    final progressCurrent =
        (adConfig['progressBarCurrent'] as num?)?.toInt() ?? 0;

    final progressTotal = (adConfig['progressBarTotal'] as num?)?.toInt() ?? 0;

    final clientColor = _parseColor(
      dash['buttonColor'] as String?,
      const Color(0xFFCF1744),
    );

    final progressPercent = progressTotal > 0
        ? (progressCurrent / progressTotal).clamp(0.0, 1.0)
        : 0.0;

    final progressPct = (progressPercent * 100).round();

    final progressLabel = DataleonLocalizations.t(lang, 'common.progressLabel');

    final stepLabel = DataleonLocalizations.t(lang, 'common.stepLabel');

    final stepText =
        progressTotal > 0 ? '$stepLabel $progressCurrent/$progressTotal' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progressEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 22, 28, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 292),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$progressPct%',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: clientColor,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          progressLabel,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w500,
                            color: clientColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Container(
                            height: 5,
                            width: constraints.maxWidth * progressPercent,
                            decoration: BoxDecoration(
                              color: clientColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      stepText,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: clientColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 10, 28, 0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 28, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onBack != null)
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: clientColor,
                      size: 18,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              if (logoUrl != null && logoUrl.isNotEmpty)
                SizedBox(
                  width: logoWidth,
                  height: logoHeight,
                  child: Image.network(
                    logoUrl,
                    width: logoWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    gaplessPlayback: true,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;

                      return SizedBox(
                        width: logoWidth,
                        height: logoHeight,
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Logo image error: $error');
                      return const SizedBox.shrink();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _resolveCustomerAssetUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final clean = value.trim();

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    return '$_customerAssetsBaseUrl/$clean';
  }
}

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.trim().isEmpty) return fallback;

  final normalized = rawColor.replaceAll('#', '').trim();
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);

  return value == null ? fallback : Color(value);
}
