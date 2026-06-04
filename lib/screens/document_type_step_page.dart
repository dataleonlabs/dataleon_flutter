import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';
import '../widgets/dataleon_step_header.dart';

class DocumentTypeStepPage extends StatelessWidget {
  const DocumentTypeStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  String get _lang => controller.languageCode;
  String _t(String key) => DataleonLocalizations.t(_lang, key);

  static const _fallbackIcon =
      'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png';

  static const _standardDocuments = <Map<String, String>>[
    {
      'key': 'id',
      'icon':
          'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png',
    },
    {
      'key': 'por',
      'icon':
          'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png',
    },
    {
      'key': 'permis',
      'icon':
          'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/driver-license-card.png',
    },
    {
      'key': 'passport',
      'icon':
          'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/passport.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = controller.dashboardConfiguration;
    final adConfig = controller.advancedDesignConfiguration;
    final uniformPrincipal = adConfig['uniformPrincipalColor'] == true;
    final accentColor = _parseColor(
      dashboardConfiguration['buttonColor'] as String?,
      const Color(0xFF111827),
    );

    final activation = (dashboardConfiguration['kycDocumentTypeActivation']
            as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final propertiesValidators =
        (controller.requestConfig?['properties_validators'] as List?) ??
            const [];

    final activeStandardDocuments = _standardDocuments.where((document) {
      return activation[document['key']] == true;
    }).toList();

    final documents = <_DocumentOption>[
      ...activeStandardDocuments.map(
        (document) => _DocumentOption(
          keyName: document['key']!,
          label: _t('documentTypeStep.documents.${document['key']}'),
          iconUrl: document['icon']!,
        ),
      ),
      ...controller.visibleCustomDocuments.map(
        (document) {
          final enriched = DataleonLocalizations.enrichCustomDoc(
            document,
            propertiesValidators,
          );
          final iconUrl = (document['icon'] as String?)?.trim();
          return _DocumentOption(
            keyName: document['key'] as String,
            label: DataleonLocalizations.customDocLabel(_lang, enriched),
            iconUrl: iconUrl != null && iconUrl.isNotEmpty
                ? iconUrl
                : _fallbackIcon,
            raw: enriched,
          );
        },
      ),
    ];

    final wc = controller.webviewConfig;
    final title = _wcString(wc, 'documentType_title').isNotEmpty
        ? _wcString(wc, 'documentType_title')
        : _wcString(wc, 'document_type_title').isNotEmpty
            ? _wcString(wc, 'document_type_title')
            : _t('documentTypeStep.title');
    final description = _wcString(wc, 'documentType_description').isNotEmpty
        ? _wcString(wc, 'documentType_description')
        : _wcString(wc, 'document_type_description').isNotEmpty
            ? _wcString(wc, 'document_type_description')
            : _t('documentTypeStep.description');

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            DataleonStepHeader(
              controller: controller,
              onBack: controller.previousStep,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.separated(
                        itemCount: documents.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = documents[index];
                          return _DocRow(
                            doc: doc,
                            uniformPrincipal: uniformPrincipal,
                            accentColor: accentColor,
                            onTap: () {
                              controller.selectDocumentType(
                                doc.keyName,
                                customDocument: doc.raw,
                              );
                              final isCustom = doc.raw != null;
                              final shouldSkipCountry = isCustom &&
                                  controller
                                      .shouldSkipCountryStepForCustomDocument(
                                          doc.raw);
                              if (controller.hasWorldCountryForDocType(
                                      doc.keyName) &&
                                  doc.keyName == 'passport') {
                                controller.selectDocumentCountry('');
                                controller.nextStep();
                                controller.nextStep();
                                return;
                              }
                              if (shouldSkipCountry) {
                                controller.selectDocumentCountry('');
                                controller.nextStep();
                                controller.nextStep();
                                return;
                              }
                              controller.nextStep();
                            },
                          );
                        },
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

  String _wcString(Map<String, dynamic> wc, String key) {
    final val = wc[key];
    return val is String ? val.trim() : '';
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.uniformPrincipal,
    required this.accentColor,
    required this.onTap,
  });

  final _DocumentOption doc;
  final bool uniformPrincipal;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Image.network(
      doc.iconUrl,
      width: 36,
      height: 36,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.description_outlined,
        size: 28,
        color: Color(0xFF6B7280),
      ),
    );

    if (uniformPrincipal) {
      iconWidget = ColorFiltered(
        colorFilter: ColorFilter.mode(
          accentColor.withValues(alpha: 0.85),
          BlendMode.srcATop,
        ),
        child: iconWidget,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            SizedBox(width: 36, height: 36, child: iconWidget),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                doc.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentOption {
  const _DocumentOption({
    required this.keyName,
    required this.label,
    required this.iconUrl,
    this.raw,
  });

  final String keyName;
  final String label;
  final String iconUrl;
  final Map<String, dynamic>? raw;
}

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.isEmpty) return fallback;
  final normalized = rawColor.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}
