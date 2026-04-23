import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool waterReminderEnabled;
  final TimeOfDay waterReminderTime;
  final bool mealRemindersEnabled;
  final TimeOfDay breakfastTime;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  final bool messagesEnabled; // Новое поле для сообщений

  const NotificationSettings({
    required this.waterReminderEnabled,
    required this.waterReminderTime,
    required this.mealRemindersEnabled,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.messagesEnabled,
  });

  NotificationSettings copyWith({
    bool? waterReminderEnabled,
    TimeOfDay? waterReminderTime,
    bool? mealRemindersEnabled,
    TimeOfDay? breakfastTime,
    TimeOfDay? lunchTime,
    TimeOfDay? dinnerTime,
    bool? messagesEnabled,
  }) {
    return NotificationSettings(
      waterReminderEnabled: waterReminderEnabled ?? this.waterReminderEnabled,
      waterReminderTime: waterReminderTime ?? this.waterReminderTime,
      mealRemindersEnabled: mealRemindersEnabled ?? this.mealRemindersEnabled,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
    );
  }
}

class NotificationSettingsService {
  static const _waterEnabledKey = 'notif_water_enabled';
  static const _waterMinutesKey = 'notif_water_minutes';
  static const _mealsEnabledKey = 'notif_meals_enabled';
  static const _breakfastMinutesKey = 'notif_breakfast_minutes';
  static const _lunchMinutesKey = 'notif_lunch_minutes';
  static const _dinnerMinutesKey = 'notif_dinner_minutes';
  static const _messagesEnabledKey = 'notif_messages_enabled'; // Новый ключ

  static const NotificationSettings defaults = NotificationSettings(
    waterReminderEnabled: false,
    waterReminderTime: TimeOfDay(hour: 10, minute: 0),
    mealRemindersEnabled: false,
    breakfastTime: TimeOfDay(hour: 8, minute: 30),
    lunchTime: TimeOfDay(hour: 13, minute: 0),
    dinnerTime: TimeOfDay(hour: 19, minute: 0),
    messagesEnabled: false, // Значение по умолчанию
  );

  Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      waterReminderEnabled:
          prefs.getBool(_waterEnabledKey) ?? defaults.waterReminderEnabled,
      waterReminderTime: _fromMinutes(
        prefs.getInt(_waterMinutesKey) ??
            _toMinutes(defaults.waterReminderTime),
      ),
      mealRemindersEnabled:
          prefs.getBool(_mealsEnabledKey) ?? defaults.mealRemindersEnabled,
      breakfastTime: _fromMinutes(
        prefs.getInt(_breakfastMinutesKey) ??
            _toMinutes(defaults.breakfastTime),
      ),
      lunchTime: _fromMinutes(
        prefs.getInt(_lunchMinutesKey) ?? _toMinutes(defaults.lunchTime),
      ),
      dinnerTime: _fromMinutes(
        prefs.getInt(_dinnerMinutesKey) ?? _toMinutes(defaults.dinnerTime),
      ),
      messagesEnabled:
          prefs.getBool(_messagesEnabledKey) ?? defaults.messagesEnabled,
    );
  }

  Future<void> save(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_waterEnabledKey, settings.waterReminderEnabled);
    await prefs.setInt(
        _waterMinutesKey, _toMinutes(settings.waterReminderTime));
    await prefs.setBool(_mealsEnabledKey, settings.mealRemindersEnabled);
    await prefs.setInt(
        _breakfastMinutesKey, _toMinutes(settings.breakfastTime));
    await prefs.setInt(_lunchMinutesKey, _toMinutes(settings.lunchTime));
    await prefs.setInt(_dinnerMinutesKey, _toMinutes(settings.dinnerTime));
  }

  Future<void> updateMessagesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messagesEnabledKey, enabled);
  }

  static int _toMinutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static TimeOfDay _fromMinutes(int minutes) {
    final normalized = minutes % (24 * 60);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }
}
