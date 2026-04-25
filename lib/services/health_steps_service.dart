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
  HealthFactory? _health;
  bool _authorized = false;

  Future<bool> isConnected() async {
    _health ??= HealthFactory();
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];
    try {
      _authorized = await _health!.requestAuthorization(types, permissions: permissions);
      import 'package:health/health.dart';
      return _authorized;
    } catch (_) {
      return false;
    }
  }

  Future<int?> fetchStepsForDate(DateTime date) async {
    _health ??= HealthFactory();
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];
    try {
      if (!_authorized) {
        _authorized = await _health!.requestAuthorization(types, permissions: permissions);
        if (!_authorized) return null;
      }
      final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final data = await _health!.getHealthDataFromTypes(start, end, types);
      final steps = data
          .where((d) => d.type == HealthDataType.STEPS)
          .fold<int>(0, (sum, d) => sum + (d.value as int? ?? 0));
      return steps;
    } catch (_) {
      return null;
    }
  }
}
