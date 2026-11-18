// ---------------------------------------------------------------------------
//  Boucle de capture temps réel : cadence, limites et lecture des réponses.
//
//  Logique pure (aucune dépendance caméra) pour être testée isolément. Le
//  contrat suit l'API `POST /individuals/<id>/capture` :
//    - `ok`      → l'image est acceptée, l'étape est validée ;
//    - `pending` → l'image est bonne mais le consensus n'est pas atteint : on
//                  continue ;
//    - `ko`      → CETTE image ne convient pas (carte absente, floue, mauvais
//                  côté…) : `message` guide l'utilisateur et on continue. Seules
//                  les raisons de `kTerminalCaptureReasons` arrêtent l'étape ;
//    - `error`   → arrêt ;
//    - absent, vide ou inconnu → traité comme `pending` : on continue. Ce
//                  n'est jamais une raison d'arrêter ; le délai de l'étape et
//                  `captureMaxAttempts` bornent la boucle.
// ---------------------------------------------------------------------------

/// Raisons d'un `ko` qui ferment l'étape côté serveur : renvoyer d'autres
/// images ne servirait à rien (budget d'images ou de durée épuisé).
const Set<String> kTerminalCaptureReasons = {'too_many_attempts'};

/// Codes d'erreur remontés à l'intégration (`DataleonResult.error`) quand la
/// capture s'arrête sans succès.
class CaptureErrorCode {
  CaptureErrorCode._();

  /// Le serveur a fermé l'étape (`ko` + `too_many_attempts`).
  static const tooManyAttempts = 'capture_too_many_attempts';

  /// `captureMaxAttempts` images envoyées sans succès.
  static const maxAttempts = 'capture_max_attempts';

  /// `captureTimeout` écoulé sans succès.
  static const timeout = 'capture_timeout';

  /// Réponse `status: "error"` de l'API.
  static const apiError = 'capture_api_error';

  /// Erreurs réseau / HTTP à la suite.
  static const networkError = 'capture_network_error';
}

/// Réglages de la boucle (repris de `DataleonConfig`).
class CaptureLoopSettings {
  const CaptureLoopSettings({
    this.minFrameInterval = const Duration(milliseconds: 400),
    this.maxAttempts = 300,
    this.timeout = const Duration(minutes: 2),
    this.maxConsecutiveErrors = 3,
  });

  /// Délai minimal entre le début de deux envois.
  final Duration minFrameInterval;

  /// Nombre maximal d'images envoyées pour une étape (recto, verso, selfie).
  final int maxAttempts;

  /// Durée maximale d'UNE étape caméra (recto, verso ou selfie). Le décompte
  /// commence quand la caméra de l'étape est prête et repart de zéro à chaque
  /// étape, à « Réessayer » et à « Reprendre » : le temps passé hors caméra
  /// (confirmation, autres écrans) ne compte pas.
  final Duration timeout;

  /// Erreurs réseau / HTTP tolérées à la suite.
  final int maxConsecutiveErrors;
}

/// Ce que la boucle doit faire après une réponse.
enum CaptureFrameAction {
  /// Image acceptée : arrêter la boucle et passer à la confirmation.
  accept,

  /// Continuer avec l'image suivante.
  retry,

  /// Arrêter la boucle et signaler l'erreur.
  stop,
}

class CaptureFrameOutcome {
  const CaptureFrameOutcome({
    required this.action,
    this.status,
    this.message,
    this.reason,
    this.errorCode,
    this.invalid = false,
  });

  final CaptureFrameAction action;

  /// Statut renvoyé par l'API, normalisé (minuscules, sans espaces).
  final String? status;

  /// Message à afficher (tel que renvoyé par l'API).
  final String? message;

  /// `details.reason` renvoyé par l'API.
  final String? reason;

  /// Code d'erreur quand [action] vaut [CaptureFrameAction.stop].
  final String? errorCode;

  /// Statut absent, vide ou inconnu, lu comme `pending` ([status] vaut alors
  /// `pending`). Informatif : la boucle continue normalement.
  final bool invalid;
}

