## 2.0.8

- Documents enchaînés : les documents non obligatoires (`required: false` dans `kycCustomDocuments`) affichent un texte « Ce document est optionnel, cliquez ici pour passer → » juste au-dessus des boutons Importer/Camera. Le lien souligné passe au document suivant de la chaîne (ou à l'écran de succès s'il n'y en a plus) sans téléversement. Les documents sans champ `required`, ou avec `required: true`, restent obligatoires et leur mise en page est inchangée.
- `appVersion` par défaut passe à `2.0.8`.

## 2.0.7

- Captures (`POST /individuals/:id/capture`) : ajout de quatre champs au body de chaque capture (recto, verso, face/selfie) — `request_id`, `account_id`, `workspace_id` (repris de la réponse `/config` : `result.id`, `result.accountId`, `result.workspaceId`) et `mode` dérivé de `dashboardConfiguration.kycIndividualFormType` (`upload → simple`, `image → advanced`, `video → full`, défaut `advanced`). Construction centralisée dans `captureRequestFields` ; les champs ne sont envoyés que s'ils ont une valeur.
- `appVersion` par défaut passe à `2.0.7`.

## 2.0.6

- Écran de chargement : nouveau design (petit loader pendant l'appel `/config/chart`, puis barre de progression qui ne se remplit qu'une seule fois) et messages d'étape affichés immédiatement.
- Outro : suppression de la redirection (nettoyage du code mort `_buildRedirectUri` et de l'import `url_launcher` inutilisé).
- `appVersion` par défaut passe à `2.0.6`.

## 2.0.5

- Écran de chargement : un message s'affiche dès le début (« Chargement de la configuration… ») et change instantanément à chaque étape (`content → request → theme → ready`) ; suppression de tous les délais de 500 ms entre les messages.
- i18n : correction du texte FR `loadingScreen.content` (placeholder cassé).

## 2.0.4

- Caméra : capture des documents (caméra arrière) en 1920x1080 (`ResolutionPreset.veryHigh`) pour une meilleure netteté ; le selfie (caméra avant) reste en 1280x720 (`ResolutionPreset.high`).
- Fix: erreur de syntaxe (`!if`) dans `outro_step_page.dart` qui empêchait la compilation.

## 2.0.3

- Compatibilité Flutter 3.29 (Dart 3.7) : `camera` rétrogradé en `^0.11.0+2`, contraintes `environment` ajustées (`sdk >=3.7.0`, `flutter >=3.29.0`).

## 2.0.2

- Fix: upload des documents chaînés (`other-documents`) — correction du mapping `document_type`/`document_subtype` qui provoquait une erreur 422, alignement sur le flow web.
- Fix: les documents chaînés n'appellent plus `save-document` (réservé aux documents standards), uniquement `other-documents`.
- Fix: migration de l'appel `file_picker` vers l'API statique `FilePicker.pickFiles` (file_picker 11.x).
- Le message d'erreur d'upload affiche désormais le détail technique pour faciliter le diagnostic.
- Ajout de `customerAssetsBucket` dans `DataleonConfig` (bucket d'assets client configurable au lieu d'une valeur en dur).
- `DataleonConfig` valide désormais que `apiBaseUrl` utilise HTTPS.
- Nettoyage des `debugPrint` de diagnostic.

## 2.0.1

- Fix: mise à jour de l'URL API par défaut vers inference.eu-west-1.dataleon.ai.
- Fix: appVersion corrigé à 2.0.0.

## 2.0.0

- Version stable du SDK natif Flutter pour la vérification d'identité Dataleon.
- Support complet du flow KYC : document, selfie, documents chaînés, upload.
- Internationalisation (fr, en, ar, de, it, pt, es, nl) avec conversion automatique des codes ISO3.
- Chargement dynamique du contenu depuis `/contents-configs` (titres, descriptions, markdown).
- Support de `uniformPrincipalColor`, `termsAndConditionsDisabled`, `intro_terms`.
- Bordure de recherche et icône upload adaptées à la couleur du client.
- Corrections : guide caméra toujours vert sur succès, mots-clés toujours verts, helpText card.
- Amélioration de la page outro : priorité au contenu API sur le YAML de configuration.

## 2.0.0-beta-1

- Refonte du SDK autour d'un flow natif piloté par configuration.
- Ajout des nouveaux modules core, flow, i18n, models, screens, services et widgets.
- Mise a jour de la documentation d'integration et de l'exemple Flutter.
- Suppression des credentials reels dans la documentation et l'exemple.
- Ajout d'un rapport d'audit ISO 27001 aligne sur l'etat actuel du SDK.
