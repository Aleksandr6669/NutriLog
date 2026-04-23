enum HealthConnectStatus {
  connected,
  needsHealthConnectInstall,
  permissionDenied,
  failed,
}

class HealthConnectResult {
  final HealthConnectStatus status;
  final String message;

  const HealthConnectResult({
    required this.status,
    required this.message,
  });

  bool get isConnected => status == HealthConnectStatus.connected;
}

class HealthStepsService {
  /// Заглушка: пока не поддерживается интеграция со здоровьем.
  Future<bool> isConnected() async => false;

  /// Заглушка: возвращаем null, чтобы шаги не синхронизировались.
  Future<int?> fetchStepsForDate(DateTime date) async => null;
}
