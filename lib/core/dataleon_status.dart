enum DataleonStatus {
  idle,
  started,
  finished,
  canceled,
  failed,
  error,
  aborted,
}

extension DataleonStatusX on DataleonStatus {
  String get value {
    switch (this) {
      case DataleonStatus.idle:
        return 'IDLE';
      case DataleonStatus.started:
        return 'STARTED';
      case DataleonStatus.finished:
        return 'FINISHED';
      case DataleonStatus.canceled:
        return 'CANCELED';
      case DataleonStatus.failed:
        return 'FAILED';
      case DataleonStatus.error:
        return 'ERROR';
      case DataleonStatus.aborted:
        return 'ABORTED';
    }
  }
}