/// Lit une réponse de l'API de capture temps réel.
CaptureFrameOutcome classifyCaptureResponse(Map<String, dynamic>? data) {
  final rawStatus = data?['status'];
  final status = rawStatus is String ? rawStatus.trim().toLowerCase() : null;
  final rawMessage = data?['message'];
  final message =
      rawMessage is String && rawMessage.trim().isNotEmpty ? rawMessage : null;
  final details = data?['details'];
  final rawReason = details is Map ? details['reason'] : null;
  final reason = rawReason is String ? rawReason : null;

  switch (status) {
    case 'ok':
      return CaptureFrameOutcome(
        action: CaptureFrameAction.accept,
        status: status,
        message: message,
        reason: reason,
      );
    case 'pending':
      return CaptureFrameOutcome(
        action: CaptureFrameAction.retry,
        status: status,
        message: message,
        reason: reason,
      );
    case 'ko':
      if (reason != null && kTerminalCaptureReasons.contains(reason)) {
        return CaptureFrameOutcome(
          action: CaptureFrameAction.stop,
          status: status,
          message: message,
          reason: reason,
          errorCode: CaptureErrorCode.tooManyAttempts,
        );
      }
      return CaptureFrameOutcome(
        action: CaptureFrameAction.retry,
        status: status,
        message: message,
        reason: reason,
      );
    case 'error':
      return CaptureFrameOutcome(
        action: CaptureFrameAction.stop,
        status: status,
        message: message,
        reason: reason,
        errorCode: CaptureErrorCode.apiError,
      );
    default:
      // Statut vide, absent ou inconnu : on le lit comme `pending`.
      return CaptureFrameOutcome(
        action: CaptureFrameAction.retry,
        status: 'pending',
        message: message,
        reason: reason,
        invalid: true,
      );
  }
}

/// Compte les envois d'une étape et décide quand s'arrêter.
class CaptureLoopTracker {
  CaptureLoopTracker(this.settings, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    reset();
  }

  final CaptureLoopSettings settings;
  final DateTime Function() _clock;

  DateTime? _startedAt;
  DateTime? _lastSendAt;
  int _attempts = 0;
  int _consecutiveErrors = 0;

  int get attempts => _attempts;
  int get consecutiveErrors => _consecutiveErrors;

  /// Nouvelle étape, ou nouvel essai après une erreur. Le décompte est à
  /// l'arrêt jusqu'à [start].
  void reset() {
    _startedAt = null;
    _lastSendAt = null;
    _attempts = 0;
    _consecutiveErrors = 0;
  }

  /// Lance le décompte de l'étape (caméra prête). Sans effet s'il court déjà.
  void start() {
    _startedAt ??= _clock();
  }

  bool get started => _startedAt != null;

  /// Temps restant avant [CaptureErrorCode.timeout] ; durée entière tant que
  /// le décompte n'a pas commencé.
  Duration get remaining {
    final startedAt = _startedAt;
    if (startedAt == null) return settings.timeout;
    final left = settings.timeout - _clock().difference(startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  /// Code d'erreur si une limite de l'intégration est atteinte, sinon null.
  /// À appeler avant chaque envoi.
  String? limitReached() {
    if (_attempts >= settings.maxAttempts) return CaptureErrorCode.maxAttempts;
    if (started && remaining == Duration.zero) return CaptureErrorCode.timeout;
    return null;
  }

  /// Temps à attendre avant le prochain envoi pour respecter la cadence.
  Duration delayBeforeNextSend() {
    final last = _lastSendAt;
    if (last == null) return Duration.zero;
    final remaining = settings.minFrameInterval - _clock().difference(last);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Vrai si un envoi peut partir maintenant (cadence respectée).
  bool get canSendNow => delayBeforeNextSend() == Duration.zero;

  /// Un envoi part (lance le décompte s'il ne court pas encore).
  void recordSend() {
    start();
    _attempts += 1;
    _lastSendAt = _clock();
  }

  /// Enregistre une réponse lue ; renvoie un code d'erreur si la boucle doit
  /// s'arrêter, sinon null.
  String? recordOutcome(CaptureFrameOutcome outcome) {
    if (outcome.action == CaptureFrameAction.stop) {
      return outcome.errorCode ?? CaptureErrorCode.apiError;
    }
    // Le serveur a répondu (même sans statut) : la série d'erreurs réseau
    // s'interrompt.
    _consecutiveErrors = 0;
    return null;
  }

  /// Enregistre une erreur réseau / HTTP ; renvoie un code d'erreur si la
  /// boucle doit s'arrêter, sinon null.
  String? recordNetworkError() {
    _consecutiveErrors += 1;
    return _consecutiveErrors >= settings.maxConsecutiveErrors
        ? CaptureErrorCode.networkError
        : null;
  }
}
