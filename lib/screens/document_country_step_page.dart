import 'package:flutter/material.dart';

import '../flow/dataleon_flow_controller.dart';
import '../i18n/dataleon_localizations.dart';

class DocumentCountryStepPage extends StatefulWidget {
  const DocumentCountryStepPage({
    super.key,
    required this.controller,
  });

  final DataleonFlowController controller;

  @override
  State<DocumentCountryStepPage> createState() => _DocumentCountryStepPageState();
}

class _DocumentCountryStepPageState extends State<DocumentCountryStepPage> {
  final TextEditingController _searchController = TextEditingController();

  String get _lang => widget.controller.languageCode;
  String _t(String key) => DataleonLocalizations.t(_lang, key);

  static const _countryNames = <String, String>{
    'AF': 'Afghanistan', 'ZA': 'Afrique du Sud', 'AL': 'Albanie',
    'DZ': 'Algérie', 'DE': 'Allemagne', 'AD': 'Andorre', 'AO': 'Angola',
    'AG': 'Antigua-et-Barbuda', 'SA': 'Arabie saoudite', 'AR': 'Argentine',
    'AM': 'Arménie', 'AU': 'Australie', 'AT': 'Autriche', 'AZ': 'Azerbaïdjan',
    'BS': 'Bahamas', 'BH': 'Bahreïn', 'BD': 'Bangladesh', 'BB': 'Barbade',
    'BE': 'Belgique', 'BZ': 'Belize', 'BJ': 'Bénin', 'BT': 'Bhoutan',
    'BY': 'Biélorussie', 'MM': 'Birmanie', 'BO': 'Bolivie',
    'BA': 'Bosnie-Herzégovine', 'BW': 'Botswana', 'BR': 'Brésil',
    'BN': 'Brunei', 'BG': 'Bulgarie', 'BF': 'Burkina Faso', 'BI': 'Burundi',
    'KH': 'Cambodge', 'CM': 'Cameroun', 'CA': 'Canada', 'CV': 'Cap-Vert',
    'CF': 'Centrafrique', 'CL': 'Chili', 'CN': 'Chine', 'CY': 'Chypre',
    'CO': 'Colombie', 'KM': 'Comores', 'KP': 'Corée du Nord',
    'KR': 'Corée du Sud', 'CR': 'Costa Rica', 'CI': "Côte d'Ivoire",
    'HR': 'Croatie', 'CU': 'Cuba', 'DK': 'Danemark', 'DJ': 'Djibouti',
    'DM': 'Dominique', 'EG': 'Égypte', 'AE': 'Émirats arabes unis',
    'EC': 'Équateur', 'ER': 'Érythrée', 'ES': 'Espagne', 'EE': 'Estonie',
    'SZ': 'Eswatini', 'US': 'États-Unis', 'ET': 'Éthiopie', 'FJ': 'Fidji',
    'FI': 'Finlande', 'FR': 'France', 'GA': 'Gabon', 'GM': 'Gambie',
    'GE': 'Géorgie', 'GH': 'Ghana', 'GR': 'Grèce', 'GD': 'Grenade',
    'GT': 'Guatemala', 'GN': 'Guinée', 'GQ': 'Guinée équatoriale',
    'GW': 'Guinée-Bissau', 'GY': 'Guyana', 'HT': 'Haïti', 'HN': 'Honduras',
    'HU': 'Hongrie', 'IN': 'Inde', 'ID': 'Indonésie', 'IQ': 'Irak',
    'IR': 'Iran', 'IE': 'Irlande', 'IS': 'Islande', 'IL': 'Israël',
    'IT': 'Italie', 'JM': 'Jamaïque', 'JP': 'Japon', 'JO': 'Jordanie',
    'KZ': 'Kazakhstan', 'KE': 'Kenya', 'KG': 'Kirghizistan', 'KI': 'Kiribati',
    'KW': 'Koweït', 'LA': 'Laos', 'LS': 'Lesotho', 'LV': 'Lettonie',
    'LB': 'Liban', 'LR': 'Liberia', 'LY': 'Libye', 'LI': 'Liechtenstein',
    'LT': 'Lituanie', 'LU': 'Luxembourg', 'MK': 'Macédoine du Nord',
    'MG': 'Madagascar', 'MY': 'Malaisie', 'MW': 'Malawi', 'MV': 'Maldives',
    'ML': 'Mali', 'MT': 'Malte', 'MA': 'Maroc', 'MU': 'Maurice',
    'MR': 'Mauritanie', 'MX': 'Mexique', 'FM': 'Micronésie', 'MD': 'Moldavie',
    'MC': 'Monaco', 'MN': 'Mongolie', 'ME': 'Monténégro', 'MZ': 'Mozambique',
    'NA': 'Namibie', 'NR': 'Nauru', 'NP': 'Népal', 'NI': 'Nicaragua',
    'NE': 'Niger', 'NG': 'Nigeria', 'NO': 'Norvège', 'NZ': 'Nouvelle-Zélande',
    'OM': 'Oman', 'UG': 'Ouganda', 'UZ': 'Ouzbékistan', 'PK': 'Pakistan',
    'PW': 'Palaos', 'PS': 'Palestine', 'PA': 'Panama', 'PG': 'Papouasie-Nouvelle-Guinée',
    'PY': 'Paraguay', 'NL': 'Pays-Bas', 'PE': 'Pérou', 'PH': 'Philippines',
    'PL': 'Pologne', 'PT': 'Portugal', 'QA': 'Qatar', 'CD': 'RD Congo',
    'CG': 'Congo', 'DO': 'République dominicaine', 'CZ': 'République tchèque',
    'RO': 'Roumanie', 'GB': 'Royaume-Uni', 'RU': 'Russie', 'RW': 'Rwanda',
    'KN': 'Saint-Kitts-et-Nevis', 'VC': 'Saint-Vincent-et-les-Grenadines',
    'LC': 'Sainte-Lucie', 'SB': 'Salomon', 'SV': 'Salvador', 'WS': 'Samoa',
    'ST': 'Sao Tomé-et-Príncipe', 'SN': 'Sénégal', 'RS': 'Serbie',
    'SC': 'Seychelles', 'SL': 'Sierra Leone', 'SG': 'Singapour',
    'SK': 'Slovaquie', 'SI': 'Slovénie', 'SO': 'Somalie', 'SD': 'Soudan',
    'SS': 'Soudan du Sud', 'LK': 'Sri Lanka', 'SE': 'Suède', 'CH': 'Suisse',
    'SR': 'Suriname', 'SY': 'Syrie', 'TJ': 'Tadjikistan', 'TZ': 'Tanzanie',
    'TD': 'Tchad', 'TH': 'Thaïlande', 'TL': 'Timor oriental', 'TG': 'Togo',
    'TO': 'Tonga', 'TT': 'Trinité-et-Tobago', 'TN': 'Tunisie',
    'TM': 'Turkménistan', 'TR': 'Turquie', 'TV': 'Tuvalu', 'UA': 'Ukraine',
    'UY': 'Uruguay', 'VU': 'Vanuatu', 'VA': 'Vatican', 'VE': 'Venezuela',
    'VN': 'Vietnam', 'YE': 'Yémen', 'ZM': 'Zambie', 'ZW': 'Zimbabwe',
    'world': 'Monde entier',
  };

