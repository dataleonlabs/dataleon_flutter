import 'dart:typed_data';

import 'package:dataleon_flutter/screens/capture_frame_encoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Image 4×2 : moitié gauche rouge, moitié droite bleue.
const _w = 4;
const _h = 2;
bool _isLeft(int x) => x < _w ~/ 2;

CaptureFrame _bgra({int rotation = 0, int padding = 0}) {
  final stride = _w * 4 + padding;
  final bytes = Uint8List(stride * _h);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = y * stride + x * 4;
      // B, G, R, A
      bytes[i] = _isLeft(x) ? 0 : 255;
      bytes[i + 1] = 0;
      bytes[i + 2] = _isLeft(x) ? 255 : 0;
      bytes[i + 3] = 255;
    }
  }
  return CaptureFrame(
    width: _w,
    height: _h,
    format: CaptureFrameFormat.bgra8888,
    planes: [CaptureFramePlane(bytes: bytes, bytesPerRow: stride, bytesPerPixel: 4)],
    rotation: rotation,
    jpegQuality: 100,
  );
}

// Rouge pur en YUV plein écart : Y=76, U=85, V=255 ; bleu : Y=29, U=255, V=107.
const _red = [76, 85, 255];
const _blue = [29, 255, 107];

CaptureFrame _yuv420({int rotation = 0, int uvPixelStride = 1}) {
  final y = Uint8List(_w * _h);
  for (var j = 0; j < _h; j++) {
    for (var i = 0; i < _w; i++) {
      y[j * _w + i] = (_isLeft(i) ? _red : _blue)[0];
    }
  }
  final uvW = _w ~/ 2;
  final uvStride = uvW * uvPixelStride;
  final u = Uint8List(uvStride);
  final v = Uint8List(uvStride);
  for (var i = 0; i < uvW; i++) {
    final c = i < uvW ~/ 2 ? _red : _blue;
    u[i * uvPixelStride] = c[1];
    v[i * uvPixelStride] = c[2];
  }
  return CaptureFrame(
    width: _w,
    height: _h,
    format: CaptureFrameFormat.yuv420,
    planes: [
      CaptureFramePlane(bytes: y, bytesPerRow: _w, bytesPerPixel: 1),
      CaptureFramePlane(bytes: u, bytesPerRow: uvStride, bytesPerPixel: uvPixelStride),
      CaptureFramePlane(bytes: v, bytesPerRow: uvStride, bytesPerPixel: uvPixelStride),
    ],
    rotation: rotation,
    jpegQuality: 100,
  );
}

CaptureFrame _nv21() {
  final bytes = Uint8List(_w * _h + _w);
  for (var j = 0; j < _h; j++) {
    for (var i = 0; i < _w; i++) {
      bytes[j * _w + i] = (_isLeft(i) ? _red : _blue)[0];
    }
  }
  // V, U entrelacés pour chaque bloc 2×2.
  for (var i = 0; i < _w ~/ 2; i++) {
    final c = i == 0 ? _red : _blue;
    bytes[_w * _h + i * 2] = c[2];
    bytes[_w * _h + i * 2 + 1] = c[1];
  }
  return CaptureFrame(
    width: _w,
    height: _h,
    format: CaptureFrameFormat.nv21,
    planes: [CaptureFramePlane(bytes: bytes, bytesPerRow: _w)],
    jpegQuality: 100,
  );
}

img.Image _decode(Uint8List jpeg) => img.decodeJpg(jpeg)!;

bool _reddish(img.Pixel p) => p.r > 150 && p.b < 100;
bool _bluish(img.Pixel p) => p.b > 150 && p.r < 100;

void main() {
  group('captureFrameRotation', () {
    test('portrait frames are never rotated', () {
      expect(
          captureFrameRotation(isAndroid: true, sensorOrientation: 90, width: 720, height: 1280),
          0);
      expect(
          captureFrameRotation(isAndroid: false, sensorOrientation: 90, width: 720, height: 1280),
          0);
    });

    test('Android landscape frames follow the sensor orientation', () {
      expect(
          captureFrameRotation(isAndroid: true, sensorOrientation: 90, width: 1280, height: 720),
          90);
      expect(
          captureFrameRotation(isAndroid: true, sensorOrientation: 270, width: 1280, height: 720),
          270);
      expect(
          captureFrameRotation(isAndroid: true, sensorOrientation: 0, width: 1280, height: 720),
          90);
    });

    test('iOS landscape frames are turned upright', () {
      expect(
          captureFrameRotation(isAndroid: false, sensorOrientation: 90, width: 1280, height: 720),
          90);
    });
  });

  group('encodeCaptureFrame', () {
    test('BGRA keeps size and colours', () {
      final out = _decode(encodeCaptureFrame(_bgra()));
      expect(out.width, _w);
      expect(out.height, _h);
      expect(_reddish(out.getPixel(0, 0)), isTrue);
      expect(_bluish(out.getPixel(3, 1)), isTrue);
    });

    test('BGRA row padding is skipped', () {
      final out = _decode(encodeCaptureFrame(_bgra(padding: 8)));
      expect(_reddish(out.getPixel(0, 1)), isTrue);
      expect(_bluish(out.getPixel(3, 1)), isTrue);
    });

    test('90° clockwise: left side ends up on top', () {
      final frame = _bgra(rotation: 90);
      expect(frame.outputWidth, _h);
      expect(frame.outputHeight, _w);
      final out = _decode(encodeCaptureFrame(frame));
      expect(out.width, _h);
      expect(out.height, _w);
      expect(_reddish(out.getPixel(0, 0)), isTrue);
      expect(_bluish(out.getPixel(0, 3)), isTrue);
    });

    test('270° clockwise: left side ends up at the bottom', () {
      final out = _decode(encodeCaptureFrame(_bgra(rotation: 270)));
      expect(out.width, _h);
      expect(out.height, _w);
      expect(_bluish(out.getPixel(0, 0)), isTrue);
      expect(_reddish(out.getPixel(0, 3)), isTrue);
    });

    test('180°: left and right are swapped', () {
      final out = _decode(encodeCaptureFrame(_bgra(rotation: 180)));
      expect(_bluish(out.getPixel(0, 0)), isTrue);
      expect(_reddish(out.getPixel(3, 1)), isTrue);
    });

    test('YUV420 planar is converted to RGB', () {
      final out = _decode(encodeCaptureFrame(_yuv420()));
      expect(_reddish(out.getPixel(0, 0)), isTrue);
      expect(_bluish(out.getPixel(3, 0)), isTrue);
    });

    test('YUV420 with interleaved chroma (pixel stride 2)', () {
      final out = _decode(encodeCaptureFrame(_yuv420(uvPixelStride: 2)));
      expect(_reddish(out.getPixel(0, 0)), isTrue);
      expect(_bluish(out.getPixel(3, 0)), isTrue);
    });

    test('YUV420 rotated like an Android back camera', () {
      final out = _decode(encodeCaptureFrame(_yuv420(rotation: 90)));
      expect(out.width, _h);
      expect(out.height, _w);
      expect(_reddish(out.getPixel(1, 0)), isTrue);
      expect(_bluish(out.getPixel(1, 3)), isTrue);
    });

    test('NV21 single plane', () {
      final out = _decode(encodeCaptureFrame(_nv21()));
      expect(_reddish(out.getPixel(0, 0)), isTrue);
      expect(_bluish(out.getPixel(3, 1)), isTrue);
    });

    test('rejects non-orthogonal rotations', () {
      expect(() => encodeCaptureFrame(_bgra(rotation: 45)), throwsArgumentError);
    });
  });
}
