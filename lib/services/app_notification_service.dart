import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'profile_service.dart';
import 'notification_settings_service.dart';

class NotificationPermissionDeniedException implements Exception {
  final String message;

  const NotificationPermissionDeniedException(this.message);

  @override
  String toString() => message;
}

class NotificationScheduleException implements Exception {
  final String message;

  const NotificationScheduleException(this.message);

  @override
  String toString() => message;
}

class AppNotificationService {
  static const int _waterBaseId = 1000;
  static const int _maxWaterReminders = 20;
  static const int _breakfastId = 1101;
  static const int _lunchId = 1102;
  static const int _dinnerId = 1103;
  static const int _waterStartHour = 8;
  static const int _waterEndHour = 22;

  final ProfileService _profileService = ProfileService();
  static bool _initialized = false;

  /// Инициализирует сервис уведомлений один раз в жизни приложения.
  /// Настраивает таймзону локально и Android/iOS детали.
  ///
  /// Таймзона инициализируется один раз и сохраняется в tz.local для всех
  /// последующих планирований. Это критично для точности времени уведомлений.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    await AwesomeNotifications().initialize(
      'resource://mipmap/launcher_icon',
      [
        NotificationChannel(
          channelKey: 'nutrilog_reminders',
          channelName: 'NutriLog напоминания',
          channelDescription: 'Напоминания о воде и приемах пищи',
          defaultColor: const Color(0xFF2196F3),
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
      debug: false,
    );
    _initialized = true;
  }

  Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    tz.Location? location;
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      location = _resolveTimezoneLocation(localTimezone);
    } catch (_) {}
    tz.setLocalLocation(location ?? tz.UTC);
  }

  tz.Location _resolveTimezoneLocation(String rawTimezone) {
    // Всегда используем смещение устройства, игнорируя имя таймзоны
    return _locationFromOffset(DateTime.now().timeZoneOffset);
  }

  tz.Location _locationFromOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final absMinutes = totalMinutes.abs();
    final hour = absMinutes ~/ 60;
    final minute = absMinutes % 60;

    // Для нестандартных зон с минутами (например, +05:30) используем UTC,
    // чтобы не выставить неверную зону из базы Etc/GMT.
    if (minute != 0 || hour > 14) {
      return tz.UTC;
    }

    if (hour == 0) {
      return tz.getLocation('Etc/GMT');
    }

    final sign = totalMinutes >= 0 ? '-' : '+';
    return tz.getLocation('Etc/GMT$sign$hour');
  }

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return false;
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed =
          await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return isAllowed;
  }

  Future<void> applySettings(NotificationSettings settings) async {
    if (kIsWeb) return;

    await initialize();
    // На случай смены часового пояса после запуска приложения.
    await _configureTimezone();

    // При изменении цели воды пересоздаём все water-уведомления
    for (var i = 0; i < _maxWaterReminders; i++) {
      await AwesomeNotifications().cancel(_waterBaseId + i);
    }
    await AwesomeNotifications().cancel(_breakfastId);
    await AwesomeNotifications().cancel(_lunchId);
    await AwesomeNotifications().cancel(_dinnerId);
    await AwesomeNotifications().cancel(1200);

    final hasEnabledReminders =
        settings.waterReminderEnabled || settings.mealRemindersEnabled;
    if (!hasEnabledReminders) return;

    final granted = await _requestPermissions();
    if (!granted) {
      throw const NotificationPermissionDeniedException(
        'Разрешение на уведомления не выдано. Если пункта NutriLog нет в Настройках iPhone, удалите и установите приложение заново, затем снова включите уведомления. Также проверьте Фокус и Сводку уведомлений.',
      );
    }

    var scheduledCount = 0;

    if (settings.waterReminderEnabled) {
      scheduledCount += await _scheduleWaterReminders();
    }

    // Добавляем напоминание о взвешивании, если включено
    if (settings.weightReminderEnabled) {
      final hour = settings.weightReminderTime.hour;
      final minute = settings.weightReminderTime.minute;
      final timeStr =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      await _scheduleDaily(
        id: 1200,
        title: 'Взвешивание',
        body:
            'Не забудьте внести свой вес в дневник NutriLog! Время напоминания: $timeStr',
        hour: hour,
        minute: minute,
      );
    }

    if (settings.mealRemindersEnabled) {
      await _scheduleDaily(
        id: _breakfastId,
        title: 'Время завтрака',
        body: 'Добавьте прием пищи в дневник, чтобы не терять статистику.',
        hour: settings.breakfastTime.hour,
        minute: settings.breakfastTime.minute,
      );
      scheduledCount++;
      await _scheduleDaily(
        id: _lunchId,
        title: 'Время обеда',
        body: 'Напоминание: отметьте обед в NutriLog.',
        hour: settings.lunchTime.hour,
        minute: settings.lunchTime.minute,
      );
      scheduledCount++;
      await _scheduleDaily(
        id: _dinnerId,
        title: 'Время ужина',
        body: 'Пора проверить дневник и добавить ужин.',
        hour: settings.dinnerTime.hour,
        minute: settings.dinnerTime.minute,
      );
      scheduledCount++;
    }

    // TODO: Для AwesomeNotifications нет прямого аналога pendingNotificationRequests с фильтрацией по id, но listScheduledNotifications используется ниже.
    // Можно реализовать дополнительную проверку, если потребуется.
  }

  Future<int> _scheduleWaterReminders() async {
    final profile = await _profileService.loadProfile();
    final dailyWaterGoalMl = profile.waterGoal;

    // Количество напоминаний напрямую зависит от цели воды (1 уведомление на ~250 мл).
    final reminderCount = math
        .max(1, (dailyWaterGoalMl / 250).ceil())
        .clamp(1, _maxWaterReminders);
    const totalMinutes = (_waterEndHour - _waterStartHour) * 60;
    final stepMinutes = totalMinutes / reminderCount;
    final amountPerReminderMl =
        ((dailyWaterGoalMl / reminderCount) / 10).round() * 10;
    final safeAmountPerReminderMl = math.max(100, amountPerReminderMl);

    var scheduledCount = 0;
    var previousMinuteOfDay = -1;
    for (var i = 0; i < reminderCount; i++) {
      var minutesFromStart = (i * stepMinutes).round();
      var minuteOfDay = _waterStartHour * 60 + minutesFromStart;

      // Гарантируем строго возрастающее время, чтобы не терять уведомления из-за дублей.
      if (minuteOfDay <= previousMinuteOfDay) {
        minuteOfDay = previousMinuteOfDay + 1;
      }

      const maxMinuteOfDay = (_waterEndHour * 60) - 1;
      if (minuteOfDay > maxMinuteOfDay) {
        minuteOfDay = maxMinuteOfDay;
      }

      previousMinuteOfDay = minuteOfDay;
      final hour = minuteOfDay ~/ 60;
      final minute = minuteOfDay % 60;

      await _scheduleDaily(
        id: _waterBaseId + i,
        title: 'Пора выпить воду',
        body:
            'Выпейте около $safeAmountPerReminderMl мл. План на день: $dailyWaterGoalMl мл, $reminderCount напоминаний.',
        hour: hour,
        minute: minute,
      );
      scheduledCount++;
    }

    return scheduledCount;
  }

  /// Планирует ежедневное уведомление в конкретное локальное время.
  ///
  /// Параметры:
  /// - hour, minute: локальное время устройства (например, 08:00).
  ///
  /// Критичные параметры zonedSchedule:
  /// 1. **wallClockTime**: Гарантирует, что уведомление придёт в точно
  ///    указанное время устройства. Без этого приходит в random time.
  /// 2. **matchDateTimeComponents: DateTimeComponents.time**: Делает уведомление
  ///    ежедневным повторяющимся. Система сама пересчитает next day,
  ///    не нужно ручное планирование.
  /// 3. **TZDateTime.from(localTarget, tz.local)**: Конвертирует локальное
  ///    время в TZDateTime в правильной таймзоне.
  ///
  /// Если текущее время уже позже целевого часа в сегодня,
  /// планируем на завтра (система с matchDateTimeComponents всё равно
  /// пересчитает, но явно указываем next day для безопасности).
  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final nowLocal = DateTime.now();
    var localTarget = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
      minute,
    );
    if (localTarget.isBefore(nowLocal)) {
      localTarget = localTarget.add(const Duration(days: 1));
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'nutrilog_reminders',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: localTarget.year,
        month: localTarget.month,
        day: localTarget.day,
        hour: localTarget.hour,
        minute: localTarget.minute,
        second: 0,
        millisecond: 0,
        repeats: true,
        timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
      ),
    );
  }

  Future<int> getPendingReminderCount() async {
    if (kIsWeb) return 0;
    await initialize();
    final pending = await AwesomeNotifications().listScheduledNotifications();
    return pending
        .where((request) =>
            request.content?.id != null &&
            request.content!.id! >= _waterBaseId &&
            request.content!.id! <= _dinnerId)
        .length;
  }

  /// Возвращает имя текущей таймзоны (например, 'Europe/Moscow', 'Etc/GMT-3').
  /// Полезно для диагностики и логирования.
  String getCurrentTimezoneName() {
    return tz.local.name;
  }

  /// Возвращает детальный статус разрешений уведомлений (универсально для всех платформ).
  Future<String> getPermissionDiagnostics() async {
    if (kIsWeb) return 'Платформа: web (системные права не применяются).';
    await initialize();
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    return allowed
        ? 'Разрешения на уведомления: ВЫДАНЫ'
        : 'Разрешения на уведомления: НЕ ВЫДАНЫ';
  }

  /// Явный ручной запрос разрешений уведомлений.
  /// Используется на экране настроек, когда нужно принудительно вызвать
  /// системный диалог и проверить итоговый статус.
  Future<bool> requestPermissionNow() async {
    if (kIsWeb) return false;
    await initialize();
    return _requestPermissions();
  }

  /// Диагностирует статус уведомлений: таймзона, количество запланированных.
  /// Используйте для отладки проблем с доставкой.
  Future<String> diagnosticsForToday() async {
    if (kIsWeb) return 'Web platform: zonedSchedule не поддерживается.';

    final timezoneName = getCurrentTimezoneName();
    final pendingCount = await getPendingReminderCount();
    final now = DateTime.now();

    return 'Таймзона: $timezoneName\n'
        'Локальное время: ${now.hour}:${now.minute.toString().padLeft(2, '0')}\n'
        'Запланировано уведомлений: $pendingCount\n'
        '(waterReminders: 0-19, breakfast: 1101, lunch: 1102, dinner: 1103)';
  }
}
