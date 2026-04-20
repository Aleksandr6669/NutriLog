import 'food_item.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ActivityEntry {
  final String id;
  final String name;
  final int calories;
  final String iconName;

  static const String defaultIconName = 'fitness_center';

  static const Map<String, IconData> iconOptions = {
    'fitness_center': Symbols.fitness_center,
    'directions_run': Symbols.directions_run,
    'directions_walk': Symbols.directions_walk,
    'directions_bike': Symbols.directions_bike,
    'pool': Symbols.pool,
    'sports_soccer': Symbols.sports_soccer,
    'sports_basketball': Symbols.sports_basketball,
    'sports_volleyball': Symbols.sports_volleyball,
    'sports_tennis': Symbols.sports_tennis,
    'sports_martial_arts': Symbols.sports_martial_arts,
    'self_improvement': Symbols.self_improvement,
    'hiking': Symbols.hiking,
  };

  static IconData iconFromName(String? iconName) {
    return iconOptions[iconName] ?? iconOptions[defaultIconName]!;
  }

  IconData get icon => iconFromName(iconName);

  const ActivityEntry({
    required this.id,
    required this.name,
    required this.calories,
    this.iconName = defaultIconName,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Активность',
      calories: json['calories'] as int? ?? 0,
      iconName: json['iconName'] as String? ?? defaultIconName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'iconName': iconName,
    };
  }
}

class DailyLog {
  final DateTime date;
  final int waterIntake; // в миллилитрах
  final int activityCalories;
  final int steps;
  final double? weight;
  final List<ActivityEntry> activities;
  final Map<String, List<FoodItem>> meals; // e.g., {'Завтрак': [FoodItem, ...]}

  DailyLog({
    required this.date,
    required this.waterIntake,
    required this.activityCalories,
    required this.steps,
    this.weight,
    this.activities = const [],
    required this.meals,
  });

  DailyLog copyWith({
    DateTime? date,
    int? waterIntake,
    int? activityCalories,
    int? steps,
    double? weight,
    List<ActivityEntry>? activities,
    Map<String, List<FoodItem>>? meals,
  }) {
    return DailyLog(
      date: date ?? this.date,
      waterIntake: waterIntake ?? this.waterIntake,
      activityCalories: activityCalories ?? this.activityCalories,
      steps: steps ?? this.steps,
      weight: weight ?? this.weight,
      activities: activities ?? this.activities,
      meals: meals ?? this.meals,
    );
  }

  // Проверяем, были ли за день записаны какие-либо данные
  bool get isEmpty {
    final bool noMeals = meals.values.every((list) => list.isEmpty);
    return noMeals &&
        waterIntake == 0 &&
        activityCalories == 0 &&
        steps == 0 &&
        weight == null &&
        activities.isEmpty;
  }

  // Пустой лог для дня, в котором еще нет записей
  factory DailyLog.empty(DateTime date) {
    return DailyLog(
      date: date,
      waterIntake: 0,
      activityCalories: 0,
      steps: 0,
      weight: null,
      activities: const [],
      meals: {
        'Завтрак': [],
        'Обед': [],
        'Ужин': [],
        'Перекусы': [],
      },
    );
  }

  // Подсчет общих нутриентов за день
  NutritionalInfo get totalNutrients {
    return meals.values.fold<NutritionalInfo>(
      NutritionalInfo.zero,
      (total, foodItems) =>
          total +
          foodItems.fold<NutritionalInfo>(
            NutritionalInfo.zero,
            (mealTotal, item) => mealTotal + item.nutrients,
          ),
    );
  }
}
