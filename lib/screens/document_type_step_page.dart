import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

class DocumentTypeStepPage extends StatelessWidget {
  const DocumentTypeStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  String get _lang => controller.languageCode;
  String _t(String key) => DataleonLocalizations.t(_lang, key);

  static const _standardDocuments = <Map<String, String>>[
    {
      'key': 'id',
      'icon': 'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png',
    },
    {
      'key': 'por',
      'icon': 'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png',
    },
    {
      'key': 'permis',
      'icon': 'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/driver-license-card.png',
    },
    {
      'key': 'passport',
      'icon': 'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/passport.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = controller.dashboardConfiguration;
    final activation =
        (dashboardConfiguration['kycDocumentTypeActivation'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final customDocuments =
        (dashboardConfiguration['kycCustomDocuments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final buttonColor = _parseColor(
      dashboardConfiguration['buttonColor'] as String?,
      const Color(0xFF222222),
    );

    // Enrich custom documents with properties_validators + standard doc info
    final propertiesValidators =
        (controller.requestConfig?['properties_validators'] as List?) ?? const [];

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
      ...customDocuments.map(
        (document) {
          final enriched = DataleonLocalizations.enrichCustomDoc(
            document,
            propertiesValidators,
          );
          return _DocumentOption(
            keyName: document['key'] as String,
            label: DataleonLocalizations.customDocLabel(_lang, enriched),
            iconUrl: 'https://customer-assets.eu-west-1.dataleon.ai/kyc-assets/external-id-card-branding-yogi-aprelliyanto-detailed-outline-yogi-aprelliyanto.png',
            raw: enriched,
          );
        },
      ),
    ];

    return _DataleonScaffold(
      controller: controller,
      title: _t('documentTypeStep.title'),
      description: _t('documentTypeStep.description'),
      body: ListView.separated(
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final document = documents[index];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              controller.selectDocumentType(
                document.keyName,
                customDocument: document.raw,
              );
              if (controller.hasWorldCountryForDocType(document.keyName) &&
                  document.keyName == 'passport') {
                controller.selectDocumentCountry('');
                controller.nextStep();
                controller.nextStep();
                return;
              }
              controller.nextStep();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Image.network(
                        document.iconUrl,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.description_outlined,
                          size: 22,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      document.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          );
        },
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

class _DataleonScaffold extends StatelessWidget {
  const _DataleonScaffold({
    required this.controller,
    required this.title,
    required this.description,
    required this.body,
  });

  final DataleonFlowController controller;
  final String title;
  final String description;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = controller.dashboardConfiguration;
    final logoUrl = dashboardConfiguration['logo'] as String?
        ?? dashboardConfiguration['logoURLApp'] as String?;
    final logoHeight =
        (dashboardConfiguration['logoHeight'] as num?)?.toDouble() ?? 24;

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
                    onPressed: controller.previousStep,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                  ),
                  const SizedBox(width: 4),
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Image.network(
                      logoUrl,
                      height: logoHeight,
                      errorBuilder: (_, __, ___) => const Icon(Icons.bolt),
                    )
                  else
                    const Icon(Icons.bolt, color: Color(0xFF111827)),
                ],
              ),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(child: body),
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

Color _parseColor(String? rawColor, Color fallback) {
  if (rawColor == null || rawColor.isEmpty) {
    return fallback;
  }

  final normalized = rawColor.replaceAll('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? fallback : Color(value);
}