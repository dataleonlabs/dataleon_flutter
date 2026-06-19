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
