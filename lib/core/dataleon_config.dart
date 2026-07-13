class DataleonConfig {
  final String sessionId;
  final String token;
  final String? accountTenant;
  final String? uploadBucket;
  final String appVersion;
  final String? initialLanguage;
  final String customerAssetsBucket;

  DataleonConfig({
    required this.sessionId,
    required this.token,
    this.accountTenant,
    this.uploadBucket,
    this.appVersion = '2.0.7',
    this.initialLanguage,
    this.customerAssetsBucket = 'yap-assets-customer',
  });

  String get sessionToken => token;

  String? get accountTenantHeader {
    if (accountTenant == null || accountTenant!.isEmpty) {
      return null;
    }
    return accountTenant;
  }

  void dispose() {}

  /// Base URL for API calls. Hardcoded for security; cannot be overridden.
  String get baseUrl => 'https://inference.eu-west-1.dataleon.ai';
}
