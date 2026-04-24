import 'dataleon_status.dart';

class DataleonResult {
  final DataleonStatus status;
  final String? error;

  const DataleonResult({
    required this.status,
    this.error,
  });
}
