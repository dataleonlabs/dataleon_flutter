class DataleonSession {
  final String id;
  final String status;
  final Map<String, dynamic>? metadata;

  const DataleonSession({
    required this.id,
    required this.status,
    this.metadata,
  });

  factory DataleonSession.fromJson(Map<String, dynamic> json) {
    return DataleonSession(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
