import 'dart:io' show Platform;

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _connectedKey = 'health_steps_connected';
  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_connectedKey) ?? false;

    // Самовосстановление состояния: если флаг stale, сверяем с реальным доступом.
    try {
      await _ensureConfigured();
      final hasAccess = await _hasStepsReadAccess();
      if (hasAccess != stored) {
        await prefs.setBool(_connectedKey, hasAccess);
      }
      return hasAccess;
    } catch (_) {
      return stored;
    }
  }

  Future<bool> connect() async {
    final result = await connectWithStatus();
    return result.isConnected;
  }

  Future<bool> _hasStepsReadAccess() async {
    final has = await _health.hasPermissions(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );
    return has == true;
  }

  Future<HealthConnectResult> connectWithStatus() async {
    try {
      await _ensureConfigured();

      if (Platform.isAndroid) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_connectedKey, false);
          return const HealthConnectResult(
            status: HealthConnectStatus.needsHealthConnectInstall,
            message:
                'Для синхронизации нужен Health Connect с доступом к данным Шаги (Steps). Установите/обновите его и повторите подключение.',
          );
        }
      }

      var granted = await _hasStepsReadAccess();
      if (!granted) {
        granted = await _health.requestAuthorization(
              [HealthDataType.STEPS],
              permissions: [HealthDataAccess.READ],
            ) ==
            true;

        // На части Android-девайсов requestAuthorization может вернуть false,
        // даже если доступ уже выдан в Health Connect. Проверяем повторно.
        if (!granted) {
          granted = await _hasStepsReadAccess();
        }
      }

      if (Platform.isIOS && granted == true) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final probe = await _health.getTotalStepsInInterval(startOfDay, now);
        if (probe == null) {
          // На iOS null может означать не только запрет, но и отсутствие шагов за день.
          // Если авторизация уже выдана — считаем источник подключенным.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_connectedKey, true);
          return const HealthConnectResult(
            status: HealthConnectStatus.connected,
            message:
                'Источник здоровья подключен. Нужны только данные Шаги (Steps). За сегодня шаги пока недоступны — проверьте, что в приложении Здоровье есть записи шагов.',
          );
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, granted == true);

      if (granted == true) {
        return const HealthConnectResult(
          status: HealthConnectStatus.connected,
          message: 'Источник здоровья подключен.',
        );
      }

      return const HealthConnectResult(
        status: HealthConnectStatus.permissionDenied,
        message:
            'Доступ не выдан. Разрешите только данные Шаги (Steps). На Android: Health Connect -> NutriLog -> Разрешения -> Шаги.',
      );
    } catch (error) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, false);
      return HealthConnectResult(
        status: HealthConnectStatus.failed,
        message:
            'Не удалось подключить источник здоровья. Попробуйте снова. Детали: $error',
      );
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, false);
  }

  Future<int?> fetchStepsForDate(
    DateTime date, {
    bool requestAuthorizationIfNeeded = false,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      await _ensureConfigured();

      if (requestAuthorizationIfNeeded) {
        final granted = await connect();
        if (!granted) return null;
      } else {
        final connected = await isConnected();
        if (!connected) {
          // Самовосстановление: если флаг stale, но доступ фактически есть,
          // не блокируем чтение шагов.
          final hasAccess = await _hasStepsReadAccess();
          if (!hasAccess) return null;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_connectedKey, true);
        }
      }

      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }

  Future<HealthConnectResult> diagnosticsForToday() async {
    try {
      await _ensureConfigured();

      final connected = await isConnected();
      if (!connected) {
        return const HealthConnectResult(
          status: HealthConnectStatus.permissionDenied,
          message:
              'Источник здоровья не подключен. Для работы нужен доступ только к данным Шаги (Steps).',
        );
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(startOfDay, now);
      if (steps == null) {
        return const HealthConnectResult(
          status: HealthConnectStatus.connected,
          message:
              'Источник подключен, доступ к Шагам выдан, но шаги за сегодня пока не получены (null). Проверьте наличие шагов в приложении Здоровье/Health Connect.',
        );
      }

      return HealthConnectResult(
        status: HealthConnectStatus.connected,
        message: 'Источник подключен. Шаги за сегодня: $steps.',
      );
    } catch (error) {
      return HealthConnectResult(
        status: HealthConnectStatus.failed,
        message: 'Диагностика здоровья завершилась ошибкой: $error',
      );
    }
  }
}
