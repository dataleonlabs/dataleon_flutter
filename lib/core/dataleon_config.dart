class DataleonConfig {
  final String sessionId;
  final String token;
  final String? accountTenant;
  final String? uploadBucket;
  final String appVersion;
  final String? initialLanguage;
  final String customerAssetsBucket;

  /// Délai minimal entre deux images envoyées à l'analyse temps réel (recto,
  /// verso, selfie). Plus court = détection plus rapide, plus de requêtes.
  final Duration captureFrameInterval;

  /// Nombre maximal d'images envoyées pour une étape de capture. Au-delà, la
  /// capture s'arrête et `onResult` reçoit `DataleonStatus.error` avec le code
  /// `capture_max_attempts`. Le serveur ferme de toute façon une étape après
  /// 300 images ou 6 minutes (`capture_too_many_attempts`).
  final int captureMaxAttempts;

  /// Durée maximale de CHAQUE étape caméra (recto, verso, selfie) : 2 minutes
  /// par défaut. Le décompte part quand la caméra de l'étape est prête et
  /// repart de zéro à l'étape suivante, à « Réessayer » et à « Reprendre ».
  /// Écoulé : plus aucune image ni appel API, message dédié à l'écran et
  /// `onResult` reçoit `DataleonStatus.error` avec le code `capture_timeout`.
  final Duration captureTimeout;

  DataleonConfig({
    required this.sessionId,
    required this.token,
    this.accountTenant,
    this.uploadBucket,
    this.appVersion = '2.0.13',
    this.initialLanguage,
    this.customerAssetsBucket = 'yap-assets-customer',
    this.captureFrameInterval = const Duration(milliseconds: 400),
    this.captureMaxAttempts = 300,
    this.captureTimeout = const Duration(minutes: 2),
  }) {
    if (captureFrameInterval.isNegative) {
      throw ArgumentError.value(
          captureFrameInterval, 'captureFrameInterval', 'must not be negative');
    }
    if (captureMaxAttempts < 1) {
      throw ArgumentError.value(
          captureMaxAttempts, 'captureMaxAttempts', 'must be at least 1');
    }
    if (captureTimeout <= Duration.zero) {
      throw ArgumentError.value(
          captureTimeout, 'captureTimeout', 'must be positive');
    }
  }

  String get sessionToken => token;

  String? get accountTenantHeader {
    if (accountTenant == null || accountTenant!.isEmpty) {
      return null;
    }
    return accountTenant;
  }

  void dispose() {}

  /// Base URL for API calls. Hardcoded for security; cannot be overridden.
  String get baseUrl => 'https://inference.eu-west-1.dataleon.ai';
}
