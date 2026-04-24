# Audit de conformité ISO 27001:2022

**Projet** : Dataleon Flutter SDK  
**Version** : 2.0.0-beta  
**Date** : 24 avril 2026  
**Périmètre** : Code source (`lib/`), dépendances (`pubspec.yaml`), exemple (`example/`)

---

## Résumé exécutif

| Résultat | Nombre |
|----------|--------|
| ✅ Conforme | 15 |
| ⚠️ Non conforme (moyen) | 4 |
| ❌ Non conforme (critique) | 0 |
| ℹ️ Bas / informatif | 3 |

---

## Contrôles conformes

### ✅ A.8.24 — Chiffrement en transit (HTTPS par défaut)

L'URL de base par défaut utilise HTTPS (`https://inference.eu-west-1.dataleon.ai`). Toutes les communications API passent par TLS.

**Fichier** : `lib/core/dataleon_config.dart`

---

### ✅ A.8.3 — Authentification par token JWT (Bearer)

Le SDK utilise un flux d'authentification sécurisé :
1. L'API key est utilisée **une seule fois** pour obtenir un JWT via `GET /token/{xxxxxx}`
2. Tous les appels suivants utilisent `Authorization: Bearer <JWT>`
3. Le JWT est stocké uniquement en mémoire (pas de persistance locale)

**Fichier** : `lib/services/dataleon_api_service.dart`

---

### ✅ A.8.10 — Nettoyage des données en mémoire

- La méthode `reset()` du contrôleur efface les fichiers uploadés, les captures et l'état de session
- Les bytes des photos sont nettoyés après confirmation et upload
- `_capturedBytes` est remis à `null` lors de `_handleRetake()`

**Fichier** : `lib/flow/dataleon_flow_controller.dart`, `lib/screens/camera_capture_step_page.dart`

---

### ✅ A.8.10 — Aucun stockage local de données sensibles

Aucune donnée sensible (photos, tokens, API keys) n'est persistée localement. Pas de SQLite, SharedPreferences, fichiers temporaires ou cache disque. Toutes les données sensibles restent en mémoire et disparaissent à la fermeture de l'application.

---

### ✅ A.8.9 — Messages d'erreur génériques

Les exceptions API (`DataleonApiException`) ne contiennent que le code HTTP et un message générique. Aucune fuite de stack trace, body de réponse serveur, ou détails internes vers l'utilisateur final.

**Fichier** : `lib/services/dataleon_api_service.dart`

---

### ✅ A.8.9 — Pas de log de credentials

Aucun `print()` ou `debugPrint()` ne log les tokens JWT, API keys, ou données utilisateur dans le flow natif. Les credentials ne sont jamais exposées dans les logs.

**Fichier** : Tout le SDK (flow natif)

---

### ✅ A.8.25 — Injection JavaScript sécurisée (WebView legacy)

Le code JavaScript injecté dans la WebView est entièrement statique (hardcodé). Aucune interpolation de variable utilisateur n'est présente, éliminant le risque d'injection XSS.

**Fichier** : `lib/dataleon_webview.dart`

---

### ✅ A.8.3 — Séparation token / identifiant de session

Le JWT est utilisé exclusivement dans les headers HTTP (`Authorization: Bearer`). Les URLs et corps de requêtes utilisent le `sessionId` (UUID), empêchant la fuite du token dans les logs serveur, proxies ou historique de navigation.

**Fichier** : `lib/services/dataleon_api_service.dart`

---

### ✅ A.8.8 — Dépendances officielles uniquement

Toutes les dépendances sont des packages officiels Flutter/Dart, maintenus par Google ou la communauté Flutter :

| Package | Source | Statut |
|---------|--------|--------|
| `camera` | Flutter team | ✅ Officiel |
| `http` | Dart team | ✅ Officiel |
| `permission_handler` | Baseflow | ✅ Populaire (10k+ likes) |
| `url_launcher` | Flutter team | ✅ Officiel |
| `yaml` | Dart team | ✅ Officiel |

Le package `webview_flutter` a été supprimé pour réduire la surface d'attaque.

---

### ✅ A.8.8 — Nombre minimal de dépendances

Le SDK n'utilise que 5 packages externes, le strict minimum nécessaire :
- `camera` — capture de documents et selfie
- `http` — appels API
- `permission_handler` — permission caméra
- `url_launcher` — liens CGU / redirection
- `yaml` — parsing configuration dashboard

---

### ✅ A.5.34 — Consentement et transparence

L'écran d'accueil affiche les liens vers les CGU et la politique de confidentialité avant toute capture de données biométriques. L'utilisateur doit interagir pour continuer.

**Fichier** : `lib/screens/welcome_step_page.dart`

---

### ✅ A.8.5 — Validation des entrées

Les réponses JSON de l'API sont parsées avec des valeurs par défaut sûres (`?? ''`, `?? 'unknown'`). Les valeurs nulles ne provoquent pas de crash.

**Fichier** : `lib/models/session.dart`

---

### ✅ A.8.3 — Fermeture du client HTTP

Le client HTTP est correctement fermé dans la méthode `dispose()`, libérant les ressources et empêchant les fuites de connexion.

**Fichier** : `lib/services/dataleon_api_service.dart`

---

### ✅ A.8.25 — Gestion d'erreur sans fuite d'information

