

# dataleon_flutter

[![pub package](https://img.shields.io/pub/v/dataleon_flutter.svg)](https://pub.dev/packages/dataleon_flutter)

Flutter SDK Dataleon pour intégrer un parcours de vérification d'identité dans une application Flutter existante.

Le SDK fournit trois modes d'intégration :

- un écran plein format prêt à pousser dans votre navigation
- une bottom sheet modale pour garder votre app visible en arrière-plan
- une vue embarquable pour l'insérer dans un écran Flutter déjà existant

## Ce que le package expose

L'intégration actuelle repose principalement sur ces points d'entrée :

- `DataleonConfig` pour déclarer la session et la configuration API
- `DataleonFlowScreen` pour ouvrir le flow en plein écran
- `DataleonBottomSheet.show(...)` pour ouvrir le flow dans une modale
- `DataleonFlowView` pour intégrer le flow dans votre propre page
- `DataleonResult` et `DataleonStatus` pour suivre l'issue du parcours

## Installation

Ajoutez la dépendance dans votre `pubspec.yaml` :

```yaml
dependencies:
  dataleon_flutter: ^2.0.13
```

Puis récupérez les dépendances :

```sh
flutter pub get
```

## Intégration dans un projet Flutter existant

Si vous avez déjà une application Flutter avec son routing, son thème, son système d'authentification et ses propres écrans, l'idée est simple : vous créez une `DataleonConfig`, puis vous ouvrez le flow Dataleon depuis un bouton, une route ou une action métier existante.

### 1. Préparer les permissions mobiles

Le SDK utilise la caméra. Il faut donc déclarer les permissions dans votre app hôte.

#### Android

Dans `android/app/src/main/AndroidManifest.xml`, ajoutez dans la balise `manifest` :

```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

Selon votre cas d'usage produit, vous pouvez aussi déclarer l'accès aux photos ou au micro si votre application l'exige déjà, mais pour le flow document/caméra exposé par le SDK, la caméra est le prérequis principal.

#### iOS

Dans `ios/Runner/Info.plist`, ajoutez au minimum :

```xml
<key>NSCameraUsageDescription</key>
<string>L'accès à la caméra est nécessaire pour la vérification d'identité.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>L'accès à la galerie photo peut être nécessaire pour sélectionner des documents.</string>
```

### 2. Récupérer les données Dataleon côté application

Le SDK attend une configuration `DataleonConfig` :

- `sessionId` : identifiant de session Dataleon
- `token` : JWT Dataleon déjà généré côté backend client

Exemple :

```dart
final config = DataleonConfig(
  sessionId: 'YOUR_SESSION_ID',
  token: 'YOUR_JWT_TOKEN',
);
```

#### Réglages de la capture temps réel (optionnels)

Pendant la capture (recto, verso, selfie), le SDK lit le flux vidéo de la caméra — sans son d'obturateur — et envoie des images à l'analyse jusqu'à ce que le document soit validé. Trois réglages encadrent cette boucle :

| Paramètre | Défaut | Rôle |
|---|---|---|
| `captureFrameInterval` | `Duration(milliseconds: 400)` | délai minimal entre deux images envoyées |
| `captureMaxAttempts` | `300` | nombre maximal d'images envoyées pour une étape |
| `captureTimeout` | `Duration(minutes: 2)` | durée maximale de **chaque** étape caméra (recto, verso, selfie) |

```dart
final config = DataleonConfig(
  sessionId: 'YOUR_SESSION_ID',
  token: 'YOUR_JWT_TOKEN',
  // Contrôle bref et répétable (ex. avant chaque course) :
  captureMaxAttempts: 60,
  captureTimeout: const Duration(seconds: 45),
);
```

Le délai `captureTimeout` est décompté dès que la caméra de l'étape est prête et repart de zéro à chaque étape (recto validé → 2 minutes pour le verso, etc.), à « Réessayer » et à « Reprendre » ; le temps passé hors caméra (écran de confirmation, autres écrans) ne compte pas. À échéance, l'envoi des images et les appels API s'arrêtent aussitôt, même si une analyse est en cours, et l'écran affiche un message propre à l'étape, par exemple : « Le temps imparti pour capturer le recto de votre document est écoulé. Vérifiez qu'il est bien éclairé et entièrement visible dans le cadre, puis relancez la capture. »

Le serveur ferme de toute façon une étape après 300 images ou 6 minutes. Quand une limite est atteinte, la capture s'arrête, l'utilisateur voit un message avec un bouton « Réessayer », et `onResult` reçoit `DataleonStatus.error` (voir [Erreurs de capture](#erreurs-de-capture)).

En pratique, dans un projet existant, vous allez rarement hardcoder ces valeurs dans l'UI. Le plus propre est de récupérer le `sessionId` et le `token` depuis votre backend ou votre couche de service applicative avant d'ouvrir le flow. Le SDK ne génère plus de token côté frontend.

### 3. Ajouter un point d'entrée dans votre écran existant

Exemple minimal dans une page déjà présente dans votre app :

```dart
import 'package:dataleon_flutter/dataleon_flutter.dart';
import 'package:flutter/material.dart';

class KycEntryPage extends StatefulWidget {
  const KycEntryPage({super.key});

  @override
  State<KycEntryPage> createState() => _KycEntryPageState();
}

class _KycEntryPageState extends State<KycEntryPage> {
  String _lastStatus = 'Aucune vérification lancée';

  final DataleonConfig _config = DataleonConfig(
    sessionId: 'YOUR_SESSION_ID',
    token: 'YOUR_JWT_TOKEN',
  );

  void _handleResult(DataleonResult result) {
    setState(() {
      _lastStatus = result.status.value;
    });

    if (result.status == DataleonStatus.finished ||
        result.status == DataleonStatus.canceled) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _openFullScreen,
              child: const Text('Lancer la vérification'),
            ),
            const SizedBox(height: 16),
            Text('Dernier statut : $_lastStatus'),
          ],
        ),
      ),
    );
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DataleonFlowScreen(
          config: _config,
          title: 'Vérification d\'identité',
          onResult: _handleResult,
        ),
      ),
    );
  }
}
```

## Trois façons de l'intégrer dans une app déjà existante

### Option 1. Ouvrir le flow dans une route plein écran

C'est l'option la plus simple si votre app possède déjà un `Navigator` ou un routeur Flutter standard.

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => DataleonFlowScreen(
      config: config,
      title: 'Identity Verification',
      onResult: (result) {
        if (result.status == DataleonStatus.finished) {
          // vérification terminée
        }

        if (result.status == DataleonStatus.failed ||
            result.status == DataleonStatus.error) {
          // afficher une erreur métier ou analytics
        }
      },
    ),
  ),
);
```

