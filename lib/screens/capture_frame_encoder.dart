// ---------------------------------------------------------------------------
//  Images du flux caméra (`startImageStream`) → JPEG redressé.
//
//  Le flux est silencieux, contrairement à `takePicture()` qui déclenche le son
//  d'obturateur sur iOS à chaque image. Ses images arrivent brutes : BGRA sur
//  iOS, YUV420 (ou NV21) sur Android, et dans l'orientation du capteur sur
//  Android (souvent 90°). Ce module les convertit en JPEG droit, sans
//  dépendance Flutter : `encodeCaptureFrame` tourne dans un isolate (`compute`)
//  pour ne pas bloquer l'interface.
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Format des pixels d'une image du flux.
enum CaptureFrameFormat {
  /// iOS : un plan, 4 octets par pixel (B, G, R, A).
  bgra8888,

  /// Android : trois plans Y, U, V (U/V sous-échantillonnés 2×2, éventuellement
  /// entrelacés : `bytesPerPixel` = 2).
  yuv420,

  /// Android : Y puis V/U entrelacés (un ou deux plans).
  nv21,
}

/// Un plan de pixels, copié depuis `CameraImage.planes` (le tampon natif est
/// réutilisé dès le retour du callback du flux).
class CaptureFramePlane {
  const CaptureFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// Image du flux prête à être encodée (transmissible à un isolate).
class CaptureFrame {
  const CaptureFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    this.rotation = 0,
    this.jpegQuality = 85,
  });

  final int width;
  final int height;
  final CaptureFrameFormat format;
  final List<CaptureFramePlane> planes;

  /// Rotation horaire à appliquer (0, 90, 180 ou 270).
  final int rotation;
  final int jpegQuality;

  /// Dimensions après rotation.
  int get outputWidth => rotation % 180 == 0 ? width : height;
  int get outputHeight => rotation % 180 == 0 ? height : width;
}

/// Rotation horaire qui redresse une image du flux pour une interface en
/// portrait.
///
/// Android livre l'image dans l'orientation du capteur : `sensorOrientation`
/// est justement l'angle horaire qui la redresse (90° en général, 270° pour
/// certains capteurs et caméras frontales). iOS oriente déjà le flux comme
/// l'appareil ; si l'image arrive malgré tout en paysage, on la tourne de 90°.
/// Une image déjà en portrait n'est jamais tournée.
int captureFrameRotation({
  required bool isAndroid,
  required int sensorOrientation,
  required int width,
  required int height,
}) {
  if (width <= height) return 0;
  if (isAndroid) {
    final r = ((sensorOrientation % 360) + 360) % 360;
    return r == 0 ? 90 : r;
  }
  return 90;
}

/// Convertit, redresse et encode une image du flux en JPEG.
///
/// Fonction de premier niveau : utilisable telle quelle avec `compute`.
Uint8List encodeCaptureFrame(CaptureFrame frame) {
  final rotation = ((frame.rotation % 360) + 360) % 360;
  if (rotation % 90 != 0) {
    throw ArgumentError.value(frame.rotation, 'rotation', 'must be a multiple of 90');
  }
  final w = frame.width;
  final h = frame.height;
  final outW = frame.outputWidth;
  final outH = frame.outputHeight;
  final rgb = Uint8List(outW * outH * 3);

  void put(int x, int y, int r, int g, int b) {
    int dx, dy;
    switch (rotation) {
      case 90:
        dx = h - 1 - y;
        dy = x;
        break;
      case 180:
        dx = w - 1 - x;
        dy = h - 1 - y;
        break;
      case 270:
        dx = y;
        dy = w - 1 - x;
        break;
      default:
        dx = x;
        dy = y;
    }
    final o = (dy * outW + dx) * 3;
    rgb[o] = r;
    rgb[o + 1] = g;
    rgb[o + 2] = b;
  }

  switch (frame.format) {
    case CaptureFrameFormat.bgra8888:
      _bgraToRgb(frame, put);
      break;
    case CaptureFrameFormat.yuv420:
      _yuv420ToRgb(frame, put);
      break;
    case CaptureFrameFormat.nv21:
      _nv21ToRgb(frame, put);
      break;
  }

  final image = img.Image.fromBytes(
    width: outW,
    height: outH,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  return img.encodeJpg(image, quality: frame.jpegQuality.clamp(1, 100).toInt());
}

typedef _PutPixel = void Function(int x, int y, int r, int g, int b);

void _bgraToRgb(CaptureFrame f, _PutPixel put) {
  final plane = f.planes.first;
  final bytes = plane.bytes;
  final stride = plane.bytesPerRow;
  for (var y = 0; y < f.height; y++) {
    var i = y * stride;
    for (var x = 0; x < f.width; x++, i += 4) {
      put(x, y, bytes[i + 2], bytes[i + 1], bytes[i]);
    }
  }
}

void _yuv420ToRgb(CaptureFrame f, _PutPixel put) {
  if (f.planes.length < 3) {
    _nv21ToRgb(f, put);
    return;
  }
  final yPlane = f.planes[0];
  final uPlane = f.planes[1];
  final vPlane = f.planes[2];
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;
  for (var y = 0; y < f.height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y >> 1) * uvRowStride;
    for (var x = 0; x < f.width; x++) {
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      _yuvPut(x, y, yPlane.bytes[yRow + x], _at(uPlane.bytes, uvIndex),
          _at(vPlane.bytes, uvIndex), put);
    }
  }
}

void _nv21ToRgb(CaptureFrame f, _PutPixel put) {
  final yPlane = f.planes[0];
  final yStride = yPlane.bytesPerRow;
  // Un seul plan : Y (hauteur × stride) puis V/U entrelacés. Deux plans : V/U
  // dans le second.
  final Uint8List vu;
  final int vuOffset;
  final int vuStride;
  if (f.planes.length >= 2) {
    vu = f.planes[1].bytes;
    vuOffset = 0;
    vuStride = f.planes[1].bytesPerRow;
  } else {
    vu = yPlane.bytes;
    vuOffset = yStride * f.height;
    vuStride = yStride;
  }
  for (var y = 0; y < f.height; y++) {
    final yRow = y * yStride;
    final vuRow = vuOffset + (y >> 1) * vuStride;
    for (var x = 0; x < f.width; x++) {
      final i = vuRow + (x & ~1);
      _yuvPut(x, y, yPlane.bytes[yRow + x], _at(vu, i + 1), _at(vu, i), put);
    }
  }
}

int _at(Uint8List bytes, int i) => i < bytes.length ? bytes[i] : 128;

// YUV plein écart (JFIF / BT.601), celui des capteurs Android, en entiers.
void _yuvPut(int x, int y, int yy, int u, int v, _PutPixel put) {
  final d = u - 128;
  final e = v - 128;
  final r = yy + ((91881 * e) >> 16);
  final g = yy - ((22554 * d + 46802 * e) >> 16);
  final b = yy + ((116130 * d) >> 16);
  put(x, y, _clamp(r), _clamp(g), _clamp(b));
}

int _clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);