Les erreurs sont capturées dans le contrôleur et transmises au résultat SDK sous forme de messages génériques. Les erreurs 403 sont distinguées (session déjà traitée) des autres erreurs (problème technique) sans exposer de détails internes.

**Fichier** : `lib/flow/dataleon_flow_controller.dart`

---

### ✅ A.8.9 — Exemple et documentation sans credentials réels

L'exemple public et la documentation n'exposent plus de `sessionId` ni d'`apiKey` réels. Les valeurs sont désormais remplacées par des placeholders explicites, ce qui supprime le risque d'exposition accidentelle de credentials dans le dépôt.

**Fichier** : `example/lib/main.dart`, `README.md`

---

## Contrôles non conformes

### ⚠️ SEC-02 — A.8.24 — Pas de validation HTTPS sur apiBaseUrl (MOYEN)

**Fichier** : `lib/core/dataleon_config.dart`

Le paramètre `apiBaseUrl` est fourni par le développeur intégrateur. Aucune vérification ne garantit qu'il utilise HTTPS. Un développeur pourrait passer `http://...` par erreur, exposant toutes les communications en clair.

**Recommandation** : Ajouter une assertion :
```dart
assert(apiBaseUrl == null || apiBaseUrl!.startsWith('https://'),
       'apiBaseUrl must use HTTPS');
```

---

### ⚠️ SEC-03 — A.8.10 — Pas de nettoyage des credentials au dispose (MOYEN)

**Fichier** : `lib/core/dataleon_config.dart`

L'API key et le JWT token restent en mémoire aussi longtemps que l'objet `DataleonConfig` existe. Même après la fermeture du SDK, si l'objet config est conservé par l'application hôte, les credentials restent accessibles.

**Recommandation** : Ajouter une méthode `dispose()` :
```dart
void dispose() {
  _sessionToken = null;
}
```

---

### ⚠️ SEC-04 — A.8.24 — Pas de certificate pinning (MOYEN)

**Fichier** : `lib/services/dataleon_api_service.dart`

Le SDK utilise `package:http` sans configuration SSL/TLS personnalisée. Pour un SDK KYC manipulant des documents d'identité et données biométriques, l'absence de certificate pinning expose à des attaques MITM sur réseaux compromis.

**Recommandation** : Envisager l'utilisation d'un `SecurityContext` personnalisé ou d'un package de certificate pinning pour les appels critiques (upload de photos, envoi de données biométriques).

---

### ⚠️ SEC-05 — A.5.34 — Photos biométriques sans chiffrement applicatif (MOYEN)

**Fichier** : `lib/screens/camera_capture_step_page.dart`

Les photos de documents d'identité et selfies sont encodées en base64 et envoyées via HTTPS. Le chiffrement de transport (TLS) est la seule protection. Pour des données PII biométriques de cette sensibilité, un chiffrement end-to-end au niveau applicatif (ex: AES) serait souhaitable.

**Recommandation** : Chiffrer les payloads contenant des images avec une clé publique serveur avant envoi.

---

### ℹ️ SEC-06 — A.8.9 — debugPrint dans le mode WebView legacy (BAS)

**Fichier** : `lib/dataleon_webview.dart`

Le mode WebView legacy contient un `debugPrint` qui log les messages JavaScript. Ce mode n'est plus utilisé dans le flow natif et les fichiers legacy ne sont plus exportés.

---

### ℹ️ SEC-07 — A.8.20 — Pas de restriction de domaine dans la WebView legacy (BAS)

**Fichier** : `lib/dataleon_webview.dart`

Le `NavigationDelegate` de la WebView legacy autorise toute URL sans filtrage de domaine. Impact limité car le mode WebView n'est plus exposé dans l'API publique du SDK.

---

### ℹ️ SEC-08 — A.8.25 — Validation d'URL par contains() dans le mode legacy (BAS)

**Fichier** : `lib/dataleon_webview.dart`

La détection de statut dans la WebView legacy utilise `url.contains('status=FINISHED')`, ce qui pourrait produire des faux positifs avec des URLs forgées. Impact limité car ce mode n'est plus utilisé.

---

## Plan de remédiation

| Priorité | ID | Action | Effort |
|----------|----|--------|--------|
| 🟡 P2 | SEC-02 | Ajouter validation HTTPS sur apiBaseUrl | Faible |
| 🟡 P2 | SEC-03 | Ajouter méthode dispose() sur DataleonConfig | Faible |
| 🟡 P3 | SEC-04 | Evaluer l'implémentation du certificate pinning | Moyen |
| 🟡 P3 | SEC-05 | Evaluer le chiffrement applicatif des images | Moyen |
| 🟢 P4 | SEC-06/07/08 | Supprimer les fichiers WebView legacy | Faible |

---

## Conclusion

Le SDK Dataleon Flutter présente un bon niveau de sécurité de base avec **15 contrôles conformes** sur les 22 évalués. Le point critique précédemment relevé sur les credentials exposés dans l'exemple a été corrigé. Les écarts restants concernent surtout des mesures défensives supplémentaires autour de `apiBaseUrl`, du cycle de vie des credentials en mémoire et du durcissement réseau. Les vulnérabilités identifiées dans le mode WebView legacy restent à faible impact car ce mode n'est plus exposé dans l'API publique.
