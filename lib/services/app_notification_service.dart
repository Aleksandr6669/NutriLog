
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'profile_service.dart';
import 'notification_settings_service.dart';
import '../router.dart';

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

  final List<String> _breakfastMessages = [
    "Доброе утро! Завтрак — это топливо для великих дел. Что сегодня в меню?",
    "Проснулись — потянулись! Не забудьте внести свой полезный завтрак в NutriLog.",
    "Завтрак — самый важный прием пищи. Зарядитесь энергией и отметьте это!",
  ];

  final List<String> _lunchMessages = [
    "Время обеда! Сделайте паузу и насладитесь вкусом. Жду ваш отчет в приложении.",
    "Обед по расписанию! Поддержите свой метаболизм правильной порцией.",
    "Приятного аппетита! Что интересного сегодня на тарелке? Запишите в NutriLog.",
  ];

  final List<String> _dinnerMessages = [
    "Скоро вечер! Легкий ужин — залог крепкого сна. Что планируете?",
    "Время ужинать. Подведем итоги дня? Добавьте последний прием пищи.",
    "Ваш организм скажет 'спасибо' за сбалансированный ужин. Не забудьте отметить!",
  ];

  final List<String> _weightMessages = [
    "Пора на весы! Помните: цифра — это просто данные для прогресса. Внесите их.",
    "Время контрольного взвешивания. Фиксируем результат и идем дальше!",
    "Дисциплина — ключ к успеху. Один замер веса приблизит вас к цели.",
  ];

  final List<String> _waterMessages = [
    "Глоток свежести! Пора попить воды.",
    "Ваши клетки просят влаги. Небольшой стакан воды?",
    "H2O — ваш лучший друг. Увлажняемся!",
    "Чувствуете усталость? Возможно, пора выпить немного воды.",
    "Водный баланс — залог красоты и здоровья. Пьем?",
    "Не ждите жажды, попейте сейчас!",
    "Чистая вода — чистая энергия. Сделайте пару глотков.",
    "Напоминание: стакан воды сделает ваш день лучше.",
    "Вода — это жизнь. Не забудьте про свой стакан!",
    "Время освежиться и пополнить запасы воды.",
  ];

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

    // Сброс счетчика и уведомлений при первой инициализации
    await resetBadge();
  }

  /// Сбрасывает счетчик на иконке и убирает все уведомления из шторки.
  Future<void> resetBadge() async {
    if (kIsWeb) return;
    try {
      await AwesomeNotifications().setGlobalBadgeCounter(0);
      await AwesomeNotifications().dismissAllNotifications();
    } catch (e) {
      debugPrint('Error resetting badge: $e');
    }
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
        settings.waterReminderEnabled || settings.mealRemindersEnabled || settings.weightReminderEnabled;
    if (!hasEnabledReminders) return;

    final granted = await _requestPermissions();
    if (!granted) {
      throw const NotificationPermissionDeniedException(
        'Разрешение на уведомления не выдано. Если пункта NutriLog нет в Настройках iPhone, удалите и установите приложение заново, затем снова включите уведомления. Также проверьте Фокус и Сводку уведомлений.',
      );
    }

    if (settings.waterReminderEnabled) {
      await _scheduleWaterReminders();
    }

    // Добавляем напоминание о взвешивании, если включено
    if (settings.weightReminderEnabled) {
      final hour = settings.weightReminderTime.hour;
      final minute = settings.weightReminderTime.minute;
      final body = _weightMessages[DateTime.now().millisecond % _weightMessages.length];
      
      await _scheduleDaily(
        id: 1200,
        title: 'Взвешивание',
        body: body,
        hour: hour,
        minute: minute,
      );
    }

    if (settings.mealRemindersEnabled) {
      final breakfastBody = _breakfastMessages[DateTime.now().millisecond % _breakfastMessages.length];
      await _scheduleDaily(
        id: _breakfastId,
        title: 'Время завтрака',
        body: breakfastBody,
        hour: settings.breakfastTime.hour,
        minute: settings.breakfastTime.minute,
      );
      
      final lunchBody = _lunchMessages[(DateTime.now().millisecond + 1) % _lunchMessages.length];
      await _scheduleDaily(
        id: _lunchId,
        title: 'Время обеда',
        body: lunchBody,
        hour: settings.lunchTime.hour,
        minute: settings.lunchTime.minute,
      );
      
      final dinnerBody = _dinnerMessages[(DateTime.now().millisecond + 2) % _dinnerMessages.length];
      await _scheduleDaily(
        id: _dinnerId,
        title: 'Время ужина',
        body: dinnerBody,
        hour: settings.dinnerTime.hour,
        minute: settings.dinnerTime.minute,
      );
    }
  }

  Future<int> _scheduleWaterReminders() async {
    // Уведомление каждый час с завтрака до ужина
    const hours = _waterEndHour - _waterStartHour;
    var scheduledCount = 0;
    for (var i = 0; i < hours; i++) {
      final hour = _waterStartHour + i;
      final body = _waterMessages[i % _waterMessages.length];
      
      await _scheduleDaily(
        id: _waterBaseId + i,
        title: 'Пора попить воды',
        body: body,
        hour: hour,
        minute: 0,
      );
      scheduledCount++;
    }
    return scheduledCount;
  }

 
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

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    if (kIsWeb) return;
    final id = receivedAction.id;
    if (id != null) {
      // Уменьшаем счетчик на иконке при нажатии на конкретное уведомление
      AwesomeNotifications().decrementGlobalBadgeCounter();
      // Убираем только это уведомление из шторки
      AwesomeNotifications().dismiss(id);
    }

    if (id == _breakfastId) {
      appRouter.push('/meal/breakfast');
    } else if (id == _lunchId) {
      appRouter.push('/meal/lunch');
    } else if (id == _dinnerId) {
      appRouter.push('/meal/dinner');
    } else if (id == 1200) {
      appRouter.push('/weight', extra: {'date': DateTime.now()});
    } else if (id != null && id >= _waterBaseId && id < _waterBaseId + _maxWaterReminders) {
      appRouter.go('/home?scrollTo=water');
    } else {
      appRouter.go('/home');
    }
  }
}
