import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

class WelcomeStepPage extends StatefulWidget {
  final DataleonFlowController controller;

  const WelcomeStepPage({
    super.key,
    required this.controller,
  });

  @override
  State<WelcomeStepPage> createState() => _WelcomeStepPageState();
}

class _WelcomeStepPageState extends State<WelcomeStepPage> {
  static const _languages = <Map<String, String>>[
    {'code': 'fr', 'label': 'Français', 'flag': '🇫🇷'},
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'label': 'العربية', 'flag': '🇸🇦'},
    {'code': 'de', 'label': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'it', 'label': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'pt', 'label': 'Português', 'flag': '🇵🇹'},
    {'code': 'es', 'label': 'Español', 'flag': '🇪🇸'},
    {'code': 'nl', 'label': 'Nederlands', 'flag': '🇳🇱'},
  ];

  String get _lang => widget.controller.languageCode;
  String _t(String key, {Map<String, String>? params}) =>
      DataleonLocalizations.t(_lang, key, params: params);

  Future<void> _openExternalLink(String? url) async {
    if (url == null || url.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickLanguage() async {
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _t('common.language'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    itemCount: _languages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final language = _languages[index];
                      final isSelected = widget.controller.languageCode ==
                          language['code'];
                      return InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(language['code']),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                language['flag'] ?? '',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  language['label']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF111827)
                                        : const Color(0xFFD1D5DB),
                                    width: isSelected ? 5 : 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCode != null) {
      widget.controller.setLanguage(selectedCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = widget.controller.dashboardConfiguration;
    final applicationName =
        dashboardConfiguration['applicationName'] as String? ?? 'Dataleon';
    final logoUrl = dashboardConfiguration['logo'] as String?
        ?? dashboardConfiguration['logoURLApp'] as String?;
    final logoHeight =
        (dashboardConfiguration['logoHeight'] as num?)?.toDouble() ?? 30;
    final buttonColor = _parseColor(
      dashboardConfiguration['buttonColor'] as String?,
      const Color(0xFF222222),
    );
    final buttonTextColor = _parseColor(
      dashboardConfiguration['buttonTextColor'] as String?,
      Colors.white,
    );
    final cguUrl = dashboardConfiguration['configUrlCgu'] as String?;
    final privacyUrl = dashboardConfiguration['configUrlPrivacyPolicy'] as String?;
    final selectedLanguage = _languages.firstWhere(
      (language) => language['code'] == widget.controller.languageCode,
      orElse: () => _languages.first,
    );

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: _DataleonLogo(
                applicationName: applicationName,
                logoUrl: logoUrl,
                logoHeight: logoHeight,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: '$applicationName ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: _t('intro.preambule', params: {'appName': ''}),
                          ),
                          const TextSpan(
                            text: '2 minutes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _t('intro.preambleTitle'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('intro.requirements.title'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RequirementItem(
                      icon: Icons.camera_rear_outlined,
                      text: _t('intro.requirements.rearCamera'),
                    ),
                    const SizedBox(height: 12),
                    _RequirementItem(
                      icon: Icons.badge_outlined,
                      text: _t('intro.requirements.idDocument'),
                    ),
                    const SizedBox(height: 12),
                    _RequirementItem(
                      icon: Icons.camera_front_outlined,
                      text: _t('intro.requirements.frontCamera'),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 22,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t('intro.dataSecurity'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _pickLanguage,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedLanguage['flag'] ?? '',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedLanguage['label']!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: _t('intro.termsNotice')),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openExternalLink(cguUrl),
                            child: Text(
                              _t('intro.termsOfUse'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                decoration: TextDecoration.underline,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: _t('intro.and')),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => _openExternalLink(privacyUrl),
                            child: Text(
                              _t('intro.privacyPolicy'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                decoration: TextDecoration.underline,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: widget.controller.nextStep,
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
                            _t('intro.startVerification'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
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

class _DataleonLogo extends StatelessWidget {
  const _DataleonLogo({
    required this.applicationName,
    required this.logoUrl,
    required this.logoHeight,
  });

  final String applicationName;
  final String? logoUrl;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (logoUrl != null && logoUrl!.isNotEmpty)
          Image.network(
            logoUrl!,
            height: logoHeight,
            errorBuilder: (_, __, ___) => const _LogoFallback(),
          )
        else
          const _LogoFallback(),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.bolt, size: 18, color: Colors.white),
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RequirementItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          child: Icon(icon, size: 26, color: Colors.black),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
      ],
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
