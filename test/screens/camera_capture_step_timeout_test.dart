import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dataleon_flutter/core/dataleon_config.dart';
import 'package:dataleon_flutter/core/dataleon_status.dart';
import 'package:dataleon_flutter/flow/dataleon_flow_controller.dart';
import 'package:dataleon_flutter/screens/camera_capture_step_page.dart';
import 'package:dataleon_flutter/services/dataleon_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

/// Vraie image JPEG (affichée à l'écran de confirmation).
final Uint8List _jpeg = img.encodeJpg(img.Image(width: 16, height: 16));

/// Caméra factice : initialisation immédiate et flux d'images JPEG toutes les
/// 100 ms tant que l'écran l'écoute (comme le flux vidéo d'un téléphone).
class _FakeCameraPlatform extends CameraPlatform {
  int streamsStarted = 0;
  int framesDelivered = 0;
  bool streaming = false;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
        CameraDescription(
            name: 'back', lensDirection: CameraLensDirection.back, sensorOrientation: 90),
        CameraDescription(
            name: 'front', lensDirection: CameraLensDirection.front, sensorOrientation: 270),
      ];

  @override
  Future<int> createCameraWithSettings(
          CameraDescription cameraDescription, MediaSettings? mediaSettings) async =>
      1;

  @override
  Future<int> createCamera(CameraDescription cameraDescription, ResolutionPreset? resolutionPreset,
          {bool enableAudio = false}) async =>
      1;

  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) => Stream.value(
      const CameraInitializedEvent(1, 1280, 720, ExposureMode.auto, false, FocusMode.auto, false));

  @override
  Stream<CameraResolutionChangedEvent> onCameraResolutionChanged(int cameraId) =>
      const Stream.empty();

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) => const Stream.empty();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => const Stream.empty();

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId,
      {CameraImageStreamOptions? options}) {
    Timer? timer;
    late final StreamController<CameraImageData> controller;
    controller = StreamController<CameraImageData>(
      onListen: () {
        streamsStarted += 1;
        streaming = true;
        timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          framesDelivered += 1;
          controller.add(CameraImageData(
            // JPEG prêt à l'emploi : pas de conversion dans un isolate.
            format: const CameraImageFormat(ImageFormatGroup.jpeg, raw: 256),
            planes: [CameraImagePlane(bytes: _jpeg, bytesPerRow: 0)],
            height: 1280,
            width: 720,
          ));
        });
      },
      // `async` : le Future d'annulation naît dans la zone du test (temps
      // simulé) ; sans lui, `stopImageStream()` n'aboutirait qu'en temps réel.
      onCancel: () async {
        streaming = false;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<void> dispose(int cameraId) async {}
}

