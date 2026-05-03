import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

  static bool _initialized = false;

  Future<String> _getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    if (saved == 'ru' || saved == 'uk' || saved == 'en') {
      return saved!;
    }
    final system = ui.PlatformDispatcher.instance.locale.languageCode;
    if (system == 'ru' || system == 'uk' || system == 'en') {
      return system;
    }
    return 'en';
  }

  List<String> _breakfastMessages(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Доброе утро! Завтрак — это топливо для великих дел. Что сегодня в меню?',
          'Проснулись — потянулись! Не забудьте внести свой полезный завтрак в NutriLog.',
          'Завтрак — самый важный прием пищи. Зарядитесь энергией и отметьте это!',
        ];
      case 'uk':
        return const [
          'Доброго ранку! Сніданок — це паливо для великих справ. Що сьогодні в меню?',
          'Прокинулись — потягнулись! Не забудьте додати свій корисний сніданок у NutriLog.',
          'Сніданок — найважливіший прийом їжі. Зарядіться енергією та відмітьте це!',
        ];
      default:
        return const [
          'Good morning! Breakfast is the fuel for a great day. What is on your menu today?',
          'Up and stretching! Do not forget to log your healthy breakfast in NutriLog.',
          'Breakfast is the most important meal of the day. Fuel up and log it!',
        ];
    }
  }

  List<String> _lunchMessages(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Время обеда! Сделайте паузу и насладитесь вкусом. Жду ваш отчет в приложении.',
          'Обед по расписанию! Поддержите свой метаболизм правильной порцией.',
          'Приятного аппетита! Что интересного сегодня на тарелке? Запишите в NutriLog.',
        ];
      case 'uk':
        return const [
          'Час обіду! Зробіть паузу та насолодіться смаком. Чекаю ваш запис у застосунку.',
          'Обід за розкладом! Підтримайте свій метаболізм правильною порцією.',
          'Смачного! Що цікавого сьогодні на тарілці? Запишіть у NutriLog.',
        ];
      default:
        return const [
          'Lunch time! Take a break and enjoy your meal. I am waiting for your log in the app.',
          'Lunch on schedule! Support your metabolism with the right portion.',
          'Enjoy your meal! What is on your plate today? Log it in NutriLog.',
        ];
    }
  }

  List<String> _dinnerMessages(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Скоро вечер! Легкий ужин — залог крепкого сна. Что планируете?',
          'Время ужинать. Подведем итоги дня? Добавьте последний прием пищи.',
          'Ваш организм скажет спасибо за сбалансированный ужин. Не забудьте отметить!',
        ];
      case 'uk':
        return const [
          'Вечір наближається! Легка вечеря — запорука міцного сну. Що плануєте?',
          'Час вечеряти. Підбиваємо підсумки дня? Додайте останній прийом їжі.',
          'Ваш організм скаже дякую за збалансовану вечерю. Не забудьте відмітити!',
        ];
      default:
        return const [
          'Evening is coming! A light dinner supports better sleep. What is your plan?',
          'Dinner time. Shall we wrap up the day? Add your last meal.',
          'Your body will thank you for a balanced dinner. Do not forget to log it!',
        ];
    }
  }

  List<String> _weightMessages(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Пора на весы! Помните: цифра — это просто данные для прогресса. Внесите их.',
          'Время контрольного взвешивания. Фиксируем результат и идем дальше!',
          'Дисциплина — ключ к успеху. Один замер веса приблизит вас к цели.',
        ];
      case 'uk':
        return const [
          'Час на ваги! Памятайте: цифра — це лише дані для прогресу. Додайте їх.',
          'Час контрольного зважування. Фіксуємо результат і рухаємось далі!',
          'Дисципліна — ключ до успіху. Одне зважування наблизить вас до цілі.',
        ];
      default:
        return const [
          'Time to step on the scale! Remember: the number is just data for progress. Log it.',
          'Check-in weigh-in time. Record the result and keep going!',
          'Discipline is the key to success. One weigh-in gets you closer to your goal.',
        ];
    }
  }

  List<String> _waterMessages(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Глоток свежести! Пора попить воды.',
          'Ваши клетки просят влаги. Небольшой стакан воды?',
          'H2O — ваш лучший друг. Увлажняемся!',
          'Чувствуете усталость? Возможно, пора выпить немного воды.',
          'Водный баланс — залог красоты и здоровья. Пьем?',
          'Не ждите жажды, попейте сейчас!',
          'Чистая вода — чистая энергия. Сделайте пару глотков.',
          'Напоминание: стакан воды сделает ваш день лучше.',
          'Вода — это жизнь. Не забудьте про свой стакан!',
          'Время освежиться и пополнить запасы воды.',
        ];
      case 'uk':
        return const [
          'Ковток свіжості! Час попити води.',
          'Ваші клітини просять вологи. Невелика склянка води?',
          'H2O — ваш найкращий друг. Зволожуємось!',
          'Відчуваєте втому? Можливо, час випити трохи води.',
          'Водний баланс — запорука краси і здоровя. Пємо?',
          'Не чекайте спраги, попийте зараз!',
          'Чиста вода — чиста енергія. Зробіть пару ковтків.',
          'Нагадування: склянка води зробить ваш день кращим.',
          'Вода — це життя. Не забудьте про свою склянку!',
          'Час освіжитися і поповнити запаси води.',
        ];
      default:
        return const [
          'A refreshing sip! Time to drink some water.',
          'Your cells need hydration. How about a small glass of water?',
          'H2O is your best friend. Stay hydrated!',
          'Feeling tired? It might be time to drink some water.',
          'Water balance is key to health and beauty. Drink now?',
          'Do not wait for thirst, drink now!',
          'Clean water means clean energy. Take a couple of sips.',
          'Reminder: a glass of water can make your day better.',
          'Water is life. Do not forget your glass!',
          'Time to refresh and refill your water balance.',
        ];
    }
  }

  /// Инициализирует сервис уведомлений один раз в жизни приложения.
  /// Настраивает таймзону локально и Android/iOS детали.
  ///
  /// Таймзона инициализируется один раз и сохраняется в tz.local для всех
  /// последующих планирований. Это критично для точности времени уведомлений.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    final lang = await _getLanguageCode();
    await AwesomeNotifications().initialize(
      'resource://mipmap/launcher_icon',
      [
        NotificationChannel(
          channelKey: 'nutrilog_reminders',
          channelName: lang == 'ru'
              ? 'NutriLog напоминания'
              : lang == 'uk'
                  ? 'NutriLog нагадування'
                  : 'NutriLog reminders',
          channelDescription: lang == 'ru'
              ? 'Напоминания о воде и приемах пищи'
              : lang == 'uk'
                  ? 'Нагадування про воду та прийоми їжі'
                  : 'Water and meal reminders',
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

    final lang = await _getLanguageCode();
    final breakfastMessages = _breakfastMessages(lang);
    final lunchMessages = _lunchMessages(lang);
    final dinnerMessages = _dinnerMessages(lang);
    final weightMessages = _weightMessages(lang);

    // При изменении цели воды пересоздаём все water-уведомления
    for (var i = 0; i < _maxWaterReminders; i++) {
      await AwesomeNotifications().cancel(_waterBaseId + i);
    }
    await AwesomeNotifications().cancel(_breakfastId);
    await AwesomeNotifications().cancel(_lunchId);
    await AwesomeNotifications().cancel(_dinnerId);
    await AwesomeNotifications().cancel(1200);

    final hasEnabledReminders = settings.waterReminderEnabled ||
        settings.mealRemindersEnabled ||
        settings.weightReminderEnabled;
    if (!hasEnabledReminders) return;

    final granted = await _requestPermissions();
    if (!granted) {
      throw NotificationPermissionDeniedException(
        lang == 'ru'
            ? 'Разрешение на уведомления не выдано. Если пункта NutriLog нет в Настройках iPhone, удалите и установите приложение заново, затем снова включите уведомления. Также проверьте Фокус и Сводку уведомлений.'
            : lang == 'uk'
                ? 'Дозвіл на сповіщення не надано. Якщо пункту NutriLog немає в Налаштуваннях iPhone, видаліть і встановіть застосунок знову, а потім знову увімкніть сповіщення. Також перевірте Фокус і Зведення сповіщень.'
                : 'Notification permission is not granted. If NutriLog does not appear in iPhone Settings, reinstall the app and enable notifications again. Also check Focus and Notification Summary settings.',
      );
    }

    if (settings.waterReminderEnabled) {
      await _scheduleWaterReminders(lang);
    }

    // Добавляем напоминание о взвешивании, если включено
    if (settings.weightReminderEnabled) {
      final hour = settings.weightReminderTime.hour;
      final minute = settings.weightReminderTime.minute;
      final body =
          weightMessages[DateTime.now().millisecond % weightMessages.length];

      await _scheduleDaily(
        id: 1200,
        title: lang == 'ru'
            ? 'Взвешивание'
            : lang == 'uk'
                ? 'Зважування'
                : 'Weigh-in',
        body: body,
        hour: hour,
        minute: minute,
      );
    }

    if (settings.mealRemindersEnabled) {
      final breakfastBody = breakfastMessages[
          DateTime.now().millisecond % breakfastMessages.length];
      await _scheduleDaily(
        id: _breakfastId,
        title: lang == 'ru'
            ? 'Время завтрака'
            : lang == 'uk'
                ? 'Час сніданку'
                : 'Breakfast time',
        body: breakfastBody,
        hour: settings.breakfastTime.hour,
        minute: settings.breakfastTime.minute,
      );

      final lunchBody = lunchMessages[
          (DateTime.now().millisecond + 1) % lunchMessages.length];
      await _scheduleDaily(
        id: _lunchId,
        title: lang == 'ru'
            ? 'Время обеда'
            : lang == 'uk'
                ? 'Час обіду'
                : 'Lunch time',
        body: lunchBody,
        hour: settings.lunchTime.hour,
        minute: settings.lunchTime.minute,
      );

      final dinnerBody = dinnerMessages[
          (DateTime.now().millisecond + 2) % dinnerMessages.length];
      await _scheduleDaily(
        id: _dinnerId,
        title: lang == 'ru'
            ? 'Время ужина'
            : lang == 'uk'
                ? 'Час вечері'
                : 'Dinner time',
        body: dinnerBody,
        hour: settings.dinnerTime.hour,
        minute: settings.dinnerTime.minute,
      );
    }
  }

  Future<int> _scheduleWaterReminders(String lang) async {
    // Уведомление каждый час с завтрака до ужина
    const hours = _waterEndHour - _waterStartHour;
    final waterMessages = _waterMessages(lang);
    var scheduledCount = 0;
    for (var i = 0; i < hours; i++) {
      final hour = _waterStartHour + i;
      final body = waterMessages[i % waterMessages.length];

      await _scheduleDaily(
        id: _waterBaseId + i,
        title: lang == 'ru'
            ? 'Пора попить воды'
            : lang == 'uk'
                ? 'Час попити води'
                : 'Time to drink water',
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
    final lang = await _getLanguageCode();
    if (kIsWeb) {
      return lang == 'ru'
          ? 'Платформа: web (системные права не применяются).'
          : lang == 'uk'
              ? 'Платформа: web (системні дозволи не застосовуються).'
              : 'Platform: web (system permissions are not applicable).';
    }
    await initialize();
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (allowed) {
      return lang == 'ru'
          ? 'Разрешения на уведомления: ВЫДАНЫ'
          : lang == 'uk'
              ? 'Дозволи на сповіщення: НАДАНІ'
              : 'Notification permissions: GRANTED';
    }
    return lang == 'ru'
        ? 'Разрешения на уведомления: НЕ ВЫДАНЫ'
        : lang == 'uk'
            ? 'Дозволи на сповіщення: НЕ НАДАНІ'
            : 'Notification permissions: NOT GRANTED';
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
    final lang = await _getLanguageCode();
    if (kIsWeb) {
      return lang == 'ru'
          ? 'Web platform: zonedSchedule не поддерживается.'
          : lang == 'uk'
              ? 'Web platform: zonedSchedule не підтримується.'
              : 'Web platform: zonedSchedule is not supported.';
    }

    final timezoneName = getCurrentTimezoneName();
    final pendingCount = await getPendingReminderCount();
    final now = DateTime.now();

    final timeText = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    if (lang == 'ru') {
      return 'Таймзона: $timezoneName\n'
          'Локальное время: $timeText\n'
          'Запланировано уведомлений: $pendingCount\n'
          '(waterReminders: 0-19, breakfast: 1101, lunch: 1102, dinner: 1103)';
    }
    if (lang == 'uk') {
      return 'Таймзона: $timezoneName\n'
          'Локальний час: $timeText\n'
          'Заплановано сповіщень: $pendingCount\n'
          '(waterReminders: 0-19, breakfast: 1101, lunch: 1102, dinner: 1103)';
    }
    return 'Timezone: $timezoneName\n'
        'Local time: $timeText\n'
        'Scheduled notifications: $pendingCount\n'
        '(waterReminders: 0-19, breakfast: 1101, lunch: 1102, dinner: 1103)';
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    if (kIsWeb) return;
    final id = receivedAction.id;
    debugPrint(
        'NOTIFICATION_CLICKED: id=$id, payload=${receivedAction.payload}');

    if (id != null) {
      // Уменьшаем счетчик на иконке при нажатии на конкретное уведомление
      AwesomeNotifications().decrementGlobalBadgeCounter();
      // Убираем только это уведомление из шторки
      AwesomeNotifications().dismiss(id);
    }

    if (id == _breakfastId) {
      debugPrint('NAVIGATING_TO: /meal/breakfast');
      handleAppDeepLink('/meal/breakfast');
    } else if (id == _lunchId) {
      debugPrint('NAVIGATING_TO: /meal/lunch');
      handleAppDeepLink('/meal/lunch');
    } else if (id == _dinnerId) {
      debugPrint('NAVIGATING_TO: /meal/dinner');
      handleAppDeepLink('/meal/dinner');
    } else if (id == 1200) {
      debugPrint('NAVIGATING_TO: /weight');
      handleAppDeepLink('/weight', {'date': DateTime.now()});
    } else if (id != null &&
        id >= _waterBaseId &&
        id < _waterBaseId + _maxWaterReminders) {
      debugPrint('NAVIGATING_TO: /home?scrollTo=water');
      handleAppDeepLink('/home?scrollTo=water');
    } else {
      debugPrint('NAVIGATING_TO: /home (default)');
      handleAppDeepLink('/home');
    }
  }
}
