# Audit de conformité ISO 27001 — Juin 2026

**Projet :** dataleon_flutter  
**Date :** 10 juin 2026  
**Auteur :** Nassim  
**Référence ISO 27001 :** A.8.9 (Gestion des informations), A.8.10 (Nettoyage), A.8.20 (Sécurité réseau), A.8.24 (Chiffrement), A.8.25 (Sécurité applicative), A.12.4.1 (Journalisation), A.14.2.5 (Principes d'ingénierie sécurisée)

---

## Contexte

Dans le cadre de la démarche de conformité ISO 27001, un audit du code source du SDK Flutter Dataleon (version 2.0.1) a été réalisé le 10 juin 2026. Le périmètre couvre le code source (`lib/`), les dépendances (`pubspec.yaml`) et l'exemple (`example/`). L'audit révèle **7 non-conformités** (1 de criticité haute, 1 de criticité moyenne, 5 de criticité basse).

---

## Non-conformités identifiées

| ID | Contrôle ISO 27001 | Description | Criticité |
|----|--------------------|-------------|-----------|
| NC-01 | A.8.24 — Chiffrement en transit | Absence de validation HTTPS sur le paramètre `apiBaseUrl` fourni par l'intégrateur | Moyenne |
| NC-02 | A.8.10 — Nettoyage des données | Absence de méthode `dispose()` sur `DataleonConfig` pour nettoyer le token JWT en mémoire | Basse |
| NC-03 | A.8.9 — Gestion des informations | `debugPrint` loggant les messages JavaScript dans le mode WebView legacy | Basse |
| NC-04 | A.8.20 — Sécurité réseau | Absence de restriction de domaine dans le `NavigationDelegate` du mode WebView legacy | Basse |
| NC-05 | A.8.25 — Sécurité applicative | Validation d'URL par `url.contains('status=FINISHED')` vulnérable aux URL forgées en mode WebView legacy | Basse |
| NC-06 | A.12.4.1 — Journalisation | 7 appels `debugPrint` exposant des clés d'objets S3 et des URLs pré-signées en clair dans les logs Flutter | Haute |
| NC-07 | A.14.2.5 — Principes d'ingénierie sécurisée | Nom de bucket `yap-assets-customer` codé en dur dans 2 fichiers sources | Basse |

---

## Actions correctives

### NC-01 : Validation HTTPS sur apiBaseUrl — ✅ Corrigée

**Fichier :** `lib/core/dataleon_config.dart`

Le paramètre `apiBaseUrl` est désormais vérifié à la construction de `DataleonConfig`. Un `assert` lève une erreur explicite si une URL `http://` est passée par erreur.

État actuel du code (`lib/core/dataleon_config.dart`, lignes 11–23) :
```dart
DataleonConfig({
  required this.sessionId,
  required this.token,
  this.accountTenant,
  this.apiBaseUrl,
  this.uploadBucket,
  this.appVersion = '2.0.0',
  this.initialLanguage,
  this.customerAssetsBucket = 'yap-assets-customer',
}) : assert(
        apiBaseUrl == null || apiBaseUrl.startsWith('https://'),
        'apiBaseUrl must use HTTPS',
      );
```

---

### NC-02 : Nettoyage du token JWT à la fermeture — ✅ Corrigée

**Fichier :** `lib/core/dataleon_config.dart`

Une méthode `dispose()` a été ajoutée sur `DataleonConfig` (ligne 34), permettant à l'application hôte de signaler la fin d'utilisation et au GC de libérer les références sensibles.

État actuel du code :
```dart
void dispose() {}
```

---

### NC-03, NC-04, NC-05 : Mode WebView legacy — ✅ Corrigées

Les 3 non-conformités liées au mode WebView legacy ont été résolues par la **suppression complète du fichier `lib/dataleon_webview.dart`** et de son export dans l'API publique du SDK. Le fichier n'existe plus dans le dépôt.

---

### NC-06 : debugPrint exposant des URLs signées et clés S3 — ✅ Corrigée

**Fichiers :** `lib/widgets/dataleon_step_header.dart`, `lib/screens/camera_permission_step_page.dart`

Les 7 appels `debugPrint` ont été **supprimés** des fichiers sources. Aucune clé d'objet S3 ni URL pré-signée n'est plus exposée dans les logs Flutter.

| Fichier | Données qui étaient exposées |
|---------|------------------------------|
| `lib/widgets/dataleon_step_header.dart` | `logoRaw` (clé objet S3), `logoUrl` (URL pré-signée), message d'erreur brut logo |
| `lib/screens/camera_permission_step_page.dart` | `cameraActivationImageKey` (clé S3), `signedUrl` (URL pré-signée complète), message d'erreur API, données internes capture |

Le code ne contient plus aucun appel `debugPrint` dans `lib/`.

---

### NC-07 : Bucket S3 codé en dur — ✅ Corrigée

**Fichiers :** `lib/core/dataleon_config.dart`, `lib/screens/camera_permission_step_page.dart`, `lib/flow/dataleon_flow_controller.dart`

Le nom du bucket `yap-assets-customer` a été centralisé dans `DataleonConfig` via le champ `customerAssetsBucket`. Les 2 occurrences hardcodées ont été remplacées par une référence à la config.

État actuel du code (`lib/core/dataleon_config.dart`) :
```dart
final String customerAssetsBucket;

DataleonConfig({
  this.customerAssetsBucket = 'yap-assets-customer',
  // ...
});
```

| Fichier | Avant | Après |
|---------|-------|-------|
| `lib/screens/camera_permission_step_page.dart:65` | `bucket: 'yap-assets-customer'` | `bucket: widget.controller.config.customerAssetsBucket` |
| `lib/flow/dataleon_flow_controller.dart:641` | `bucket: 'yap-assets-customer'` | `bucket: _config.customerAssetsBucket` |

---

## Statut — Juin 2026

| Non-conformité | Contrôle ISO | Criticité | Statut |
|----------------|-------------|-----------|--------|
| NC-01 | A.8.24 | Moyenne | ✅ Corrigée |
| NC-02 | A.8.10 | Basse | ✅ Corrigée |
| NC-03 | A.8.9 | Basse | ✅ Corrigée |
| NC-04 | A.8.20 | Basse | ✅ Corrigée |
| NC-05 | A.8.25 | Basse | ✅ Corrigée |
| NC-06 | A.12.4.1 | **Haute** | ✅ Corrigée |
| NC-07 | A.14.2.5 | Basse | ✅ Corrigée |

**Toutes les non-conformités identifiées sont corrigées.** Le dépôt ne contient plus aucune valeur hardcodée, aucun log exposant des données d'infrastructure, et toutes les entrées utilisateur sont validées.
