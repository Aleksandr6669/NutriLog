import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ProfileService _profileService = ProfileService();
  static bool _initialized = false;
  bool _permissionsGranted = true;

  /// Инициализирует сервис уведомлений один раз в жизни приложения.
  /// Настраивает таймзону локально и Android/iOS детали.
  ///
  /// Таймзона инициализируется один раз и сохраняется в tz.local для всех
  /// последующих планирований. Это критично для точности времени уведомлений.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    await _configureTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      // Как в официальном примере плагина: запрашиваем права явно,
      // когда пользователь включает уведомления в интерфейсе.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Настраивает таймзону для всего приложения.
  ///
  /// Сначала пытается получить IANA timezone ID от системы. Если ошибка
  /// (особенно на iOS, который иногда возвращает GMT+3 вместо IANA),
  /// конвертирует GMT-смещение в Etc/GMT форму.
  ///
  /// Fallback: если и это не сработает, использует локальный UTC-offset
  /// (например, UTC+3). Это гарантирует, что уведомления придут хоть в какую-то
  /// корректную временную зону, а не с произвольным сдвигом.
  Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(_resolveTimezoneLocation(localTimezone));
    } catch (_) {
      // Fallback: используем оффсет устройства, чтобы избежать сдвига напоминаний
      // (например, вместо 8:00 не приходило 10:00 из-за неправильной таймзоны).
      tz.setLocalLocation(_locationFromOffset(DateTime.now().timeZoneOffset));
    }
  }

  tz.Location _resolveTimezoneLocation(String rawTimezone) {
    final timezone = rawTimezone.trim();
    if (timezone.isEmpty) return tz.local;

    try {
      return tz.getLocation(timezone);
    } catch (_) {
      // iOS иногда возвращает смещение в формате GMT+3 / UTC+03:00.
      final match = RegExp(r'^(?:GMT|UTC)\s*([+-])(\d{1,2})(?::?(\d{2}))?$')
          .firstMatch(timezone.toUpperCase());
      if (match != null) {
        final sign = match.group(1)!;
        final hour = int.tryParse(match.group(2) ?? '0') ?? 0;
        final minute = int.tryParse(match.group(3) ?? '0') ?? 0;
        if (minute == 0 && hour <= 14) {
          // В базе Etc/GMT знак инвертирован.
          final etcSign = sign == '+' ? '-' : '+';
          final etcName = hour == 0 ? 'Etc/GMT' : 'Etc/GMT$etcSign$hour';
          try {
            return tz.getLocation(etcName);
          } catch (_) {
            return _locationFromOffset(DateTime.now().timeZoneOffset);
          }
        }
      }
      return _locationFromOffset(DateTime.now().timeZoneOffset);
    }
  }

  tz.Location _locationFromOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final absMinutes = totalMinutes.abs();
    final hour = absMinutes ~/ 60;
    final minute = absMinutes % 60;

    // Для нестандартных зон с минутами (например, +05:30) используем UTC,
    // чтобы не выставить неверную зону из базы Etc/GMT.
    if (minute != 0 || hour > 14) return tz.UTC;

    if (hour == 0) {
      return tz.getLocation('Etc/GMT');
    }

    // В базе Etc/GMT знак инвертирован:
    // UTC+3 -> Etc/GMT-3, UTC-4 -> Etc/GMT+4.
    final sign = totalMinutes >= 0 ? '-' : '+';
    return tz.getLocation('Etc/GMT$sign$hour');
  }

  Future<bool> _requestPermissions() async {
    var androidGranted = true;
    var iosGranted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (Platform.isAndroid) {
      if (android == null) {
        androidGranted = false;
      } else {
        androidGranted = await android.requestNotificationsPermission() ?? true;
        final enabledAfterRequest = await android.areNotificationsEnabled();
        androidGranted = androidGranted && (enabledAfterRequest ?? true);
      }
      // Для Android 14+ exact alarm может требовать отдельного разрешения.
      // Если не получится получить, ниже в планировании сработает fallback на inexact.
      try {
        await android?.requestExactAlarmsPermission();
      } catch (_) {
        // Игнорируем, чтобы не блокировать уведомления полностью.
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (Platform.isIOS) {
      if (ios == null) {
        iosGranted = false;
      } else {
        // Запрашиваем разрешение напрямую как в примере плагина.
        final requested = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;

        if (requested) {
          iosGranted = true;
        } else {
          final afterRequest = await ios.checkPermissions();
          iosGranted = (afterRequest?.isEnabled ?? false) &&
              ((afterRequest?.isAlertEnabled ?? false) ||
                  (afterRequest?.isProvisionalEnabled ?? false));
        }
      }
    }

    _permissionsGranted = androidGranted && iosGranted;
    return _permissionsGranted;
  }

  Future<void> applySettings(NotificationSettings settings) async {
    if (kIsWeb) return;

    await initialize();
    // На случай смены часового пояса после запуска приложения.
    await _configureTimezone();

    for (var i = 0; i < _maxWaterReminders; i++) {
      await _plugin.cancel(_waterBaseId + i);
    }
    await _plugin.cancel(_breakfastId);
    await _plugin.cancel(_lunchId);
    await _plugin.cancel(_dinnerId);

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

    final pending = await _plugin.pendingNotificationRequests();
    final hasScheduled = pending.any(
      (request) => request.id >= _waterBaseId && request.id <= _dinnerId,
    );

    // На Android отсутствие pending сразу после планирования чаще означает реальную
    // проблему (разрешения/энергосбережение). На iOS список pending может обновляться
    // не мгновенно, поэтому не делаем жёсткий fail и не откатываем настройки.
    if (scheduledCount > 0 && !hasScheduled && Platform.isAndroid) {
      throw const NotificationScheduleException(
        'Не удалось запланировать уведомления. Проверьте системные разрешения и режим энергосбережения.',
      );
    }
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
    final scheduled = tz.TZDateTime.from(localTarget, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'nutrilog_reminders',
      'NutriLog напоминания',
      channelDescription: 'Напоминания о воде и приемах пищи',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    // Сначала пытаемся поставить более надежный exact режим на Android,
    // при ошибке (например, нет exact-alarm разрешения) откатываемся на inexact.
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<int> getPendingReminderCount() async {
    if (kIsWeb) return 0;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .where(
            (request) => request.id >= _waterBaseId && request.id <= _dinnerId)
        .length;
  }

  /// Возвращает имя текущей таймзоны (например, 'Europe/Moscow', 'Etc/GMT-3').
  /// Полезно для диагностики и логирования.
  String getCurrentTimezoneName() {
    return tz.local.name;
  }

  /// Возвращает детальный статус разрешений уведомлений по платформе.
  /// Нужен для быстрой диагностики на реальном устройстве.
  Future<String> getPermissionDiagnostics() async {
    if (kIsWeb) return 'Платформа: web (системные права не применяются).';

    await initialize();

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios == null) {
        return 'iOS implementation: недоступен (ios == null).';
      }

      final perms = await ios.checkPermissions();
      if (perms == null) {
        return 'iOS permissions: checkPermissions() вернул null.';
      }

      return 'iOS permissions:\n'
          'isEnabled=${perms.isEnabled}\n'
          'isAlertEnabled=${perms.isAlertEnabled}\n'
          'isBadgeEnabled=${perms.isBadgeEnabled}\n'
          'isSoundEnabled=${perms.isSoundEnabled}\n'
          'isProvisionalEnabled=${perms.isProvisionalEnabled}\n'
          'isCriticalEnabled=${perms.isCriticalEnabled}';
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) {
        return 'Android implementation: недоступен (android == null).';
      }

      final enabled = await android.areNotificationsEnabled();
      return 'Android permissions:\n'
          'notificationsEnabled=${enabled ?? false}\n'
          'exactAlarmPermission=см. системные настройки (может требоваться на Android 14+)';
    }

    return 'Платформа ${Platform.operatingSystem}: отдельная диагностика не реализована.';
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
