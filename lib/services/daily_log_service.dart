import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';
import 'profile_service.dart';
import 'recipe_loader.dart';

class DailyLogService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static const String _storageKey = 'daily_logs_v2';
  final ProfileService _profileService = ProfileService();

  Future<Map<String, dynamic>> _loadRawData() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_storageKey);

    // Fallback to older daily_logs key if v2 is empty
    if (stored == null || stored.isEmpty) {
      stored = prefs.getString('daily_logs');
      if (stored != null && stored.isNotEmpty) {
        // Save to new key to complete migration
        await prefs.setString(_storageKey, stored);
      }
    }

    if (stored == null || stored.isEmpty) {
      return {};
    }
    
    try {
      final decoded = json.decode(stored);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    
    return {};
  }

  Future<void> _saveRawData(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(jsonMap));
  }

  Map<String, dynamic> _emptyMealsJson() {
    return {
      'Завтрак': [],
      'Обед': [],
      'Ужин': [],
      'Перекусы': [],
    };
  }

  Map<String, dynamic> _logToJson(DailyLog log) {
    return {
      'waterIntake': log.waterIntake,
      'activityCalories': log.activityCalories,
      'steps': log.steps,
      'weight': log.weight,
      'activities':
          log.activities.map((activity) => activity.toJson()).toList(),
      'meals': log.meals.map((mealName, items) {
        return MapEntry(
          mealName,
          items.map((item) => _foodItemToJson(item)).toList(),
        );
      }),
    };
  }

  Map<String, dynamic> _foodItemToJson(FoodItem item) {
    return {
      'icon': RecipeLoader.getIconName(item.icon),
      'name': item.name,
      'description': item.description,
      'nutrients': _nutrientsToJson(item.nutrients),
      'recipeIngredients': item.recipeIngredients,
      'recipeInstructions': item.recipeInstructions,
    };
  }

  Map<String, dynamic> _nutrientsToJson(NutritionalInfo nutrients) {
    return {
      'calories': nutrients.calories,
      'protein': nutrients.protein,
      'carbs': nutrients.carbs,
      'fat': nutrients.fat,
      'saturatedFat': nutrients.saturatedFat,
      'polyunsaturatedFat': nutrients.polyunsaturatedFat,
      'monounsaturatedFat': nutrients.monounsaturatedFat,
      'transFat': nutrients.transFat,
      'cholesterol': nutrients.cholesterol,
      'sodium': nutrients.sodium,
      'potassium': nutrients.potassium,
      'fiber': nutrients.fiber,
      'sugar': nutrients.sugar,
      'vitaminA': nutrients.vitaminA,
      'vitaminC': nutrients.vitaminC,
      'vitaminD': nutrients.vitaminD,
      'calcium': nutrients.calcium,
      'iron': nutrients.iron,
    };
  }

  DailyLog _parseLog(String dateString, Map<String, dynamic> logJson) {
    final mealsJson =
        (logJson['meals'] as Map<String, dynamic>?) ?? _emptyMealsJson();
    final meals = mealsJson.map((mealName, itemsJson) {
      final items = (itemsJson as List)
          .map((itemJson) => itemJson as Map<String, dynamic>)
          .map((itemJson) {
        final nutrientsJson =
            (itemJson['nutrients'] as Map<String, dynamic>?) ??
                <String, dynamic>{};
        return FoodItem(
          icon: RecipeLoader.getIcon(itemJson['icon'] as String? ?? ''),
          name: itemJson['name'] as String? ?? '',
          description: itemJson['description'] as String? ?? '',
          nutrients: NutritionalInfo.fromJson(nutrientsJson),
          recipeIngredients:
              ((itemJson['recipeIngredients'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(),
          recipeInstructions:
              ((itemJson['recipeInstructions'] as List?) ?? const [])
                  .whereType<String>()
                  .toList(),
        );
      }).toList();
      return MapEntry(mealName, items);
    });

    final activities = ((logJson['activities'] as List?) ?? const [])
        .whereType<Map>()
        .map(
            (entry) => ActivityEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
    final totalActivityCalories =
        activities.fold<int>(0, (sum, entry) => sum + entry.calories);

    return DailyLog(
      date: DateTime.parse(dateString),
      waterIntake: logJson['waterIntake'] as int? ?? 0,
      activityCalories: activities.isNotEmpty
          ? totalActivityCalories
          : logJson['activityCalories'] as int? ?? 0,
      steps: logJson['steps'] as int? ?? 0,
      weight: (logJson['weight'] as num?)?.toDouble(),
      activities: activities,
      meals: {
        ...DailyLog.empty(DateTime.parse(dateString)).meals,
        ...meals,
      },
    );
  }

  Future<Map<String, DailyLog>> _loadDailyLogs() async {
    final jsonMap = await _loadRawData();
    return jsonMap.map((dateString, logJson) {
      return MapEntry(
        dateString,
        _parseLog(dateString, logJson as Map<String, dynamic>),
      );
    });
  }

  Future<void> _saveLog(DailyLog log) async {
    final all = await _loadRawData();
    final dateString = _dateFormat.format(log.date);
    all[dateString] = _logToJson(log);
    await _saveRawData(all);
  }

  FoodItem recipeToFoodItem(Recipe recipe) {
    return FoodItem(
      icon: recipe.icon,
      name: recipe.name,
      description: recipe.description,
      recipeIngredients:
          recipe.ingredients.map((ingredient) => ingredient.toJson()).toList(),
      recipeInstructions: List<String>.from(recipe.instructions),
      nutrients: NutritionalInfo(
        calories: recipe.nutrients['calories'] ?? 0,
        protein: recipe.nutrients['protein'] ?? 0,
        carbs: recipe.nutrients['carbs'] ?? 0,
        fat: recipe.nutrients['fat'] ?? 0,
        saturatedFat: recipe.nutrients['saturated_fat'] ?? 0,
        polyunsaturatedFat: recipe.nutrients['polyunsaturated_fat'] ?? 0,
        monounsaturatedFat: recipe.nutrients['monounsaturated_fat'] ?? 0,
        transFat: recipe.nutrients['trans_fat'] ?? 0,
        cholesterol: recipe.nutrients['cholesterol'] ?? 0,
        sodium: recipe.nutrients['sodium'] ?? 0,
        potassium: recipe.nutrients['potassium'] ?? 0,
        fiber: recipe.nutrients['fiber'] ?? 0,
        sugar: recipe.nutrients['sugar'] ?? 0,
        vitaminA: recipe.nutrients['vitamin_a'] ?? 0,
        vitaminC: recipe.nutrients['vitamin_c'] ?? 0,
        vitaminD: recipe.nutrients['vitamin_d'] ?? 0,
        calcium: recipe.nutrients['calcium'] ?? 0,
        iron: recipe.nutrients['iron'] ?? 0,
      ),
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
    final jsonMap = await _loadRawData();
    return jsonMap.keys.map((dateString) => DateTime.parse(dateString)).toSet();
  }

  /// Загружает данные за указанный период (например, за неделю).
  Future<List<DailyLog>> getLogsForPeriod(
      DateTime startDate, DateTime endDate) async {
    final allLogs = await _loadDailyLogs();
    final logs = <DailyLog>[];

    for (var day = startDate;
        day.isBefore(endDate.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))) {
      final dateString = _dateFormat.format(day);
      logs.add(allLogs[dateString] ?? DailyLog.empty(day));
    }

    return logs;
  }

  Future<void> addRecipesToMeal(
    DateTime date,
    String mealName,
    List<Recipe> recipes,
  ) async {
    if (recipes.isEmpty) return;

    final currentLog = await getLogForDate(date);
    final currentItems = List<FoodItem>.from(currentLog.meals[mealName] ?? []);
    currentItems.addAll(recipes.map(recipeToFoodItem));

    final updatedMeals = Map<String, List<FoodItem>>.from(currentLog.meals);
    updatedMeals[mealName] = currentItems;

    final updatedLog = currentLog.copyWith(meals: updatedMeals);

    await _saveLog(updatedLog);
  }

  Future<void> updateMealItems(
    DateTime date,
    String mealName,
    List<FoodItem> items,
  ) async {
    final currentLog = await getLogForDate(date);
    final updatedMeals = Map<String, List<FoodItem>>.from(currentLog.meals);
    updatedMeals[mealName] = items;
    final updatedLog = currentLog.copyWith(meals: updatedMeals);
    await _saveLog(updatedLog);
  }

  Future<void> removeFoodItemFromMeal(
    DateTime date,
    String mealName,
    int itemIndex,
  ) async {
    final currentLog = await getLogForDate(date);
    final currentItems = List<FoodItem>.from(currentLog.meals[mealName] ?? []);

    if (itemIndex < 0 || itemIndex >= currentItems.length) {
      return;
    }

    currentItems.removeAt(itemIndex);

    final updatedMeals = Map<String, List<FoodItem>>.from(currentLog.meals);
    updatedMeals[mealName] = currentItems;

    final updatedLog = currentLog.copyWith(meals: updatedMeals);

    await _saveLog(updatedLog);
  }

  Future<void> addWater(DateTime date, {int amount = 250}) async {
    final currentLog = await getLogForDate(date);
    final nextValue = currentLog.waterIntake + amount;
    await _saveLog(currentLog.copyWith(waterIntake: nextValue));
  }

  Future<void> removeWater(DateTime date, {int amount = 250}) async {
    final currentLog = await getLogForDate(date);
    final nextValue = (currentLog.waterIntake - amount).clamp(0, 1000000);
    await _saveLog(currentLog.copyWith(waterIntake: nextValue));
  }

  Future<void> setSteps(DateTime date, {required int steps}) async {
    final currentLog = await getLogForDate(date);
    final nextSteps = steps < 0 ? 0 : steps;
    await _saveLog(currentLog.copyWith(steps: nextSteps));
  }

  Future<void> updateActivityList(
    DateTime date,
    List<ActivityEntry> activities,
  ) async {
    final currentLog = await getLogForDate(date);
    final total = activities.fold<int>(0, (sum, item) => sum + item.calories);
    final updatedLog = currentLog.copyWith(
      activities: activities,
      activityCalories: total,
    );
    await _saveLog(updatedLog);
  }

  Future<void> addActivity(
    DateTime date, {
    required String name,
    required int calories,
    String iconName = ActivityEntry.defaultIconName,
  }) async {
    final currentLog = await getLogForDate(date);
    final activities = List<ActivityEntry>.from(currentLog.activities)
      ..add(
        ActivityEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          calories: calories,
          iconName: iconName,
        ),
      );
    final total = activities.fold<int>(0, (sum, item) => sum + item.calories);
    await _saveLog(
      currentLog.copyWith(
        activities: activities,
        activityCalories: total,
      ),
    );
  }

  Future<void> updateActivity(
    DateTime date, {
    required String id,
    required String name,
    required int calories,
    String iconName = ActivityEntry.defaultIconName,
  }) async {
    final currentLog = await getLogForDate(date);
    final activities = currentLog.activities
        .map(
          (entry) => entry.id == id
              ? ActivityEntry(
                  id: entry.id,
                  name: name,
                  calories: calories,
                  iconName: iconName,
                )
              : entry,
        )
        .toList();
    final total = activities.fold<int>(0, (sum, item) => sum + item.calories);
    await _saveLog(
      currentLog.copyWith(
        activities: activities,
        activityCalories: total,
      ),
    );
  }

  Future<void> removeActivity(DateTime date, {required String id}) async {
    final currentLog = await getLogForDate(date);
    final activities = currentLog.activities.where((e) => e.id != id).toList();
    final total = activities.fold<int>(0, (sum, item) => sum + item.calories);
    await _saveLog(
      currentLog.copyWith(
        activities: activities,
        activityCalories: total,
      ),
    );
  }

  Future<void> setWeight(DateTime date, {required double weight}) async {
    final currentLog = await getLogForDate(date);
    await _saveLog(currentLog.copyWith(weight: weight));
    await syncProfileWeightFromLogs();
  }

  Future<void> syncProfileWeightFromLogs() async {
    final allLogs = await _loadDailyLogs();
    if (allLogs.isEmpty) return;

    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day);

    final weightedLogs =
        allLogs.values.where((log) => log.weight != null).where((log) {
      final dateOnly = DateTime(log.date.year, log.date.month, log.date.day);
      return !dateOnly.isAfter(cutoff);
    }).toList();

    if (weightedLogs.isEmpty) return;

    weightedLogs.sort((a, b) => b.date.compareTo(a.date));
    final latestWeight = weightedLogs.first.weight!;

    final profile = await _profileService.loadProfile();
    if ((profile.weight - latestWeight).abs() < 0.0001) return;

    await _profileService.saveProfile(profile.copyWith(weight: latestWeight));
  }
}
