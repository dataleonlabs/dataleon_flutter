class DataleonStepResult {
  final String stepName;
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const DataleonStepResult({
    required this.stepName,
    required this.success,
    this.data,
    this.errorMessage,
  });
}
