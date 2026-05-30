import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';
import 'cloud_data_service.dart';
import 'profile_service.dart';
import 'recipe_loader.dart';

class DailyLogService {
  static final StreamController<void> _cacheUpdatesController =
      StreamController<void>.broadcast();

  static Stream<void> get cacheUpdates => _cacheUpdatesController.stream;

  static void _notifyCacheUpdated() {
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  /// Очищает локальный кеш дневника пользователя
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _notifyCacheUpdated();
  }

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static const String _storageKey = 'daily_logs';
  final ProfileService _profileService = ProfileService();

  Future<Map<String, dynamic>> _loadRawData() async {
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_storageKey);
    if (stored == null || stored.isEmpty) {
      return {};
    }

    try {
      final decoded = json.decode(stored);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Игнорируем битые локальные данные и возвращаем пустой map.
    }

    return {};
  }

  Future<void> _saveRawData(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(jsonMap));
    _notifyCacheUpdated();

    // Сохраняем локально мгновенно, синхронизацию в облако выполняем асинхронно.
    unawaited(_syncDailyLogsToCloudInBackground(jsonMap));
  }

  Future<void> saveRawDataFromCloud(Map<String, dynamic> jsonMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(jsonMap));
    _notifyCacheUpdated();
  }

  Future<void> _syncDailyLogsToCloudInBackground(
      Map<String, dynamic> jsonMap) async {
    try {
      await CloudDataService.instance.writeMap('daily_logs', {'logs': jsonMap});
    } catch (_) {
      // Повторится при следующем фоновом цикле синхронизации.
    }
  }

  Future<void> syncWithCloud() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return;

    final localData = await _loadRawData();
    // Phone-first: облако всегда обновляется локальным состоянием дневника.
    await cloud.writeMap('daily_logs', {'logs': localData});
  }

  Future<void> pullFromCloudReplaceLocal() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return;

    final remote = await cloud.readMap('daily_logs');
    final logs = remote?['logs'];
    if (logs is! Map<String, dynamic>) return;
    await saveRawDataFromCloud(logs);
  }

  Map<String, dynamic> _emptyMealsJson() {
    return {
      'breakfast': [],
      'lunch': [],
      'dinner': [],
      'snacks': [],
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
      'id': item.id,
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
      'vitaminE': nutrients.vitaminE,
      'vitaminK': nutrients.vitaminK,
      'vitaminB1': nutrients.vitaminB1,
      'vitaminB2': nutrients.vitaminB2,
      'vitaminB3': nutrients.vitaminB3,
      'vitaminB5': nutrients.vitaminB5,
      'vitaminB6': nutrients.vitaminB6,
      'vitaminB7': nutrients.vitaminB7,
      'vitaminB9': nutrients.vitaminB9,
      'vitaminB12': nutrients.vitaminB12,
      'magnesium': nutrients.magnesium,
      'phosphorus': nutrients.phosphorus,
      'zinc': nutrients.zinc,
      'copper': nutrients.copper,
      'manganese': nutrients.manganese,
      'selenium': nutrients.selenium,
      'iodine': nutrients.iodine,
      'chromium': nutrients.chromium,
      'molybdenum': nutrients.molybdenum,
      'fluoride': nutrients.fluoride,
      'lead': nutrients.lead,
      'mercury': nutrients.mercury,
      'cadmium': nutrients.cadmium,
      'arsenic': nutrients.arsenic,
      'nitrates': nutrients.nitrates,
      'pesticides': nutrients.pesticides,
    };
  }

  DailyLog _parseLog(String dateString, Map<String, dynamic> logJson) {
    final mealsJson =
        (logJson['meals'] as Map<String, dynamic>?) ?? _emptyMealsJson();
    final meals = mealsJson.map((mealName, itemsJson) {
      // Маппинг старых русских ключей на новые английские для обратной совместимости
      String key = mealName;
      if (mealName == 'Завтрак') key = 'breakfast';
      if (mealName == 'Обед') key = 'lunch';
      if (mealName == 'Ужин') key = 'dinner';
      if (mealName == 'Перекусы') key = 'snacks';

      final items = (itemsJson as List)
          .map((itemJson) => itemJson as Map<String, dynamic>)
          .map((itemJson) {
        final nutrientsJson =
            (itemJson['nutrients'] as Map<String, dynamic>?) ??
                <String, dynamic>{};
        return FoodItem(
          id: itemJson['id'] as String?,
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
      return MapEntry(key, items);
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
      id: recipe.id,
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
        vitaminE: recipe.nutrients['vitamin_e'] ?? 0,
        vitaminK: recipe.nutrients['vitamin_k'] ?? 0,
        vitaminB1: recipe.nutrients['vitamin_b1'] ?? 0,
        vitaminB2: recipe.nutrients['vitamin_b2'] ?? 0,
        vitaminB3: recipe.nutrients['vitamin_b3'] ?? 0,
        vitaminB5: recipe.nutrients['vitamin_b5'] ?? 0,
        vitaminB6: recipe.nutrients['vitamin_b6'] ?? 0,
        vitaminB7: recipe.nutrients['vitamin_b7'] ?? 0,
        vitaminB9: recipe.nutrients['vitamin_b9'] ?? 0,
        vitaminB12: recipe.nutrients['vitamin_b12'] ?? 0,
        magnesium: recipe.nutrients['magnesium'] ?? 0,
        phosphorus: recipe.nutrients['phosphorus'] ?? 0,
        zinc: recipe.nutrients['zinc'] ?? 0,
        copper: recipe.nutrients['copper'] ?? 0,
        manganese: recipe.nutrients['manganese'] ?? 0,
        selenium: recipe.nutrients['selenium'] ?? 0,
        iodine: recipe.nutrients['iodine'] ?? 0,
        chromium: recipe.nutrients['chromium'] ?? 0,
        molybdenum: recipe.nutrients['molybdenum'] ?? 0,
        fluoride: recipe.nutrients['fluoride'] ?? 0,
        lead: recipe.nutrients['lead'] ?? 0,
        mercury: recipe.nutrients['mercury'] ?? 0,
        cadmium: recipe.nutrients['cadmium'] ?? 0,
        arsenic: recipe.nutrients['arsenic'] ?? 0,
        nitrates: recipe.nutrients['nitrates'] ?? 0,
        pesticides: recipe.nutrients['pesticides'] ?? 0,
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
    String description = '',
    required int calories,
    String iconName = ActivityEntry.defaultIconName,
  }) async {
    final currentLog = await getLogForDate(date);
    final activities = List<ActivityEntry>.from(currentLog.activities)
      ..add(
        ActivityEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          description: description,
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
    String description = '',
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
                  description: description,
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