  /// ISO 3166-1 alpha-3 → alpha-2 mapping
  static const _iso3ToIso2 = <String, String>{
    'AFG': 'AF', 'ZAF': 'ZA', 'ALB': 'AL', 'DZA': 'DZ', 'DEU': 'DE',
    'AND': 'AD', 'AGO': 'AO', 'ATG': 'AG', 'SAU': 'SA', 'ARG': 'AR',
    'ARM': 'AM', 'AUS': 'AU', 'AUT': 'AT', 'AZE': 'AZ', 'BHS': 'BS',
    'BHR': 'BH', 'BGD': 'BD', 'BRB': 'BB', 'BEL': 'BE', 'BLZ': 'BZ',
    'BEN': 'BJ', 'BTN': 'BT', 'BLR': 'BY', 'MMR': 'MM', 'BOL': 'BO',
    'BIH': 'BA', 'BWA': 'BW', 'BRA': 'BR', 'BRN': 'BN', 'BGR': 'BG',
    'BFA': 'BF', 'BDI': 'BI', 'KHM': 'KH', 'CMR': 'CM', 'CAN': 'CA',
    'CPV': 'CV', 'CAF': 'CF', 'CHL': 'CL', 'CHN': 'CN', 'CYP': 'CY',
    'COL': 'CO', 'COM': 'KM', 'PRK': 'KP', 'KOR': 'KR', 'CRI': 'CR',
    'CIV': 'CI', 'HRV': 'HR', 'CUB': 'CU', 'DNK': 'DK', 'DJI': 'DJ',
    'DMA': 'DM', 'EGY': 'EG', 'ARE': 'AE', 'ECU': 'EC', 'ERI': 'ER',
    'ESP': 'ES', 'EST': 'EE', 'SWZ': 'SZ', 'USA': 'US', 'ETH': 'ET',
    'FJI': 'FJ', 'FIN': 'FI', 'FRA': 'FR', 'GAB': 'GA', 'GMB': 'GM',
    'GEO': 'GE', 'GHA': 'GH', 'GRC': 'GR', 'GRD': 'GD', 'GTM': 'GT',
    'GIN': 'GN', 'GNQ': 'GQ', 'GNB': 'GW', 'GUY': 'GY', 'HTI': 'HT',
    'HND': 'HN', 'HUN': 'HU', 'IND': 'IN', 'IDN': 'ID', 'IRQ': 'IQ',
    'IRN': 'IR', 'IRL': 'IE', 'ISL': 'IS', 'ISR': 'IL', 'ITA': 'IT',
    'JAM': 'JM', 'JPN': 'JP', 'JOR': 'JO', 'KAZ': 'KZ', 'KEN': 'KE',
    'KGZ': 'KG', 'KIR': 'KI', 'KWT': 'KW', 'LAO': 'LA', 'LSO': 'LS',
    'LVA': 'LV', 'LBN': 'LB', 'LBR': 'LR', 'LBY': 'LY', 'LIE': 'LI',
    'LTU': 'LT', 'LUX': 'LU', 'MKD': 'MK', 'MDG': 'MG', 'MYS': 'MY',
    'MWI': 'MW', 'MDV': 'MV', 'MLI': 'ML', 'MLT': 'MT', 'MAR': 'MA',
    'MUS': 'MU', 'MRT': 'MR', 'MEX': 'MX', 'FSM': 'FM', 'MDA': 'MD',
    'MCO': 'MC', 'MNG': 'MN', 'MNE': 'ME', 'MOZ': 'MZ', 'NAM': 'NA',
    'NRU': 'NR', 'NPL': 'NP', 'NIC': 'NI', 'NER': 'NE', 'NGA': 'NG',
    'NOR': 'NO', 'NZL': 'NZ', 'OMN': 'OM', 'UGA': 'UG', 'UZB': 'UZ',
    'PAK': 'PK', 'PLW': 'PW', 'PSE': 'PS', 'PAN': 'PA', 'PNG': 'PG',
    'PRY': 'PY', 'NLD': 'NL', 'PER': 'PE', 'PHL': 'PH', 'POL': 'PL',
    'PRT': 'PT', 'QAT': 'QA', 'COD': 'CD', 'COG': 'CG', 'DOM': 'DO',
    'CZE': 'CZ', 'ROU': 'RO', 'GBR': 'GB', 'RUS': 'RU', 'RWA': 'RW',
    'KNA': 'KN', 'VCT': 'VC', 'LCA': 'LC', 'SLB': 'SB', 'SLV': 'SV',
    'WSM': 'WS', 'STP': 'ST', 'SEN': 'SN', 'SRB': 'RS', 'SYC': 'SC',
    'SLE': 'SL', 'SGP': 'SG', 'SVK': 'SK', 'SVN': 'SI', 'SOM': 'SO',
    'SDN': 'SD', 'SSD': 'SS', 'LKA': 'LK', 'SWE': 'SE', 'CHE': 'CH',
    'SUR': 'SR', 'SYR': 'SY', 'TJK': 'TJ', 'TZA': 'TZ', 'TCD': 'TD',
    'THA': 'TH', 'TLS': 'TL', 'TGO': 'TG', 'TON': 'TO', 'TTO': 'TT',
    'TUN': 'TN', 'TKM': 'TM', 'TUR': 'TR', 'TUV': 'TV', 'UKR': 'UA',
    'URY': 'UY', 'VUT': 'VU', 'VAT': 'VA', 'VEN': 'VE', 'VNM': 'VN',
    'YEM': 'YE', 'ZMB': 'ZM', 'ZWE': 'ZW',
    'HKG': 'HK', 'TWN': 'TW', 'MAC': 'MO', 'XKX': 'XK',
  };

