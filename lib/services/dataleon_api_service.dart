import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import '../core/dataleon_config.dart';
import '../models/session.dart';

class DataleonApiService {
  final DataleonConfig config;
  final http.Client _client;
  static const String _webviewVersion = '3';
  static const String _webviewRelease = '1';

  DataleonApiService({
    required this.config,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _withAccountTenant(Map<String, String> headers) => {
        ...headers,
        if (config.accountTenantHeader != null)
          'X-Account-Tenant': config.accountTenantHeader!,
      };

  Map<String, String> get _headers => _withAccountTenant({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.sessionToken}',
      });

  Map<String, String> get _gatewayHeaders => _withAccountTenant({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${config.sessionToken}',
        'X-Trax': config.sessionId,
        'X-Webview-Version': _webviewVersion,
        'X-Webview-Release': _webviewRelease,
        'X-App-Version': config.appVersion,
      });

  /// Runtime platform name reported via the informative `X-Platform` header.
  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  /// Headers for the public branding endpoint: no auth / token / tenant /
  /// session, only informative headers.
  Map<String, String> get _publicHeaders => _withAccountTenant({
        'Accept': 'application/json',
        'X-App-Version': config.appVersion,
        'X-Platform': _platform,
        'X-Webview-Version': _webviewVersion,
        'X-Webview-Release': _webviewRelease,
      });

  /// Fetch the public dashboard branding config used to paint the loading
  /// screen before any authenticated call.
  ///
  /// Public endpoint: sends no auth/token/session headers, only informative
  /// ones (see [_publicHeaders]).
  Future<Map<String, dynamic>> fetchChartConfig() async {
    final url = Uri.parse(
      '${config.baseUrl}/individuals/${config.sessionId}/config/chart',
    );

    final response = await _client.get(url, headers: _publicHeaders);

    if (response.statusCode != 200) {
      throw DataleonApiException(
        'Failed to fetch chart config',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) return body;
    return const <String, dynamic>{};
  }

  /// Fetch the request configuration and progress from the backend.
  /// Equivalent to the React fetchRequestConfig.
  Future<Map<String, dynamic>> fetchRequestConfig() async {
    final url = Uri.parse(
      '${config.baseUrl}/individuals/${config.sessionId}/config',
    );

    final response = await _client.post(
      url,
      headers: _gatewayHeaders,
      body: jsonEncode({'request_id': config.sessionId}),
    );

    if (response.statusCode != 200) {
      throw DataleonApiException(
        'Failed to fetch request config',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchContentsConfig() async {
    final url = Uri.parse(
      '${config.baseUrl}/contents-configs/${config.sessionId}',
    );
    try {
      final response = await _client.get(url, headers: _gatewayHeaders);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) return body;
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> applyRequestService({
    required String path,
    required Object data,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${config.baseUrl}$path');
    final response = await _client.post(
      url,
      headers: {
        ..._gatewayHeaders,
        if (headers != null) ...headers,
      },
      body: data is String ? data : jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to apply request service for $path',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendCaptureFrame({
    required Map<String, dynamic> payload,
  }) async {
    final url =
        Uri.parse('${config.baseUrl}/individuals/${config.sessionId}/capture');
    final response = await _client.post(
      url,
      headers: _gatewayHeaders,
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to send capture frame',
        statusCode: response.statusCode,
      );
    }

    if (response.body.isEmpty) {
      return const <String, dynamic>{};
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateSignedUploadUrl({
    required String objectName,
    required String contentType,
    String acl = 'private',
    String? bucket,
  }) async {
    final url = Uri.parse('${config.baseUrl}/generate-signed-url');
    final response = await _client.post(
      url,
      headers: _gatewayHeaders,
      body: jsonEncode({
        'key': objectName,
        'content_type': contentType,
        'acl': acl,
        'type': 'PUT',
        'bucket': bucket ?? config.uploadBucket ?? '',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to generate signed upload url',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateSignedGetUrl({
    required String objectName,
    String? bucket,
  }) async {
    final url = Uri.parse('${config.baseUrl}/generate-signed-url');
    final response = await _client.post(
      url,
      headers: _gatewayHeaders,
      body: jsonEncode({
        'key': objectName,
        'type': 'GET',
        'bucket': bucket ?? config.uploadBucket ?? '',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to generate signed GET url',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<int>> downloadBytes(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to download bytes from $url',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<String> uploadBytesToSignedUrl({
    required String signedUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final response = await _client.put(
      Uri.parse(signedUrl),
      headers: {
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DataleonApiException(
        'Failed to upload bytes to signed url',
        statusCode: response.statusCode,
      );
    }

    final expiresIndex = signedUrl.indexOf('?Expires');
    if (expiresIndex != -1) {
      return signedUrl.substring(0, expiresIndex);
    }

    final queryIndex = signedUrl.indexOf('?');
    if (queryIndex != -1) {
      return signedUrl.substring(0, queryIndex);
    }

    return signedUrl;
  }

  Future<Map<String, dynamic>> submitFinishedDocuments({
    required Object data,
  }) async {
    return applyRequestService(
      path: '/individuals/${config.sessionId}/verifications/finished',
      data: data,
    );
  }

  /// Fetch the current session info from the backend.
  Future<DataleonSession> getSession() async {
    final url =
        Uri.parse('${config.baseUrl}/api/v1/sessions/${config.sessionId}');
    final response = await _client.get(url, headers: _headers);

    if (response.statusCode != 200) {
      throw DataleonApiException(
        'Failed to fetch session',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return DataleonSession.fromJson(json);
  }

  /// Submit step data to the backend.
  Future<Map<String, dynamic>> submitStep({
    required String stepName,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse(
      '${config.baseUrl}/api/v1/sessions/${config.sessionId}/steps/$stepName',
    );

    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DataleonApiException(
        'Failed to submit step $stepName',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Upload a file (document photo, selfie, etc.) to the backend.
  Future<Map<String, dynamic>> uploadFile({
    required String stepName,
    required String fieldName,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final url = Uri.parse(
      '${config.baseUrl}/api/v1/sessions/${config.sessionId}/upload',
    );

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(
        _withAccountTenant({
          'Authorization': 'Bearer ${config.sessionToken}',
        }),
      )
      ..fields['step'] = stepName
      ..files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
      ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DataleonApiException(
        'Failed to upload file for step $stepName',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Complete / finalize the session.
  Future<void> completeSession() async {
    final url = Uri.parse(
      '${config.baseUrl}/api/v1/sessions/${config.sessionId}/complete',
    );

    final response = await _client.post(url, headers: _headers);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DataleonApiException(
        'Failed to complete session',
        statusCode: response.statusCode,
      );
    }
  }

  void dispose() {
    _client.close();
  }
}

class DataleonApiException implements Exception {
  final String message;
  final int? statusCode;

  const DataleonApiException(this.message, {this.statusCode});

  @override
  String toString() => 'DataleonApiException($statusCode): $message';
}
