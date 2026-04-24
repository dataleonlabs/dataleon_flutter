import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dataleon_flutter/core/dataleon_config.dart';
import 'package:dataleon_flutter/services/dataleon_api_service.dart';

void main() {
  late DataleonConfig config;

  setUp(() {
    config = DataleonConfig(
      sessionId: 'test-session-id',
      apiKey: 'test-api-key',
    );
  });

  DataleonApiService createService(MockClient client) {
    return DataleonApiService(config: config, client: client);
  }

  group('DataleonApiService', () {
    group('fetchToken', () {
      test('sets sessionToken on success', () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/token/test-session-id');
          expect(request.headers['api-key'], 'test-api-key');
          return http.Response(
            jsonEncode({'token': 'jwt-abc-123'}),
            200,
          );
        });

        final service = createService(client);
        final result = await service.fetchToken();

        expect(result['token'], 'jwt-abc-123');
        expect(config.sessionToken, 'jwt-abc-123');
      });

      test('does not set token when response has no token', () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({}), 200);
        });

        final service = createService(client);
        await service.fetchToken();

        // Should still return sessionId as fallback
        expect(config.sessionToken, 'test-session-id');
      });

      test('does not set token when token is empty string', () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'token': ''}), 200);
        });

        final service = createService(client);
        await service.fetchToken();

        expect(config.sessionToken, 'test-session-id');
      });

      test('throws DataleonApiException on non-200 status', () async {
        final client = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final service = createService(client);
        expect(
          () => service.fetchToken(),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)),
        );
      });

      test('throws DataleonApiException on 403', () async {
        final client = MockClient((request) async {
          return http.Response('Forbidden', 403);
        });

        final service = createService(client);
        expect(
          () => service.fetchToken(),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)),
        );
      });
    });

    group('fetchRequestConfig', () {
      test('posts with correct URL, headers and body', () async {
        config.sessionToken = 'jwt-token';
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/individuals/test-session-id/config');
          expect(request.headers['Authorization'], 'Bearer jwt-token');
          expect(request.headers['X-Trax'], 'test-session-id');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['request_id'], 'test-session-id');

          return http.Response(
            jsonEncode({'result': {'status': 'active'}}),
            200,
          );
        });

        final service = createService(client);
        final result = await service.fetchRequestConfig();

        expect(result['result']['status'], 'active');
      });

      test('throws on non-200 status', () async {
        final client = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final service = createService(client);
        expect(
          () => service.fetchRequestConfig(),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });
    });

    group('applyRequestService', () {
      test('posts to correct path with gateway headers', () async {
        config.sessionToken = 'jwt';
        final client = MockClient((request) async {
          expect(request.url.path, '/test/path');
          expect(request.headers['Authorization'], 'Bearer jwt');
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final service = createService(client);
        final result = await service.applyRequestService(
          path: '/test/path',
          data: {'key': 'value'},
        );

        expect(result['ok'], true);
      });

      test('merges additional headers', () async {
        final client = MockClient((request) async {
          expect(request.headers['X-Custom'], 'custom-value');
          return http.Response(jsonEncode({}), 200);
        });

        final service = createService(client);
        await service.applyRequestService(
          path: '/path',
          data: {},
          headers: {'X-Custom': 'custom-value'},
        );
      });

      test('returns empty map when body is empty', () async {
        final client = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = createService(client);
        final result = await service.applyRequestService(
          path: '/path',
          data: {},
        );

        expect(result, isEmpty);
      });

      test('sends raw string data as-is', () async {
        final client = MockClient((request) async {
          expect(request.body, 'raw-string-data');
          return http.Response(jsonEncode({}), 200);
        });

        final service = createService(client);
        await service.applyRequestService(
          path: '/path',
          data: 'raw-string-data',
        );
      });

      test('throws on 4xx/5xx status', () async {
        final client = MockClient((request) async {
          return http.Response('Bad Request', 400);
        });

        final service = createService(client);
        expect(
          () => service.applyRequestService(path: '/path', data: {}),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)),
        );
      });
    });

    group('sendCaptureFrame', () {
      test('posts to correct URL', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/individuals/test-session-id/capture');
          return http.Response(jsonEncode({'frame': 'ok'}), 200);
        });

        final service = createService(client);
        final result = await service.sendCaptureFrame(
          payload: {'image': 'base64data'},
        );

        expect(result['frame'], 'ok');
      });

      test('returns empty map when body is empty', () async {
        final client = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = createService(client);
        final result = await service.sendCaptureFrame(
          payload: {'image': 'data'},
        );

        expect(result, isEmpty);
      });

      test('throws on error status', () async {
        final client = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final service = createService(client);
        expect(
          () => service.sendCaptureFrame(payload: {'image': 'data'}),
          throwsA(isA<DataleonApiException>()),
        );
      });
    });

    group('generateSignedUploadUrl', () {
      test('sends correct payload', () async {
        config = DataleonConfig(
          sessionId: 's',
          apiKey: 'k',
          uploadBucket: 'my-bucket',
        );
        final client = MockClient((request) async {
          expect(request.url.path, '/generate-signed-url');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['key'], 'photo.jpg');
          expect(body['content_type'], 'image/jpeg');
          expect(body['acl'], 'private');
          expect(body['type'], 'PUT');
          expect(body['bucket'], 'my-bucket');
          return http.Response(
            jsonEncode({'url': 'https://s3.example.com/signed'}),
            200,
          );
        });

        final service = createService(client);
        final result = await service.generateSignedUploadUrl(
          objectName: 'photo.jpg',
          contentType: 'image/jpeg',
        );

        expect(result['url'], 'https://s3.example.com/signed');
      });

      test('uses empty string when no uploadBucket', () async {
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['bucket'], '');
          return http.Response(jsonEncode({}), 200);
        });

        final service = createService(client);
        await service.generateSignedUploadUrl(
          objectName: 'file.png',
          contentType: 'image/png',
        );
      });

      test('throws on error status', () async {
        final client = MockClient((request) async {
          return http.Response('Error', 400);
        });

        final service = createService(client);
        expect(
          () => service.generateSignedUploadUrl(
            objectName: 'file.png',
            contentType: 'image/png',
          ),
          throwsA(isA<DataleonApiException>()),
        );
      });
    });

    group('uploadBytesToSignedUrl', () {
      test('strips ?Expires query param from URL', () async {
        final client = MockClient((request) async {
          expect(request.method, 'PUT');
          return http.Response('', 200);
        });

        final service = createService(client);
        final result = await service.uploadBytesToSignedUrl(
          signedUrl: 'https://s3.example.com/photo.jpg?Expires=123&Sig=abc',
          bytes: [1, 2, 3],
          contentType: 'image/jpeg',
        );

        expect(result, 'https://s3.example.com/photo.jpg');
      });

      test('strips any query string if no Expires', () async {
        final client = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = createService(client);
        final result = await service.uploadBytesToSignedUrl(
          signedUrl: 'https://s3.example.com/photo.jpg?token=xyz',
          bytes: [1, 2, 3],
          contentType: 'image/jpeg',
        );

        expect(result, 'https://s3.example.com/photo.jpg');
      });

      test('returns URL as-is when no query string', () async {
        final client = MockClient((request) async {
          return http.Response('', 200);
        });

        final service = createService(client);
        final result = await service.uploadBytesToSignedUrl(
          signedUrl: 'https://s3.example.com/photo.jpg',
          bytes: [1, 2, 3],
          contentType: 'image/jpeg',
        );

        expect(result, 'https://s3.example.com/photo.jpg');
      });

      test('throws on upload failure', () async {
        final client = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final service = createService(client);
        expect(
          () => service.uploadBytesToSignedUrl(
            signedUrl: 'https://s3.example.com/photo.jpg',
            bytes: [1, 2, 3],
            contentType: 'image/jpeg',
          ),
          throwsA(isA<DataleonApiException>()),
        );
      });
    });

    group('submitFinishedDocuments', () {
      test('delegates to applyRequestService with correct path', () async {
        final client = MockClient((request) async {
          expect(
            request.url.path,
            '/individuals/test-session-id/verifications/finished',
          );
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        final service = createService(client);
        final result = await service.submitFinishedDocuments(
          data: {'documents': []},
        );

        expect(result['ok'], true);
      });
    });

    group('getSession', () {
      test('returns DataleonSession on success', () async {
        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/sessions/test-session-id');
          return http.Response(
            jsonEncode({'id': 'test-session-id', 'status': 'active'}),
            200,
          );
        });

        final service = createService(client);
        final session = await service.getSession();

        expect(session.id, 'test-session-id');
        expect(session.status, 'active');
      });

      test('throws on failure', () async {
        final client = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final service = createService(client);
        expect(
          () => service.getSession(),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });
    });

    group('submitStep', () {
      test('posts to correct URL', () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/sessions/test-session-id/steps/document',
          );
          return http.Response(jsonEncode({'submitted': true}), 200);
        });

        final service = createService(client);
        final result = await service.submitStep(
          stepName: 'document',
          data: {'type': 'passport'},
        );

        expect(result['submitted'], true);
      });

      test('accepts 201 status', () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'ok': true}), 201);
        });

        final service = createService(client);
        final result = await service.submitStep(
          stepName: 'selfie',
          data: {},
        );

        expect(result['ok'], true);
      });

      test('throws on 400', () async {
        final client = MockClient((request) async {
          return http.Response('Bad Request', 400);
        });

        final service = createService(client);
        expect(
          () => service.submitStep(stepName: 'step', data: {}),
          throwsA(isA<DataleonApiException>()),
        );
      });
    });

    group('completeSession', () {
      test('posts to correct URL', () async {
        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/sessions/test-session-id/complete',
          );
          return http.Response('', 200);
        });

        final service = createService(client);
        await service.completeSession();
      });

      test('throws on failure', () async {
        final client = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final service = createService(client);
        expect(
          () => service.completeSession(),
          throwsA(isA<DataleonApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)),
        );
      });
    });
  });

  group('DataleonApiException', () {
    test('toString includes statusCode and message', () {
      const ex = DataleonApiException('test error', statusCode: 404);
      expect(ex.toString(), 'DataleonApiException(404): test error');
    });

    test('toString with null statusCode', () {
      const ex = DataleonApiException('network error');
      expect(ex.toString(), 'DataleonApiException(null): network error');
    });

    test('implements Exception', () {
      const ex = DataleonApiException('err');
      expect(ex, isA<Exception>());
    });
  });
}
