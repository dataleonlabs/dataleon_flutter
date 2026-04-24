class DataleonConfig {
  final String sessionId;
  final String apiKey;
  final String? apiBaseUrl;
  final String? uploadBucket;
  final String appVersion;

  /// Set after calling [DataleonApiService.fetchToken].
  String? _sessionToken;

  DataleonConfig({
    required this.sessionId,
    required this.apiKey,
    this.apiBaseUrl,
    this.uploadBucket,
    this.appVersion = '2.0.0-beta',
  });

  /// The JWT session token. Must be set via [setSessionToken] before API calls.
  String get sessionToken => _sessionToken ?? sessionId;

  set sessionToken(String token) => _sessionToken = token;

  /// Base URL for API calls.
  String get baseUrl {
    if (apiBaseUrl != null && apiBaseUrl!.isNotEmpty) {
      return apiBaseUrl!;
    }
    return 'https://inference.eu-west-1.dataleon.ai';
  }
}
