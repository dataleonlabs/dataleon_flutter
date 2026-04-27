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
    {'code': 'fr', 'label': 'Français', 'flag': '🇫🇷', 'short': 'FRA'},
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧', 'short': 'GB'},
    {'code': 'ar', 'label': 'العربية', 'flag': '🇸🇦', 'short': 'SA'},
    {'code': 'de', 'label': 'Deutsch', 'flag': '🇩🇪', 'short': 'DEU'},
    {'code': 'it', 'label': 'Italiano', 'flag': '🇮🇹', 'short': 'ITA'},
    {'code': 'pt', 'label': 'Português', 'flag': '🇵🇹', 'short': 'PRT'},
    {'code': 'es', 'label': 'Español', 'flag': '🇪🇸', 'short': 'ESP'},
    {'code': 'nl', 'label': 'Nederlands', 'flag': '🇳🇱', 'short': 'NLD'},
  ];

  bool _isLanguagePageOpen = false;
  String _languageSearch = '';
  late String _pendingLanguageCode;

  String get _lang => widget.controller.languageCode;
  String _t(String key, {Map<String, String>? params}) =>
      DataleonLocalizations.t(_lang, key, params: params);
  String _tr(String key, {String? fallback, Map<String, String>? params}) =>
      DataleonLocalizations.t(_lang, key, fallback: fallback, params: params);

  @override
  void initState() {
    super.initState();
    _pendingLanguageCode = widget.controller.languageCode;
  }

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

  void _openLanguagePage() {
    setState(() {
      _pendingLanguageCode = widget.controller.languageCode;
      _languageSearch = '';
      _isLanguagePageOpen = true;
    });
  }

  void _closeLanguagePage() {
    setState(() {
      _isLanguagePageOpen = false;
      _languageSearch = '';
      _pendingLanguageCode = widget.controller.languageCode;
    });
  }

  void _applyLanguageSelection() {
    widget.controller.setLanguage(_pendingLanguageCode);
    setState(() {
      _isLanguagePageOpen = false;
      _languageSearch = '';
    });
  }

  List<Map<String, String>> _filteredLanguages() {
    final query = _languageSearch.trim().toLowerCase();
    if (query.isEmpty) {
      return _languages;
    }

    return _languages.where((language) {
      return (language['label'] ?? '').toLowerCase().contains(query) ||
          (language['short'] ?? '').toLowerCase().contains(query) ||
          (language['code'] ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildLanguageSelectionPage(Color accentColor) {
    final filteredLanguages = _filteredLanguages();

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  InkWell(
                    onTap: _closeLanguagePage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tr(
                        'common.selectLanguage',
                        fallback: _t('common.language'),
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _languageSearch = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: _tr('common.search', fallback: 'Search'),
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9CA3AF),
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: filteredLanguages.length,
                itemBuilder: (context, index) {
                  final language = filteredLanguages[index];
                  final isSelected = _pendingLanguageCode == language['code'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _pendingLanguageCode = language['code']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.08)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? accentColor : Colors.transparent,
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            language['flag'] ?? '',
                            style: const TextStyle(fontSize: 42),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            language['short'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? accentColor
                                  : const Color(0xFF374151),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _applyLanguageSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _t('common.continue'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = widget.controller.dashboardConfiguration;
    final applicationName =
        dashboardConfiguration['applicationName'] as String? ?? 'Dataleon';
    final logoUrl = dashboardConfiguration['logo'] as String? ??
        dashboardConfiguration['logoURLApp'] as String?;
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
    final accentColor = _parseColor(
      dashboardConfiguration['buttonColor'] as String?,
      const Color(0xFFE8505B),
    );
    final cguUrl = dashboardConfiguration['configUrlCgu'] as String?;
    final privacyUrl =
        dashboardConfiguration['configUrlPrivacyPolicy'] as String?;
    final selectedLanguage = _languages.firstWhere(
      (language) => language['code'] == widget.controller.languageCode,
      orElse: () => _languages.first,
    );

    if (_isLanguagePageOpen) {
      return _buildLanguageSelectionPage(accentColor);
    }

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
                            text:
                                _t('intro.preambule', params: {'appName': ''}),
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
                    onTap: _openLanguagePage,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            color: Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
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
                                color: Color(0xFF374151),
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