Quand choisir cette option :

- si vous voulez un parcours séparé du reste de l'application
- si votre équipe produit veut une expérience immersive
- si vous avez déjà une convention de navigation par écrans dédiés

### Option 2. Ouvrir le flow dans une bottom sheet

Pratique si vous souhaitez garder le contexte de l'écran courant visible derrière la vérification.

```dart
await DataleonBottomSheet.show(
  context: context,
  config: config,
  heightFactor: 0.9,
  onResult: (result) {
    if (result.status == DataleonStatus.finished) {
      // succès
    }
  },
);
```

Quand choisir cette option :

- si la vérification est une étape secondaire dans un tunnel existant
- si vous utilisez déjà beaucoup de modales ou de bottom sheets dans votre app
- si vous voulez refermer proprement le SDK sans changer la stack de navigation principale

### Option 3. Embarquer le flow dans votre propre écran

Si vous avez déjà une page maison avec votre header, votre analytics, vos composants ou un layout complexe, utilisez `DataleonFlowView`.

```dart
class ExistingCheckoutLikeScreen extends StatelessWidget {
  const ExistingCheckoutLikeScreen({super.key, required this.config});

  final DataleonConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon écran existant')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Bloc applicatif existant au-dessus du flow'),
          ),
          Expanded(
            child: DataleonFlowView(
              config: config,
              onResult: (result) {
                // brancher votre logique métier
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

Quand choisir cette option :

- si vous devez intégrer Dataleon dans une page déjà dessinée par votre design system
- si vous voulez composer le flow avec vos propres widgets Flutter
- si vous devez contrôler précisément le conteneur, les marges ou le comportement autour du SDK

## Gérer le résultat du parcours

Le callback `onResult` renvoie un `DataleonResult` contenant :

- `status` : une valeur de l'enum `DataleonStatus`
- `error` : un message optionnel en cas d'échec

Les statuts principaux sont :

- `DataleonStatus.started`
- `DataleonStatus.finished`
- `DataleonStatus.canceled`
- `DataleonStatus.failed`
- `DataleonStatus.error`
- `DataleonStatus.aborted`

Exemple de gestion propre dans une app existante :

```dart
void handleDataleonResult(BuildContext context, DataleonResult result) {
  switch (result.status) {
    case DataleonStatus.finished:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérification terminée')),
      );
      break;

    case DataleonStatus.canceled:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérification annulée')),
      );
      break;

    case DataleonStatus.failed:
    case DataleonStatus.error:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Une erreur est survenue')),
      );
      break;

    default:
      break;
  }
}
```

### Erreurs de capture

Quand la capture temps réel s'arrête sans succès, `onResult` reçoit `DataleonStatus.error` et `result.error` vaut l'un de ces codes. Le parcours reste ouvert : l'utilisateur peut relancer la capture avec « Réessayer » (une nouvelle erreur sera signalée à nouveau), ou fermer le parcours.

| Code | Cause |
|---|---|
| `capture_timeout` | `captureTimeout` (2 min par défaut) écoulé sur une étape caméra sans image validée |
| `capture_max_attempts` | `captureMaxAttempts` images envoyées sans succès |
| `capture_too_many_attempts` | le serveur a fermé l'étape (300 images ou 6 minutes) |
| `capture_api_error` | l'API a répondu `status: "error"` (requête invalide, jeton refusé, panne serveur) : arrêt immédiat, sans nouvel essai |
| `capture_network_error` | 3 erreurs réseau ou HTTP de suite (réponse HTTP sans corps `status: "error"`) |

Une image refusée (`ko` : carte absente, floue, hors du cadre…) n'est pas une erreur : son message guide l'utilisateur et la capture continue.

L'API répond toujours l'un de ces quatre statuts : `pending` (image correcte, vérification en cours), `ok` (étape validée), `ko` (image refusée, on continue) ou `error` (arrêt). Un statut vide, absent ou inconnu est lu comme `pending` : la capture continue, bornée par `captureTimeout` et `captureMaxAttempts`.

## Adapter le flow à votre application

Le SDK permet aussi de personnaliser le rendu de certaines étapes via `stepBuilders` et, si nécessaire, via un `DataleonFlowController` fourni par votre code.

Exemple :

```dart
DataleonFlowScreen(
  config: config,
  stepBuilders: {
    DataleonFlowStep.review: (context, controller, step) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: controller.nextStep,
            child: const Text('Valider ma revue personnalisée'),
          ),
        ),
      );
    },
  },
)
```

Cela permet d'intégrer Dataleon dans un produit existant sans forcer un habillage unique sur toute votre application.

## Recommandations d'intégration en production

- créez la `DataleonConfig` dans une couche service ou un view model plutôt que directement dans le widget si les données viennent du backend
- logguez les statuts `finished`, `failed` et `canceled` dans votre analytics produit
- traitez séparément les erreurs techniques et les abandons utilisateur
- testez les permissions caméra sur Android et iOS avant la mise en production
- prévoyez une UX claire de reprise si l'utilisateur ferme ou annule le flow

## Exemple du dépôt

Le projet d'exemple montre deux intégrations typiques dans une app cliente Flutter :

- ouverture en plein écran avec `DataleonFlowScreen`
- ouverture en modale avec `DataleonBottomSheet.show(...)`

## Dépendances principales

- `camera`
- `http`
- `permission_handler`
- `url_launcher`
- `yaml`

## License

MIT
