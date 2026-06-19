class DataleonConfig {
  final String sessionId;
  final String token;
  final String? accountTenant;
  final String? apiBaseUrl;
  final String? uploadBucket;
  final String appVersion;
  final String? initialLanguage;
  final String customerAssetsBucket;

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
          apiBaseUrl == null || apiBaseUrl.isEmpty || apiBaseUrl.startsWith('https://'),
          'apiBaseUrl must use HTTPS',
        );

  String get sessionToken => token;

  String? get accountTenantHeader {
    if (accountTenant == null || accountTenant!.isEmpty) {
      return null;
    }
    return accountTenant;
  }

  void dispose() {}

  /// Base URL for API calls.
  String get baseUrl {
    if (apiBaseUrl != null && apiBaseUrl!.isNotEmpty) {
      return apiBaseUrl!;
    }
    return 'https://inference.eu-west-1.dataleon.ai';
  }
}