  String _countryDisplayName(String code) {
    final upper = code.toUpperCase();
    // Try direct lookup (alpha-2)
    if (_countryNames.containsKey(upper)) return _countryNames[upper]!;
    // Try alpha-3 → alpha-2 conversion
    final iso2 = _iso3ToIso2[upper];
    if (iso2 != null && _countryNames.containsKey(iso2)) return _countryNames[iso2]!;
    // Try original case (e.g. 'world')
    if (_countryNames.containsKey(code)) return _countryNames[code]!;
    return code;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardConfiguration = widget.controller.dashboardConfiguration;
    final selectedDocumentType = widget.controller.documentType;
    final customCountries = widget.controller.selectedCustomDocument?['countries'];
    final kycCountries = dashboardConfiguration['kycCountries'] as Map<String, dynamic>?;
    final countriesSource = (customCountries as List?) ??
        (kycCountries != null ? kycCountries[selectedDocumentType] as List? : null) ??
        const [];

    final countryCodes = <String>{};
    for (final item in countriesSource) {
      if (item is Map<String, dynamic>) {
        if (item['value'] is String) {
          countryCodes.add(item['value'] as String);
        }
        final countries = item['countries'];
        if (countries is List) {
          for (final country in countries) {
            if (country is Map<String, dynamic> && country['value'] is String) {
              countryCodes.add(country['value'] as String);
            }
          }
        }
      }
    }

    final search = _searchController.text.trim().toLowerCase();
    final filteredCountries = countryCodes
        .where((code) {
          final name = _countryDisplayName(code).toLowerCase();
          return code.toLowerCase().contains(search) || name.contains(search);
        })
        .toList()
      ..sort((a, b) => _countryDisplayName(a).compareTo(_countryDisplayName(b)));

    return _CountryScaffold(
      controller: widget.controller,
      title: _t('documentCountry.title'),
      description: _t('documentCountry.description'),
      searchField: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: _t('documentCountry.searchPlaceholder'),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: filteredCountries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final countryCode = filteredCountries[index];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              widget.controller.selectDocumentCountry(countryCode);
              widget.controller.nextStep();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                children: [
                  _CountryFlag(code: countryCode),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _countryDisplayName(countryCode),
                      style: const TextStyle(
                        fontSize: 16,
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

class _CountryScaffold extends StatelessWidget {
  const _CountryScaffold({
    required this.controller,
    required this.title,
    required this.description,
    required this.searchField,
    required this.body,
  });

  final DataleonFlowController controller;
  final String title;
  final String description;
  final Widget searchField;
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
                    const SizedBox(height: 16),
                    searchField,
                    const SizedBox(height: 16),
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

class _CountryFlag extends StatelessWidget {
  const _CountryFlag({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    String iso2;
    final upper = code.toUpperCase();
    if (upper.length == 3 && _DocumentCountryStepPageState._iso3ToIso2.containsKey(upper)) {
      iso2 = _DocumentCountryStepPageState._iso3ToIso2[upper]!;
    } else {
      iso2 = upper.length >= 2 ? upper.substring(0, 2) : upper;
    }
    if (iso2.length != 2) {
      return const SizedBox(width: 24);
    }

    final codePoints = iso2.codeUnits.map((char) => 127397 + char);
    return Text(
      String.fromCharCodes(codePoints),
      style: const TextStyle(fontSize: 20),
    );
  }
}