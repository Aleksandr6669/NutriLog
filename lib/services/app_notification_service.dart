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

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    await _configureTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(_resolveTimezoneLocation(localTimezone));
    } catch (_) {
      // Не форсируем UTC: это сдвигает локальные напоминания по времени.
      // Оставляем стандартную локаль timezone пакета как есть.
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
            return tz.local;
          }
        }
      }
      return tz.local;
    }
  }

  Future<bool> _requestPermissions() async {
    var androidGranted = true;
    var iosGranted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (Platform.isAndroid) {
      androidGranted = await android?.requestNotificationsPermission() ?? true;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (Platform.isIOS) {
      iosGranted = await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }

    _permissionsGranted = androidGranted && iosGranted;
    return _permissionsGranted;
  }

  Future<void> applySettings(NotificationSettings settings) async {
    if (kIsWeb) return;

    await initialize();

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
        'Разрешение на уведомления не выдано. Откройте настройки iPhone и включите уведомления для NutriLog.',
      );
    }

    if (settings.waterReminderEnabled) {
      await _scheduleWaterReminders();
    }

    if (settings.mealRemindersEnabled) {
      await _scheduleDaily(
        id: _breakfastId,
        title: 'Время завтрака',
        body: 'Добавьте прием пищи в дневник, чтобы не терять статистику.',
        hour: settings.breakfastTime.hour,
        minute: settings.breakfastTime.minute,
      );
      await _scheduleDaily(
        id: _lunchId,
        title: 'Время обеда',
        body: 'Напоминание: отметьте обед в NutriLog.',
        hour: settings.lunchTime.hour,
        minute: settings.lunchTime.minute,
      );
      await _scheduleDaily(
        id: _dinnerId,
        title: 'Время ужина',
        body: 'Пора проверить дневник и добавить ужин.',
        hour: settings.dinnerTime.hour,
        minute: settings.dinnerTime.minute,
      );
    }
  }

  Future<void> _scheduleWaterReminders() async {
    final profile = await _profileService.loadProfile();
    final dailyWaterGoalMl = profile.waterGoal;

    // Планируем равномерные напоминания в активное дневное окно.
    final reminderCount =
        (dailyWaterGoalMl / 250).ceil().clamp(3, _maxWaterReminders);
    const totalMinutes = (_waterEndHour - _waterStartHour) * 60;
    final intervalMinutes =
        math.max(45, (totalMinutes / reminderCount).floor());
    final amountPerReminderMl =
        ((dailyWaterGoalMl / reminderCount) / 10).round() * 10;
    final safeAmountPerReminderMl = math.max(100, amountPerReminderMl);

    for (var i = 0; i < reminderCount; i++) {
      final minutesFromStart = i * intervalMinutes;
      final hour = _waterStartHour + (minutesFromStart ~/ 60);
      final minute = minutesFromStart % 60;
      if (hour >= _waterEndHour) break;

      await _scheduleDaily(
        id: _waterBaseId + i,
        title: 'Пора выпить воду',
        body:
            'Выпейте около $safeAmountPerReminderMl мл. План на день: $dailyWaterGoalMl мл, $reminderCount напоминаний.',
        hour: hour,
        minute: minute,
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'nutrilog_reminders',
      'NutriLog напоминания',
      channelDescription: 'Напоминания о воде и приемах пищи',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
