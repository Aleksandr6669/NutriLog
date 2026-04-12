import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/daily_log.dart';
import '../models/food_item.dart';
import 'recipe_loader.dart'; // Для доступа к маппингу иконок

class DailyLogService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Загружает и парсит весь файл журнала
  Future<Map<String, dynamic>> _loadJsonData() async {
    final jsonString = await rootBundle.loadString('assets/data/daily_log.json');
    return json.decode(jsonString) as Map<String, dynamic>;
  }

  // Загружает и парсит весь файл журнала
  Future<Map<String, DailyLog>> _loadDailyLogs() async {
    final jsonMap = await _loadJsonData();

    return jsonMap.map((dateString, logJson) {
      return MapEntry(dateString, _parseLog(dateString, logJson));
    });
  }

  DailyLog _parseLog(String dateString, Map<String, dynamic> logJson) {
     final mealsJson = logJson['meals'] as Map<String, dynamic>;
      final meals = mealsJson.map((mealName, itemsJson) {
        final items = (itemsJson as List).map((itemJson) {
          final nutrientsJson = itemJson['nutrients'];
          return FoodItem(
            icon: RecipeLoader.getIcon(itemJson['icon'] ?? ''),
            name: itemJson['name'] ?? '',
            description: itemJson['description'] ?? '',
            nutrients: NutritionalInfo.fromJson(nutrientsJson),
          );
        }).toList();
        return MapEntry(mealName, items);
      });

      return DailyLog(
        date: DateTime.parse(dateString),
        waterIntake: logJson['waterIntake'] as int? ?? 0,
        activityCalories: logJson['activityCalories'] as int? ?? 0,
        steps: logJson['steps'] as int? ?? 0,
        weight: (logJson['weight'] as num?)?.toDouble(),
        meals: meals,
      );
  }

  /// Загружает данные для конкретного дня.
  Future<DailyLog> getLogForDate(DateTime date) async {
    final allLogs = await _loadDailyLogs();
    final dateString = _dateFormat.format(date);
    return allLogs[dateString] ?? DailyLog.empty(date);
  }

  /// Возвращает множество дат, для которых есть записи в логе.
  Future<Set<DateTime>> getLoggedDates() async {
      final jsonMap = await _loadJsonData();
      return jsonMap.keys.map((dateString) => DateTime.parse(dateString)).toSet();
  }

  /// Загружает данные за указанный период (например, за неделю).
  Future<List<DailyLog>> getLogsForPeriod(DateTime startDate, DateTime endDate) async {
    final allLogs = await _loadDailyLogs();
    final logs = <DailyLog>[];
    
    for (var day = startDate; day.isBefore(endDate.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final dateString = _dateFormat.format(day);
      logs.add(allLogs[dateString] ?? DailyLog.empty(day));
    }
    
    return logs;
  }

  // TODO: Добавить методы для сохранения/обновления данных в JSON
  // Future<void> saveLog(DailyLog log) async { ... }
}
