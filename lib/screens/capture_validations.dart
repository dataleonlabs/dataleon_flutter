import '../i18n/dataleon_localizations.dart';

// ---------------------------------------------------------------------------
//  Validations de confirmation (même contrat que getPhaseValidations de la
//  webview identity).
// ---------------------------------------------------------------------------

/// Validation appelée après la confirmation d'une photo.
///
/// [validations] : noms des contrôles renvoyés par l'API (`validations[].name`)
/// qui font échouer l'étape. [errorMessages] : message dédié par contrôle,
/// [errorMessage] servant de repli.
class CaptureValidationDef {
  const CaptureValidationDef({
    required this.path,
    required this.label,
    required this.errorMessage,
    required this.step,
    required this.wait,
    this.validations = const [],
    this.errorMessages = const {},
  });

  final String path;
  final String label;
  final String errorMessage;
  final int step;
  final bool wait;
  final List<String> validations;
  final Map<String, String> errorMessages;
}

/// Échec d'une validation : contrôle en cause ([name], `null` pour un
/// indicateur global) et message à afficher.
class CaptureValidationFailure {
  const CaptureValidationFailure({required this.name, required this.message});

  final String? name;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is CaptureValidationFailure &&
      other.name == name &&
      other.message == message;

  @override
  int get hashCode => Object.hash(name, message);

  @override
  String toString() => 'CaptureValidationFailure($name, $message)';
}

List<CaptureValidationDef> captureValidationDefs({
  required String phase,
  required bool hasBackPhase,
  required String lang,
}) {
  String t(String key) => DataleonLocalizations.t(lang, key);

  if (phase == 'back' || (phase == 'front' && !hasBackPhase)) {
    return [
      CaptureValidationDef(
        path: '/individuals/<id>/verifications/personal-data-checking',
        label: t('validations.personalData'),
        errorMessage: t('validations.personalDataError'),
        validations: const ['FullName', 'Country', 'ExpirationDate', 'Age18'],
        errorMessages: {
          'FullName': t('validations.personalDataErrors.fullName'),
          'Country': t('validations.personalDataErrors.countryMismatch'),
          'ExpirationDate': t('validations.personalDataErrors.expired'),
          'Age18': t('validations.personalDataErrors.age'),
        },
        step: 1,
        wait: true,
      ),
      CaptureValidationDef(
        path: '/individuals/<id>/verifications/blacklist-detection',
        label: t('validations.blacklist'),
        errorMessage: t('validations.blacklistError'),
        validations: const ['Blacklist'],
        step: 1,
        wait: false,
      ),
    ];
  }
  if (phase == 'face') {
    return [
      CaptureValidationDef(
        path: '/individuals/<id>/verifications/similarity-document',
        label: t('validations.faceSimilarity'),
        errorMessage: t('validations.faceSimilarityError'),
        validations: const ['FaceSimilarity'],
        step: 3,
        wait: true,
      ),
      CaptureValidationDef(
        path: '/individuals/<id>/verifications/facial-classification',
        label: t('validations.facialClassification'),
        errorMessage: t('validations.facialClassificationError'),
        validations: const ['Gender'],
        step: 3,
        wait: false,
      ),
    ];
  }
  return const [];
}

bool _hasFailureFlag(Map r) =>
    r['success'] == false || r['status'] == false || r['error'] != null;

/// Échec d'une validation de confirmation, ou `null` si elle passe.
///
/// Deux sources d'échec :
///  1. un indicateur global (`success`/`status` à `false`, `error` présent),
///     sur la réponse ou sur `data` ;
///  2. un contrôle de `validations[]` attendu par [def] et renvoyé avec
///     `validate == false` — c'est ainsi que l'API signale un nom qui ne
///     correspond pas, une pièce expirée, un mineur ou un visage différent.
///     Sans ce second bloc, ces refus n'étaient visibles qu'au back-office.
CaptureValidationFailure? captureValidationFailure(
  Map<String, dynamic>? r,
  CaptureValidationDef def,
) {
  if (r == null) return null;
  final d = r['data'];
  final data = d is Map ? d : null;

  if (_hasFailureFlag(r) || (data != null && _hasFailureFlag(data))) {
    return CaptureValidationFailure(name: null, message: def.errorMessage);
  }

  if (def.validations.isEmpty) return null;

  for (final source in [r['validations'], data?['validations']]) {
    if (source is! List) continue;
    for (final entry in source) {
      if (entry is! Map) continue;
      final name = entry['name'];
      if (name is String &&
          def.validations.contains(name) &&
          entry['validate'] == false) {
        return CaptureValidationFailure(
          name: name,
          message: def.errorMessages[name] ?? def.errorMessage,
        );
      }
    }
  }
  return null;
}