void main() {
  late _FakeCameraPlatform camera;
  late List<String> steps;
  late _FakeCaptureServer api;

  setUp(() {
    camera = _FakeCameraPlatform();
    CameraPlatform.instance = camera;
    steps = [];
  });

  Future<DataleonFlowController> pumpPage(
    WidgetTester tester, {
    Duration? timeout,
    required Future<http.Response> Function(Map<String, dynamic> body) respond,
  }) async {
    // Écran de téléphone en portrait.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final config = timeout == null
        ? DataleonConfig(sessionId: 's', token: 'jwt', initialLanguage: 'fr')
        : DataleonConfig(
            sessionId: 's', token: 'jwt', initialLanguage: 'fr', captureTimeout: timeout);
    api = _FakeCaptureServer(respond, steps);
    final ctrl = DataleonFlowController(
      config: config,
      apiService: DataleonApiService(config: config, client: MockClient(api.handle)),
    );
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: CameraCaptureStepPage(
        controller: ctrl,
        // Temps simulé du test (cadence et délai suivent tester.pump).
        clock: () => tester.binding.clock.now(),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return ctrl;
  }

  /// Quitter l'écran : coupe le flux caméra et les minuteries.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 100);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  http.Response ko() => http.Response(
      jsonEncode({'status': 'ko', 'message': 'Rapprochez la carte', 'details': {'reason': 'card_too_small'}}),
      200);

  testWidgets('stops at the deadline even with a request in flight, with the dedicated message',
      (tester) async {
    var n = 0;
    final ctrl = await pumpPage(tester, timeout: const Duration(seconds: 4), respond: (_) {
      n += 1;
      // 1re image : ko ; ensuite la requête ne revient jamais (réseau bloqué).
      return n == 1 ? Future.value(ko()) : Completer<http.Response>().future;
    });

    await advance(tester, const Duration(milliseconds: 3800));
    expect(ctrl.result.status, isNot(DataleonStatus.error));
    expect(api.calls, greaterThanOrEqualTo(2));

    await advance(tester, const Duration(milliseconds: 400));
    expect(ctrl.result.status, DataleonStatus.error);
    expect(ctrl.result.error, 'capture_timeout');
    expect(find.text('Le temps imparti pour capturer le recto de votre document est écoulé. Vérifiez qu\'il est bien éclairé et entièrement visible dans le cadre, puis relancez la capture.'), findsOneWidget);
    expect(camera.streaming, isFalse, reason: 'le flux caméra doit être coupé');

    final sent = api.calls;
    await advance(tester, const Duration(seconds: 5));
    expect(api.calls, sent, reason: 'plus aucun appel API après le délai');
    await closePage(tester);
  });

  testWidgets('l\'API ne renvoie que status "" → la boucle continue puis s\'arrête au délai',
      (tester) async {
    final ctrl = await pumpPage(tester,
        timeout: const Duration(seconds: 4),
        respond: (_) => Future.value(http.Response(jsonEncode({'status': ''}), 200)));

    await advance(tester, const Duration(milliseconds: 3800));
    expect(ctrl.result.status, isNot(DataleonStatus.error), reason: 'vide = pending : on continue');
    expect(api.calls, greaterThan(5));

    await advance(tester, const Duration(milliseconds: 400));
    expect(ctrl.result.error, 'capture_timeout');
    expect(camera.streaming, isFalse);
    final sent = api.calls;
    await advance(tester, const Duration(seconds: 10));
    expect(api.calls, sent, reason: 'plus aucun envoi : pas de boucle infinie');
    await closePage(tester);
  });

  testWidgets('default delay is 2 minutes per camera step', (tester) async {
    final ctrl = await pumpPage(tester, respond: (_) => Future.value(ko()));

    await advance(tester, const Duration(seconds: 119));
    expect(ctrl.result.status, isNot(DataleonStatus.error));
    await advance(tester, const Duration(seconds: 2));
    expect(ctrl.result.error, 'capture_timeout');
    expect(find.textContaining('capturer le recto de votre document est écoulé'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('« Réessayer » gives a fresh delay', (tester) async {
    final ctrl = await pumpPage(tester,
        timeout: const Duration(seconds: 4), respond: (_) => Future.value(ko()));

    await advance(tester, const Duration(milliseconds: 4200));
    expect(ctrl.result.error, 'capture_timeout');
    await advance(tester, const Duration(seconds: 5)); // feuille d'erreur : hors capture

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    expect(ctrl.result.status, DataleonStatus.started);
    await advance(tester, const Duration(milliseconds: 3700));
    expect(ctrl.result.status, DataleonStatus.started);
    await advance(tester, const Duration(milliseconds: 500));
    expect(ctrl.result.error, 'capture_timeout');
    await closePage(tester);
  });

  testWidgets('next step (recto → verso) restarts the delay; confirmation time excluded',
      (tester) async {
    var n = 0;
    final ctrl = await pumpPage(tester, timeout: const Duration(seconds: 4), respond: (body) {
      n += 1;
      return Future.value(n == 1
          ? http.Response(jsonEncode({'status': 'ok', 'message': null}), 200)
          : ko());
    });

    await advance(tester, const Duration(seconds: 2)); // recto accepté → confirmation
    await advance(tester, const Duration(seconds: 6)); // relecture : ne compte pas
    expect(ctrl.result.status, isNot(DataleonStatus.error));

    await tester.tap(find.text('Confirmer'));
    for (var i = 0; i < 50 && !steps.contains('back'); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(steps, contains('back'));

    await advance(tester, const Duration(milliseconds: 3500));
    expect(ctrl.result.status, isNot(DataleonStatus.error));
    await advance(tester, const Duration(milliseconds: 700));
    expect(ctrl.result.error, 'capture_timeout');
    expect(find.textContaining('capturer le verso de votre document est écoulé'), findsOneWidget);
    await closePage(tester);
  });
}

/// Faux serveur de capture : compte les appels et note l'étape de chaque image.
class _FakeCaptureServer {
  _FakeCaptureServer(this.respond, this.steps);

  final Future<http.Response> Function(Map<String, dynamic> body) respond;
  final List<String> steps;
  int calls = 0;

  Future<http.Response> handle(http.Request request) {
    if (request.url.path.endsWith('/generate-signed-url')) {
      // Envoi du recto confirmé : URL de dépôt factice.
      return Future.value(http.Response(
          jsonEncode({'signedUrl': 'https://s3.test/doc.jpg?Expires=1', 'key': 'doc.jpg'}), 200));
    }
    if (!request.url.path.endsWith('/capture')) {
      return Future.value(http.Response('{}', 200));
    }
    calls += 1;
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    steps.add(body['step'] as String);
    return respond(body);
  }
}
