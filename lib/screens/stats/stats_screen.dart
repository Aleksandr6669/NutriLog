import 'dart:developer' as developer;
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../models/daily_log.dart';
import '../../models/recipe.dart';
import '../../models/user_profile.dart';
import '../../services/ai_report_history_service.dart';
import '../../services/cloud_data_service.dart';
import '../../services/daily_log_service.dart';
import '../../services/gemini_recipe_service.dart';
import '../../services/notification_settings_service.dart';
import '../../services/profile_service.dart';
import '../../services/recipe_loader.dart';
import '../../services/recipe_service.dart';
import '../../services/local_first_sync_service.dart';
import '../../router.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import 'widgets/chart_legend_item.dart';
import 'widgets/progress_card.dart';
import '../profile/subscription_plans_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _StatsPeriod { week, month, year }

class _StatsScreenState extends State<StatsScreen> with RouteAware {
  _StatsPeriod _period = _StatsPeriod.week;
  final DailyLogService _logService = DailyLogService();
  final ProfileService _profileService = ProfileService();
  final GeminiRecipeService _geminiRecipeService = GeminiRecipeService();
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final ScrollController _scrollController = ScrollController();
  late Future<Map<String, dynamic>> _statsFuture;
  String? _aiOverview;
  List<Map<String, String>> _aiRecommendations = const [];
  bool _aiError = false;
  int _dataRequestId = 0;
  int _aiStartedForRequestId = -1;
  Locale? _lastLocale;
  final AiReportHistoryService _historyService = AiReportHistoryService();
  List<AiReportEntry> _aiReportHistory = const [];
  StreamSubscription<void>? _logCacheSubscription;
  StreamSubscription<void>? _profileCacheSubscription;
  Timer? _reloadDebounce;
  bool _isDebouncePending = false;
  Map<String, dynamic>? _lastLoadedStats;
  ModalRoute<dynamic>? _subscribedRoute;
  String? _lastDisplayedSignature;
  // Per-period in-memory AI cache: avoids redundant AI calls on period switch.
  final Map<String,
          ({String? overview, List<Map<String, String>> recs, bool error})>
      _aiCacheByPeriod = {};

  @override
  void initState() {
    super.initState();
    _reloadStats();
    _loadHistory();
    _logCacheSubscription = DailyLogService.cacheUpdates.listen((_) {
      if (!mounted) return;
      _reloadDebounce?.cancel();
      setState(() => _isDebouncePending = true);
      _reloadDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted) _reloadStats(soft: true);
      });
    });
    _profileCacheSubscription = ProfileService.cacheUpdates.listen((_) {
      if (!mounted) return;
      _reloadDebounce?.cancel();
      setState(() => _isDebouncePending = true);
      _reloadDebounce = Timer(const Duration(seconds: 3), () {
        if (mounted) _reloadStats(soft: true);
      });
    });
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadHistory();
    if (!mounted) return;
    setState(() => _aiReportHistory = history);
  }

  @override
  void dispose() {
    if (_subscribedRoute is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    _reloadDebounce?.cancel();
    _logCacheSubscription?.cancel();
    _profileCacheSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute is PageRoute<dynamic>) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route is PageRoute<dynamic>) {
        appRouteObserver.subscribe(this, route);
      }
    }

    final locale = Localizations.localeOf(context);
    if (_lastLocale != locale) {
      _lastLocale = locale;
      if (mounted) {
        _reloadStats();
      }
    }
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    _reloadStats(soft: true);
  }

  void _reloadStats({bool soft = false}) {
    _dataRequestId++;
    _aiStartedForRequestId = -1;
    unawaited(LocalFirstSyncService.instance.syncNow());
    setState(() {
      _isDebouncePending = false;
      if (!soft) {
        final cached = _aiCacheByPeriod[_period.name];
        if (cached != null) {
          _aiOverview = cached.overview;
          _aiRecommendations = cached.recs;
          _aiError = cached.error;
        } else {
          _aiOverview = null;
          _aiRecommendations = const [];
          _aiError = false;
        }
      }
      _statsFuture = _loadData();
    });
  }

  Future<Map<String, dynamic>> _loadData() async {
    developer.log('Starting to load data for stats screen...',
        name: 'StatsScreen');
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final startDate = switch (_period) {
      _StatsPeriod.week => now.subtract(const Duration(days: 6)),
      _StatsPeriod.month => now.subtract(const Duration(days: 29)),
      _StatsPeriod.year => now.subtract(const Duration(days: 364)),
    };
    final endDate = now;

    final logs = await _logService.getLogsForPeriod(startDate, endDate);
    final profile = await _profileService.loadProfile();
    final settings = await _settingsService.load();
    final aiAssistantEnabled = settings.statsAiAssistantEnabled;
    final recipeService = RecipeService();
    if (CloudDataService.instance.isSignedIn) {
      // Не блокируем загрузку аналитики: синхронизация только в фоне.
      unawaited(recipeService.syncWithCloud());
    }
    final builtInRecipes = await RecipeLoader.loadRecipesFromAssets(
      locale: locale,
    );
    final userRecipes = await recipeService.loadUserRecipes();
    final allRecipes = [...userRecipes, ...builtInRecipes];

    List<double> caloriesData;
    List<double> weightData;
    List<double> stepsSeries;
    List<double> activitySeries;
    List<double> waterSeries;
    if (_period == _StatsPeriod.year) {
      caloriesData = List<double>.filled(12, 0);
      weightData = List<double>.filled(12, 0);
      stepsSeries = List<double>.filled(12, 0);
      activitySeries = List<double>.filled(12, 0);
      waterSeries = List<double>.filled(12, 0);

      for (int month = 1; month <= 12; month++) {
        final monthLogs = logs.where((log) => log.date.month == month).toList();
        caloriesData[month - 1] = monthLogs.fold<double>(
          0,
          (sum, log) => sum + log.totalNutrients.calories,
        );

        if (monthLogs.isNotEmpty) {
          final stepSum = monthLogs.fold<int>(0, (sum, log) => sum + log.steps);
          stepsSeries[month - 1] = stepSum / monthLogs.length;

          final waterSum =
              monthLogs.fold<int>(0, (sum, log) => sum + log.waterIntake);
          waterSeries[month - 1] = (waterSum / monthLogs.length) / 1000;

          final activitySum = monthLogs.fold<double>(0, (sum, log) {
            if (log.activities.isNotEmpty) {
              return sum +
                  log.activities.fold<int>(0, (s, item) => s + item.calories);
            }
            return sum + log.activityCalories;
          });
          activitySeries[month - 1] = activitySum / monthLogs.length;
        }

        final monthWeightLogs =
            monthLogs.where((log) => log.weight != null).toList();
        if (monthWeightLogs.isNotEmpty) {
          weightData[month - 1] = monthWeightLogs.last.weight ?? 0.0;
        }
      }
    } else {
      caloriesData = logs.map((log) => log.totalNutrients.calories).toList();
      weightData = logs.map((log) => log.weight ?? 0.0).toList();
      stepsSeries = logs.map((log) => log.steps.toDouble()).toList();
      waterSeries = logs.map((log) => log.waterIntake / 1000).toList();
      activitySeries = logs.map((log) {
        if (log.activities.isNotEmpty) {
          return log.activities
              .fold<int>(0, (sum, item) => sum + item.calories)
              .toDouble();
        }
        return log.activityCalories.toDouble();
      }).toList();
    }

    // Считаем только по заполненным дням (log.isEmpty == false)
    final filledLogs = logs.where((log) => !log.isEmpty).toList();
    int logCount = filledLogs.length;
    if (logCount == 0) logCount = 1;

    final totalCarbs = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.carbs);
    final totalProtein = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.protein);
    final totalFat =
        filledLogs.fold<double>(0, (sum, log) => sum + log.totalNutrients.fat);
    final totalCalories = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.calories);
    final totalFiber = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.fiber);
    final totalSugar = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.sugar);
    final totalSaturatedFat = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.saturatedFat);
    final totalPolyunsaturatedFat = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.polyunsaturatedFat);
    final totalMonounsaturatedFat = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.monounsaturatedFat);
    final totalTransFat = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.transFat);
    final totalCholesterol = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.cholesterol);
    final totalSodium = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.sodium);
    final totalPotassium = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.potassium);
    final totalVitaminA = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.vitaminA);
    final totalVitaminC = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.vitaminC);
    final totalVitaminD = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.vitaminD);
    final totalCalcium = filledLogs.fold<double>(
        0, (sum, log) => sum + log.totalNutrients.calcium);
    final totalIron =
        filledLogs.fold<double>(0, (sum, log) => sum + log.totalNutrients.iron);
    final totalMacros = totalCarbs + totalProtein + totalFat;
    final foodFrequency = <String, int>{};
    for (final log in filledLogs) {
      for (final mealItems in log.meals.values) {
        for (final item in mealItems) {
          final key = item.name.trim();
          if (key.isEmpty) continue;
          foodFrequency.update(key, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    final topFoods = foodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final snackPriorityRecipes = allRecipes.map((recipe) {
      final nutrients = recipe.nutrients;
      final calories = ((nutrients['calories'] as num?) ?? 0).toDouble();
      final protein = ((nutrients['protein'] as num?) ?? 0).toDouble();
      final fiber = ((nutrients['fiber'] as num?) ?? 0).toDouble();
      final sugar = ((nutrients['sugar'] as num?) ?? 0).toDouble();

      // Nutrient density for snacks: prioritize protein/fiber, limit sugar.
      final score =
          (protein * 2.2) + (fiber * 1.8) - (sugar * 0.6) - (calories / 220);
      return {
        'name': recipe.name,
        'calories': calories.round(),
        'protein': protein,
        'fiber': fiber,
        'sugar': sugar,
        'score': score,
      };
    }).where((item) {
      final calories = (item['calories'] as num).toInt();
      final protein = (item['protein'] as num).toDouble();
      final fiber = (item['fiber'] as num).toDouble();
      final sugar = (item['sugar'] as num).toDouble();
      final nutrientDense = protein >= 5 || fiber >= 3;
      final sugarOk = sugar <= 18;
      return calories >= 60 && calories <= 360 && nutrientDense && sugarOk;
    }).toList()
      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    final avgCarbs = totalMacros > 0 ? (totalCarbs / totalMacros) * 100 : 0;
    final avgProtein = totalMacros > 0 ? (totalProtein / totalMacros) * 100 : 0;
    final avgFat = totalMacros > 0 ? (totalFat / totalMacros) * 100 : 0;

    final avgSteps = logCount > 0
        ? filledLogs.fold<int>(0, (sum, log) => sum + log.steps) ~/ logCount
        : 0;
    final latestStepsLog = logs.lastWhere((log) => log.steps > 0,
        orElse: () => DailyLog.empty(now));
    final latestSteps = latestStepsLog.steps;

    final latestWeightLog = logs.lastWhere((log) => log.weight != null,
        orElse: () => DailyLog.empty(now));
    final latestWeight = latestWeightLog.weight ?? profile.weight;
    final weightLogs = filledLogs.where((log) => log.weight != null).toList();
    final avgWeight = weightLogs.isEmpty
        ? latestWeight
        : weightLogs.fold<double>(0, (sum, log) => sum + (log.weight ?? 0)) /
            weightLogs.length;

    int workouts = 0;
    int totalActivityCalories = 0;
    for (final log in filledLogs) {
      if (log.activities.isNotEmpty) {
        workouts += log.activities.length;
        totalActivityCalories +=
            log.activities.fold<int>(0, (sum, item) => sum + item.calories);
      } else if (log.activityCalories > 0) {
        // Backward compatibility for old logs without activity entries.
        workouts += 1;
        totalActivityCalories += log.activityCalories;
      }
    }
    final avgActivityCalories =
        workouts > 0 ? (totalActivityCalories / workouts).round() : 0;
    final avgWater = logCount > 0
        ? filledLogs.fold<int>(0, (sum, log) => sum + log.waterIntake) ~/
            logCount
        : 0;
    final latestWaterLog = logs.lastWhere((log) => log.waterIntake > 0,
        orElse: () => DailyLog.empty(now));
    final latestWater = latestWaterLog.waterIntake;

    final avgCalories = caloriesData.isEmpty
        ? 0.0
        : caloriesData.reduce((a, b) => a + b) / caloriesData.length;
    final avgProteinGrams = totalProtein / logCount;
    final avgFatGrams = totalFat / logCount;
    final avgCarbsGrams = totalCarbs / logCount;
    final avgFiberGrams = totalFiber / logCount;
    final avgSugarGrams = totalSugar / logCount;
    final avgSaturatedFatGrams = totalSaturatedFat / logCount;
    final avgPolyunsaturatedFatGrams = totalPolyunsaturatedFat / logCount;
    final avgMonounsaturatedFatGrams = totalMonounsaturatedFat / logCount;
    final avgTransFatGrams = totalTransFat / logCount;
    final avgCholesterolMg = totalCholesterol / logCount;
    final avgSodiumMg = totalSodium / logCount;
    final avgPotassiumMg = totalPotassium / logCount;
    final avgVitaminAMcg = totalVitaminA / logCount;
    final avgVitaminCMg = totalVitaminC / logCount;
    final avgVitaminDMcg = totalVitaminD / logCount;
    final avgCalciumMg = totalCalcium / logCount;
    final avgIronMg = totalIron / logCount;

    return {
      'calories': caloriesData,
      'weight': weightData,
      'avgCarbs': avgCarbs,
      'avgProtein': avgProtein,
      'avgFat': avgFat,
      'avgSteps': avgSteps,
      'latestSteps': latestSteps,
      'avgWeight': avgWeight,
      'latestWeight': latestWeight,
      'avgActivityCalories': avgActivityCalories,
      'workouts': workouts,
      'avgWater': avgWater,
      'latestWater': latestWater,
      'stepsSeries': stepsSeries,
      'weightSeries': weightData,
      'activitySeries': activitySeries,
      'waterSeries': waterSeries,
      'profile': profile,
      'aiAssistantEnabled': aiAssistantEnabled,
      'recipes': allRecipes,
      'aiInput': {
        'periodLabel': _period.name,
        'goalType': profile.goalType.enLabel,
        'activityTypes': profile.activityTypes,
        'aiContext': profile.aiContext,
        'calorieGoal': profile.calorieGoal,
        'proteinGoal': profile.proteinGoal,
        'fatGoal': profile.fatGoal,
        'carbsGoal': profile.carbsGoal,
        'avgCalories': avgCalories,
        'avgProteinGrams': avgProteinGrams,
        'avgFatGrams': avgFatGrams,
        'avgCarbsGrams': avgCarbsGrams,
        'avgFiberGrams': avgFiberGrams,
        'avgSugarGrams': avgSugarGrams,
        'avgSaturatedFatGrams': avgSaturatedFatGrams,
        'avgPolyunsaturatedFatGrams': avgPolyunsaturatedFatGrams,
        'avgMonounsaturatedFatGrams': avgMonounsaturatedFatGrams,
        'avgTransFatGrams': avgTransFatGrams,
        'avgCholesterolMg': avgCholesterolMg,
        'avgSodiumMg': avgSodiumMg,
        'avgPotassiumMg': avgPotassiumMg,
        'avgVitaminAMcg': avgVitaminAMcg,
        'avgVitaminCMg': avgVitaminCMg,
        'avgVitaminDMcg': avgVitaminDMcg,
        'avgCalciumMg': avgCalciumMg,
        'avgIronMg': avgIronMg,
        'totalCalories': totalCalories,
        'totalProteinGrams': totalProtein,
        'totalFatGrams': totalFat,
        'totalCarbsGrams': totalCarbs,
        'totalFiberGrams': totalFiber,
        'totalSugarGrams': totalSugar,
        'totalSaturatedFatGrams': totalSaturatedFat,
        'totalPolyunsaturatedFatGrams': totalPolyunsaturatedFat,
        'totalMonounsaturatedFatGrams': totalMonounsaturatedFat,
        'totalTransFatGrams': totalTransFat,
        'totalCholesterolMg': totalCholesterol,
        'totalSodiumMg': totalSodium,
        'totalPotassiumMg': totalPotassium,
        'totalVitaminAMcg': totalVitaminA,
        'totalVitaminCMg': totalVitaminC,
        'totalVitaminDMcg': totalVitaminD,
        'totalCalciumMg': totalCalcium,
        'totalIronMg': totalIron,
        'stepsGoal': profile.stepsGoal,
        'avgSteps': avgSteps,
        'weightGoal': profile.weightGoal,
        'latestWeight': latestWeight,
        'avgWaterLiters': avgWater / 1000,
        'waterGoalLiters': profile.waterGoal / 1000,
        'workouts': workouts,
        'avgActivityCalories': avgActivityCalories,
        'userName': profile.name,
        'topFoods': topFoods
            .take(5)
            .map((entry) => {
                  'name': entry.key,
                  'count': entry.value,
                })
            .toList(),
        'snackPriorityRecipes': snackPriorityRecipes
            .take(6)
            .map((item) => {
                  'name': item['name'],
                  'calories': item['calories'],
                  'protein': (item['protein'] as double).toStringAsFixed(1),
                  'fiber': (item['fiber'] as double).toStringAsFixed(1),
                  'sugar': (item['sugar'] as double).toStringAsFixed(1),
                })
            .toList(),
        'availableRecipeNames': allRecipes
            .map((recipe) => recipe.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(),
        'consumedFoodNames': filledLogs
            .expand((log) => log.meals.values.expand((items) => items))
            .map((item) {
              final n = item.nutrients;
              final details = [
                '${n.calories.round()}kcal',
                if (n.protein > 0) 'P:${n.protein.round()}g',
                if (n.fat > 0) 'F:${n.fat.round()}g',
                if (n.carbs > 0) 'C:${n.carbs.round()}g',
                if (n.sugar > 0) 'Sug:${n.sugar.round()}g',
                if (n.sodium > 0) 'Sod:${n.sodium.round()}mg',
              ].join(', ');
              return '${item.name.trim()} ($details)';
            })
            .where((name) => name.isNotEmpty && !name.startsWith(' ()'))
            .toSet()
            .toList(),
      },
    };
  }

  Future<void> _loadAiReport(
    Map<String, dynamic> aiInput,
    int requestId, {
    required String sourceSignature,
  }) async {
    // Breather to avoid redundant requests during rapid UI interaction
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted || requestId != _dataRequestId) return;

    try {
      final profile = context.read<ProfileProvider>().profile;
      if (profile == null || !profile.isAiAnalyticsAvailable) {
        if (mounted) {
          setState(() {
            _aiError = false;
            _aiOverview = null;
            _isDebouncePending = false;
          });
        }
        return;
      }
      final aiReport = await _geminiRecipeService.generateStructuredStatsReport(
        periodLabel: aiInput['periodLabel'] as String,
        healthConditions: profile.healthConditions,
        goalType: (aiInput['goalType'] as String? ?? '').trim(),
        activityTypes: (aiInput['activityTypes'] as String? ?? '').trim(),
        aiContext: (aiInput['aiContext'] as String? ?? '').trim(),
        calorieGoal: aiInput['calorieGoal'] as int,
        proteinGoal: aiInput['proteinGoal'] as int,
        fatGoal: aiInput['fatGoal'] as int,
        carbsGoal: aiInput['carbsGoal'] as int,
        avgCalories: (aiInput['avgCalories'] as num).toDouble(),
        locale: Localizations.localeOf(context).languageCode,
        avgProteinGrams: (aiInput['avgProteinGrams'] as num).toDouble(),
        avgFatGrams: (aiInput['avgFatGrams'] as num).toDouble(),
        avgCarbsGrams: (aiInput['avgCarbsGrams'] as num).toDouble(),
        avgFiberGrams: (aiInput['avgFiberGrams'] as num).toDouble(),
        avgSugarGrams: (aiInput['avgSugarGrams'] as num).toDouble(),
        avgSaturatedFatGrams:
            (aiInput['avgSaturatedFatGrams'] as num).toDouble(),
        avgPolyunsaturatedFatGrams:
            (aiInput['avgPolyunsaturatedFatGrams'] as num).toDouble(),
        avgMonounsaturatedFatGrams:
            (aiInput['avgMonounsaturatedFatGrams'] as num).toDouble(),
        avgTransFatGrams: (aiInput['avgTransFatGrams'] as num).toDouble(),
        avgCholesterolMg: (aiInput['avgCholesterolMg'] as num).toDouble(),
        avgSodiumMg: (aiInput['avgSodiumMg'] as num).toDouble(),
        avgPotassiumMg: (aiInput['avgPotassiumMg'] as num).toDouble(),
        avgVitaminAMcg: (aiInput['avgVitaminAMcg'] as num).toDouble(),
        avgVitaminCMg: (aiInput['avgVitaminCMg'] as num).toDouble(),
        avgVitaminDMcg: (aiInput['avgVitaminDMcg'] as num).toDouble(),
        avgCalciumMg: (aiInput['avgCalciumMg'] as num).toDouble(),
        avgIronMg: (aiInput['avgIronMg'] as num).toDouble(),
        totalCalories: (aiInput['totalCalories'] as num).toDouble(),
        totalProteinGrams: (aiInput['totalProteinGrams'] as num).toDouble(),
        totalFatGrams: (aiInput['totalFatGrams'] as num).toDouble(),
        totalCarbsGrams: (aiInput['totalCarbsGrams'] as num).toDouble(),
        totalFiberGrams: (aiInput['totalFiberGrams'] as num).toDouble(),
        totalSugarGrams: (aiInput['totalSugarGrams'] as num).toDouble(),
        totalSaturatedFatGrams:
            (aiInput['totalSaturatedFatGrams'] as num).toDouble(),
        totalPolyunsaturatedFatGrams:
            (aiInput['totalPolyunsaturatedFatGrams'] as num).toDouble(),
        totalMonounsaturatedFatGrams:
            (aiInput['totalMonounsaturatedFatGrams'] as num).toDouble(),
        totalTransFatGrams: (aiInput['totalTransFatGrams'] as num).toDouble(),
        totalCholesterolMg: (aiInput['totalCholesterolMg'] as num).toDouble(),
        totalSodiumMg: (aiInput['totalSodiumMg'] as num).toDouble(),
        totalPotassiumMg: (aiInput['totalPotassiumMg'] as num).toDouble(),
        totalVitaminAMcg: (aiInput['totalVitaminAMcg'] as num).toDouble(),
        totalVitaminCMg: (aiInput['totalVitaminCMg'] as num).toDouble(),
        totalVitaminDMcg: (aiInput['totalVitaminDMcg'] as num).toDouble(),
        totalCalciumMg: (aiInput['totalCalciumMg'] as num).toDouble(),
        totalIronMg: (aiInput['totalIronMg'] as num).toDouble(),
        stepsGoal: aiInput['stepsGoal'] as int,
        avgSteps: aiInput['avgSteps'] as int,
        weightGoal: (aiInput['weightGoal'] as num).toDouble(),
        latestWeight: (aiInput['latestWeight'] as num).toDouble(),
        avgWaterLiters: (aiInput['avgWaterLiters'] as num).toDouble(),
        waterGoalLiters: (aiInput['waterGoalLiters'] as num).toDouble(),
        workouts: aiInput['workouts'] as int,
        avgActivityCalories: aiInput['avgActivityCalories'] as int,
        userName: (aiInput['userName'] as String? ?? '').trim(),
        topFoods: (aiInput['topFoods'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
        snackPriorityRecipes:
            (aiInput['snackPriorityRecipes'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false),
        availableRecipeNames:
            (aiInput['availableRecipeNames'] as List<dynamic>? ?? const [])
                .cast<String>()
                .toList(growable: false),
        consumedFoodNames:
            (aiInput['consumedFoodNames'] as List<dynamic>? ?? const [])
                .cast<String>()
                .toList(growable: false),
        previousReports: _aiReportHistory
            .map(
              (entry) => {
                'period': entry.period,
                'generatedAt': entry.generatedAt.toIso8601String(),
                'overview': entry.overview,
                'recommendations': entry.recommendations,
              },
            )
            .toList(growable: false),
      );

      if (!mounted || requestId != _dataRequestId) return;
      final parsedRecommendations =
          (aiReport['recommendations'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (item) => {
                  'when': (item['when'] as String? ?? '').trim(),
                  'action': (item['action'] as String? ?? '').trim(),
                  'recipeName': (item['recipeName'] as String? ?? '').trim(),
                },
              )
              .where((item) => (item['action'] ?? '').isNotEmpty)
              .toList(growable: false);
      final overview = (aiReport['overview'] as String?)?.trim();
      final normalizedRecommendations =
          _normalizeSortAndMergeRecommendations(parsedRecommendations);

      if (overview != null && overview.isNotEmpty) {
        await _historyService.saveReport(
          AiReportEntry(
            period: aiInput['periodLabel'] as String? ?? _period.name,
            generatedAt: DateTime.now(),
            overview: overview,
            recommendations: normalizedRecommendations,
            sourceSignature: sourceSignature,
          ),
        );
        await _loadHistory();
      }

      setState(() {
        _aiOverview = overview;
        _aiRecommendations = normalizedRecommendations;
        _aiError = false;
        _lastDisplayedSignature = sourceSignature;
        _aiCacheByPeriod[aiInput['periodLabel'] as String? ?? _period.name] = (
          overview: overview,
          recs: normalizedRecommendations,
          error: false,
        );
      });
    } on GeminiRecipeException catch (e) {
      developer.log('AI report error: ${e.message}', name: 'StatsScreen');
      if (!mounted || requestId != _dataRequestId) return;
      _fallbackToLastCachedReport();
    } catch (e) {
      developer.log('AI report error: $e', name: 'StatsScreen');
      if (!mounted || requestId != _dataRequestId) return;
      _fallbackToLastCachedReport();
    }
  }

  /// При недоступности AI показываем последний сохранённый отчёт из истории.
  void _fallbackToLastCachedReport() {
    setState(() {
      _aiOverview = null;
      _aiRecommendations = const [];
      _aiError = true;
    });
  }

  String _buildAiSourceSignature(Map<String, dynamic> aiInput) {
    final signaturePayload = {
      'periodLabel': aiInput['periodLabel'],
      'goalType': aiInput['goalType'],
      'activityTypes': aiInput['activityTypes'],
      'aiContext': aiInput['aiContext'],
      'calorieGoal': aiInput['calorieGoal'],
      'proteinGoal': aiInput['proteinGoal'],
      'fatGoal': aiInput['fatGoal'],
      'carbsGoal': aiInput['carbsGoal'],
      'avgCalories': aiInput['avgCalories'],
      'avgProteinGrams': aiInput['avgProteinGrams'],
      'avgFatGrams': aiInput['avgFatGrams'],
      'avgCarbsGrams': aiInput['avgCarbsGrams'],
      'avgFiberGrams': aiInput['avgFiberGrams'],
      'avgSugarGrams': aiInput['avgSugarGrams'],
      'avgSaturatedFatGrams': aiInput['avgSaturatedFatGrams'],
      'avgPolyunsaturatedFatGrams': aiInput['avgPolyunsaturatedFatGrams'],
      'avgMonounsaturatedFatGrams': aiInput['avgMonounsaturatedFatGrams'],
      'avgTransFatGrams': aiInput['avgTransFatGrams'],
      'avgCholesterolMg': aiInput['avgCholesterolMg'],
      'avgSodiumMg': aiInput['avgSodiumMg'],
      'avgPotassiumMg': aiInput['avgPotassiumMg'],
      'avgVitaminAMcg': aiInput['avgVitaminAMcg'],
      'avgVitaminCMg': aiInput['avgVitaminCMg'],
      'avgVitaminDMcg': aiInput['avgVitaminDMcg'],
      'avgCalciumMg': aiInput['avgCalciumMg'],
      'avgIronMg': aiInput['avgIronMg'],
      'totalCalories': aiInput['totalCalories'],
      'totalProteinGrams': aiInput['totalProteinGrams'],
      'totalFatGrams': aiInput['totalFatGrams'],
      'totalCarbsGrams': aiInput['totalCarbsGrams'],
      'totalFiberGrams': aiInput['totalFiberGrams'],
      'totalSugarGrams': aiInput['totalSugarGrams'],
      'totalSaturatedFatGrams': aiInput['totalSaturatedFatGrams'],
      'totalPolyunsaturatedFatGrams': aiInput['totalPolyunsaturatedFatGrams'],
      'totalMonounsaturatedFatGrams': aiInput['totalMonounsaturatedFatGrams'],
      'totalTransFatGrams': aiInput['totalTransFatGrams'],
      'totalCholesterolMg': aiInput['totalCholesterolMg'],
      'totalSodiumMg': aiInput['totalSodiumMg'],
      'totalPotassiumMg': aiInput['totalPotassiumMg'],
      'totalVitaminAMcg': aiInput['totalVitaminAMcg'],
      'totalVitaminCMg': aiInput['totalVitaminCMg'],
      'totalVitaminDMcg': aiInput['totalVitaminDMcg'],
      'totalCalciumMg': aiInput['totalCalciumMg'],
      'totalIronMg': aiInput['totalIronMg'],
      'avgSteps': aiInput['avgSteps'],
      'latestWeight': aiInput['latestWeight'],
      'avgWaterLiters': aiInput['avgWaterLiters'],
      'workouts': aiInput['workouts'],
      'avgActivityCalories': aiInput['avgActivityCalories'],
      'topFoods': aiInput['topFoods'],
    };
    return jsonEncode(signaturePayload);
  }

  AiReportEntry? _findCachedReportForSignature({
    required String period,
    required String sourceSignature,
  }) {
    for (final entry in _aiReportHistory) {
      if (entry.period != period) continue;
      if (entry.sourceSignature != sourceSignature) continue;
      if (entry.overview.trim().isEmpty) continue;
      if (entry.recommendations.isEmpty) continue;
      return entry;
    }
    return null;
  }

  void _ensureAiReportForCurrentData(
    Map<String, dynamic> aiInput,
    int requestId,
  ) {
    final period = (aiInput['periodLabel'] as String? ?? _period.name).trim();
    final sourceSignature = _buildAiSourceSignature(aiInput);

    if (sourceSignature == _lastDisplayedSignature && _aiOverview != null) {
      return;
    }

    final cached = _findCachedReportForSignature(
      period: period,
      sourceSignature: sourceSignature,
    );

    if (cached != null) {
      final normalizedRecommendations =
          _normalizeSortAndMergeRecommendations(cached.recommendations);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || requestId != _dataRequestId) return;
        setState(() {
          _aiOverview = cached.overview;
          _aiRecommendations = normalizedRecommendations;
          _aiError = false;
          _lastDisplayedSignature = sourceSignature;
          _aiCacheByPeriod[period] = (
            overview: cached.overview,
            recs: normalizedRecommendations,
            error: false,
          );
        });
      });
      return;
    }

    _loadAiReport(
      aiInput,
      requestId,
      sourceSignature: sourceSignature,
    );
  }

  String _periodLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_period) {
      case _StatsPeriod.week:
        return l10n.statsPeriodLabelWeek;
      case _StatsPeriod.month:
        return l10n.statsPeriodLabelMonth;
      case _StatsPeriod.year:
        return l10n.statsPeriodLabelYear;
    }
  }

  List<String>? _chartLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_period) {
      case _StatsPeriod.week:
        final days = [
          l10n.dayMon,
          l10n.dayTue,
          l10n.dayWed,
          l10n.dayThu,
          l10n.dayFri,
          l10n.daySat,
          l10n.daySun
        ];
        final today = DateTime.now().weekday;
        return List.generate(7, (i) => days[(today - 7 + i) % 7]);
      case _StatsPeriod.month:
        final now = DateTime.now();
        return List.generate(now.day, (i) => (i + 1).toString());
      case _StatsPeriod.year:
        final months = [
          l10n.monthJan,
          l10n.monthFeb,
          l10n.monthMar,
          l10n.monthApr,
          l10n.monthMayAbbr,
          l10n.monthJun,
          l10n.monthJul,
          l10n.monthAug,
          l10n.monthSep,
          l10n.monthOct,
          l10n.monthNov,
          l10n.monthDec
        ];
        final now = DateTime.now();
        return List.generate(
            now.month, (i) => months[(now.month - now.month + i) % 12]);
    }
  }

  void _onPeriodChanged(_StatsPeriod period) {
    if (period == _period) return;
    // Save current AI state before switching period.
    _aiCacheByPeriod[_period.name] = (
      overview: _aiOverview,
      recs: List<Map<String, String>>.from(_aiRecommendations),
      error: _aiError,
    );
    setState(() => _period = period);
    _reloadStats();
  }

  List<double> _trimProgressSeriesToCurrentDate(List<double> source) {
    if (source.isEmpty) return source;

    final now = DateTime.now();
    final maxPoints = switch (_period) {
      _StatsPeriod.week => now.weekday,
      _StatsPeriod.month => now.day,
      _StatsPeriod.year => now.month,
    };

    final safeCount = max(1, min(maxPoints, source.length));
    var trimmed = source.take(safeCount).toList(growable: false);
    // Если последний элемент пустой (0 или null), не включаем его
    if (trimmed.isNotEmpty && (trimmed.last == 0 || trimmed.last.isNaN)) {
      trimmed = trimmed.sublist(0, trimmed.length - 1);
    }
    // Для всех периодов: убираем ведущие пустые значения (если пользователь начал недавно)
    while (trimmed.isNotEmpty && (trimmed.first == 0 || trimmed.first.isNaN)) {
      trimmed = trimmed.sublist(1);
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        flexibleSpace: const GlassAppBarBackground(),
        title: Text(l10n.analysis),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final hasCurrentData =
              snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data!.isNotEmpty;
          if (hasCurrentData) {
            _lastLoadedStats = snapshot.data!;
          }
          final effectiveData =
              hasCurrentData ? snapshot.data! : _lastLoadedStats;

          if (snapshot.connectionState == ConnectionState.waiting &&
              effectiveData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && effectiveData == null) {
            return Center(
              child: Text(l10n.statsErrorLoading(snapshot.error.toString())),
            );
          }
          if (effectiveData == null || effectiveData.isEmpty) {
            return Center(child: Text(l10n.statsNoDataForAnalysis));
          }

          final data = effectiveData;
          final aiAssistantEnabled =
              data['aiAssistantEnabled'] as bool? ?? true;
          final requestId = _dataRequestId;
          if (hasCurrentData &&
              aiAssistantEnabled &&
              _aiStartedForRequestId != requestId) {
            _aiStartedForRequestId = requestId;
            _ensureAiReportForCurrentData(
              data['aiInput'] as Map<String, dynamic>,
              requestId,
            );
          }

          final profile = data['profile'] as UserProfile;
          final calories = List<double>.from(data['calories'] as List);
          final weight = List<double>.from(data['weight'] as List);
          final stepsTrend = _trimProgressSeriesToCurrentDate(
            List<double>.from(data['stepsSeries'] as List),
          );
          final weightTrend = _trimProgressSeriesToCurrentDate(
            List<double>.from(data['weightSeries'] as List),
          );
          final activityTrend = _trimProgressSeriesToCurrentDate(
            List<double>.from(data['activitySeries'] as List),
          );
          final waterTrend = _trimProgressSeriesToCurrentDate(
            List<double>.from(data['waterSeries'] as List),
          );

          return SingleChildScrollView(
            key: const PageStorageKey<String>('stats-screen-scroll'),
            controller: _scrollController,
            padding: glassBodyPadding(
              context,
              top: -8,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodToggle(theme),
                const SizedBox(height: 24),
                _buildCaloriesChart(
                  context,
                  theme,
                  calories,
                  profile.calorieGoal.toDouble(),
                ),
                const SizedBox(height: 16),
                _buildWeightChart(
                  context,
                  theme,
                  weight,
                  profile.weightGoal,
                ),
                const SizedBox(height: 16),
                _buildPieChartAndLegend(
                  context,
                  theme,
                  (data['avgCarbs'] as num).toDouble(),
                  (data['avgProtein'] as num).toDouble(),
                  (data['avgFat'] as num).toDouble(),
                ),
                const SizedBox(height: 16),
                _buildProgressCards(
                  theme,
                  data['avgSteps'] as int,
                  data['latestSteps'] as int,
                  (data['avgWeight'] as num).toDouble(),
                  (data['latestWeight'] as num).toDouble(),
                  data['avgActivityCalories'] as int,
                  data['workouts'] as int,
                  data['avgWater'] as int,
                  data['latestWater'] as int,
                  stepsTrend,
                  weightTrend,
                  activityTrend,
                  waterTrend,
                  profile,
                ),
                const SizedBox(height: 24),
                _buildAverageMetricsCard(theme, data),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildAiCircleIcon(),
                    const SizedBox(width: 10),
                    Text(
                      l10n.statsAiReportTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (profile.isPersonalAdviceAvailable)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.info, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.statsAiNotMedicalAdvice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _buildAiReportCard(
                  context,
                  theme,
                  List<Recipe>.from(data['recipes'] as List),
                  aiAssistantEnabled,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodToggle(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppStyles.buttonRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              text: l10n.statsPeriodWeek,
              isSelected: _period == _StatsPeriod.week,
              onTap: () => _onPeriodChanged(_StatsPeriod.week),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              text: l10n.statsPeriodMonth,
              isSelected: _period == _StatsPeriod.month,
              onTap: () => _onPeriodChanged(_StatsPeriod.month),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              text: l10n.statsPeriodYear,
              isSelected: _period == _StatsPeriod.year,
              onTap: () => _onPeriodChanged(_StatsPeriod.year),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart(BuildContext context, ThemeData theme,
      List<double> calories, double goal) {
    final l10n = AppLocalizations.of(context)!;
    return _LineChart(
      data: calories,
      goal: goal,
      lineColor: AppColors.primary,
      gradientColor: AppColors.primary.withAlpha(77),
      labels: _chartLabels(context),
      goalLabel: l10n.statsGoalKcal(goal.toInt()),
      unit: l10n.kcal,
      hideZeroValues: true,
    );
  }

  Widget _buildWeightChart(BuildContext context, ThemeData theme,
      List<double> weightData, double goal) {
    final l10n = AppLocalizations.of(context)!;
    return _LineChart(
      data: weightData,
      goal: goal,
      lineColor: Colors.orange,
      gradientColor: Colors.orange.withAlpha(77),
      labels: _chartLabels(context),
      goalLabel: l10n.statsGoalWeightKg(goal.toStringAsFixed(1)),
      unit: l10n.weightUnit,
      isWeight: true,
    );
  }

  Widget _buildPieChartAndLegend(BuildContext context, ThemeData theme,
      double carbs, double protein, double fat) {
    final l10n = AppLocalizations.of(context)!;
    final hasData = carbs + protein + fat > 0;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChartLegendItem(
                      color: AppColors.primary,
                      text: l10n.carbs,
                      percentage: carbs.round()),
                  const SizedBox(height: 12),
                  ChartLegendItem(
                      color: Colors.orange,
                      text: l10n.protein,
                      percentage: protein.round()),
                  const SizedBox(height: 12),
                  ChartLegendItem(
                      color: Colors.blue,
                      text: l10n.fat,
                      percentage: fat.round()),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 140,
                child: hasData
                    ? PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                                value: carbs,
                                color: AppColors.primary,
                                radius: 40,
                                showTitle: false),
                            PieChartSectionData(
                                value: protein,
                                color: Colors.orange,
                                radius: 40,
                                showTitle: false),
                            PieChartSectionData(
                                value: fat,
                                color: Colors.blue,
                                radius: 40,
                                showTitle: false),
                          ],
                          centerSpaceRadius: 30,
                          sectionsSpace: 4,
                        ),
                      )
                    : Center(
                        child: Text(l10n.statsNoData,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCards(
    ThemeData theme,
    int avgSteps,
    int latestSteps,
    double avgWeight,
    double latestWeight,
    int avgActivityCalories,
    int workouts,
    int avgWater,
    int latestWater,
    List<double> stepsSeries,
    List<double> weightSeries,
    List<double> activitySeries,
    List<double> waterSeries,
    UserProfile profile,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final waterGoalLiters = profile.waterGoal / 1000.0;
    return Column(
      children: [
        ProgressCard(
            icon: Symbols.footprint,
            title: l10n.steps,
            primaryLine: l10n.statsStepsAvg(avgSteps),
            secondaryLine: l10n.statsStepsLatest(latestSteps),
            color: AppColors.primary,
            goal: profile.stepsGoal,
            metricValue: latestSteps,
            trendData: stepsSeries),
        const SizedBox(height: 8),
        ProgressCard(
            icon: Symbols.weight,
            title: l10n.weight,
            primaryLine: l10n.statsWeightAvgKg(avgWeight.toStringAsFixed(1)),
            secondaryLine:
                l10n.statsWeightLatestKg(latestWeight.toStringAsFixed(1)),
            color: Colors.orange,
            goal: profile.weightGoal,
            isWeight: true,
            metricValue: latestWeight,
            trendData: weightSeries),
        const SizedBox(height: 8),
        ProgressCard(
            icon: Symbols.fitness_center,
            title: l10n.activity,
            primaryLine: l10n.statsActivityAvgKcal(avgActivityCalories),
            secondaryLine: l10n.statsWorkoutsCount(workouts),
            color: Colors.blue,
            goal: 1,
            metricValue: workouts,
            useStrictGoalComparison: true,
            trendData: activitySeries),
        const SizedBox(height: 8),
        ProgressCard(
            icon: Symbols.water_drop,
            title: l10n.water,
            primaryLine:
                l10n.statsWaterAvgL((avgWater / 1000).toStringAsFixed(1)),
            secondaryLine:
                l10n.statsWaterLatestL((latestWater / 1000).toStringAsFixed(1)),
            color: Colors.lightBlue,
            goal: waterGoalLiters,
            isWater: true,
            metricValue: latestWater / 1000,
            trendData: waterSeries),
      ],
    );
  }

  Recipe? _findRecipeByName(String name, List<Recipe> recipes) {
    String normalize(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final target = normalize(name);
    if (target.isEmpty) return null;
    for (final recipe in recipes) {
      final current = normalize(recipe.name);
      if (current == target ||
          current.contains(target) ||
          target.contains(current)) {
        return recipe;
      }
    }
    return null;
  }

  String _localizedMealTime(String raw, AppLocalizations l10n) {
    switch (raw.trim().toLowerCase()) {
      case 'breakfast':
        return l10n.breakfast;
      case 'lunch':
        return l10n.lunch;
      case 'dinner':
        return l10n.dinner;
      case 'snack':
      case 'snacks':
        return l10n.snacks;
      case 'any':
      case '':
        return l10n.statsAiMealTimeAny;
      default:
        return raw;
    }
  }

  String _canonicalMealTime(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'breakfast':
        return 'breakfast';
      case 'lunch':
        return 'lunch';
      case 'dinner':
        return 'dinner';
      case 'snack':
      case 'snacks':
        return 'snack';
      case 'any':
      case '':
        return 'any';
      default:
        return 'any';
    }
  }

  int _mealTimeOrder(String raw) {
    switch (_canonicalMealTime(raw)) {
      case 'breakfast':
        return 0;
      case 'lunch':
        return 1;
      case 'dinner':
        return 2;
      case 'snack':
        return 3;
      case 'any':
      default:
        return 4;
    }
  }

  String _normalizeActionText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _areActionsSimilar(String a, String b) {
    final normalizedA = _normalizeActionText(a);
    final normalizedB = _normalizeActionText(b);

    if (normalizedA.isEmpty || normalizedB.isEmpty) return false;
    if (normalizedA == normalizedB) return true;

    if (normalizedA.length >= 20 && normalizedB.length >= 20) {
      if (normalizedA.contains(normalizedB) ||
          normalizedB.contains(normalizedA)) {
        return true;
      }
    }

    final tokensA =
        normalizedA.split(' ').where((token) => token.length >= 3).toSet();
    final tokensB =
        normalizedB.split(' ').where((token) => token.length >= 3).toSet();

    if (tokensA.isEmpty || tokensB.isEmpty) return false;

    final intersectionSize = tokensA.intersection(tokensB).length.toDouble();
    final jaccard = intersectionSize / (tokensA.union(tokensB).length);
    final coverage = intersectionSize / min(tokensA.length, tokensB.length);

    return jaccard >= 0.72 || coverage >= 0.8;
  }

  List<Map<String, String>> _normalizeSortAndMergeRecommendations(
      List<Map<String, String>> items) {
    final mergedExact = <String, Map<String, String>>{};

    for (final item in items) {
      final action = (item['action'] ?? '').trim();
      if (action.isEmpty) continue;

      final canonicalWhen = _canonicalMealTime(item['when'] ?? '');
      final normalizedAction = _normalizeActionText(action);
      final key = '$canonicalWhen|$normalizedAction';

      final existing = mergedExact[key];
      if (existing == null) {
        mergedExact[key] = {
          'when': canonicalWhen,
          'action': action,
          'recipeName': (item['recipeName'] ?? '').trim(),
        };
      } else {
        final existingRecipe = (existing['recipeName'] ?? '').trim();
        final nextRecipe = (item['recipeName'] ?? '').trim();
        if (existingRecipe.isEmpty && nextRecipe.isNotEmpty) {
          existing['recipeName'] = nextRecipe;
        }
      }
    }

    final softMerged = <Map<String, String>>[];
    for (final candidate in mergedExact.values) {
      final idx = softMerged.indexWhere((existing) {
        return (existing['when'] ?? '') == (candidate['when'] ?? '') &&
            _areActionsSimilar(
                existing['action'] ?? '', candidate['action'] ?? '');
      });

      if (idx == -1) {
        softMerged.add(Map<String, String>.from(candidate));
        continue;
      }

      final existing = softMerged[idx];
      final existingAction = existing['action'] ?? '';
      final candidateAction = candidate['action'] ?? '';
      if (candidateAction.length > existingAction.length) {
        existing['action'] = candidateAction;
      }

      final existingRecipe = (existing['recipeName'] ?? '').trim();
      final candidateRecipe = (candidate['recipeName'] ?? '').trim();
      if (existingRecipe.isEmpty && candidateRecipe.isNotEmpty) {
        existing['recipeName'] = candidateRecipe;
      }
    }

    final result = softMerged
      ..sort((a, b) {
        final byMeal = _mealTimeOrder(a['when'] ?? '')
            .compareTo(_mealTimeOrder(b['when'] ?? ''));
        if (byMeal != 0) return byMeal;
        return (a['action'] ?? '').compareTo(b['action'] ?? '');
      });

    return result;
  }

  Widget _buildAiCircleIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Symbols.auto_awesome,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildAverageMetricsCard(ThemeData theme, Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final aiInput = data['aiInput'] as Map<String, dynamic>;
    final metrics = <({String label, String value})>[
      (
        label: l10n.calories,
        value: '${(aiInput['avgCalories'] as num).round()} ${l10n.kcal}'
      ),
      (
        label: l10n.protein,
        value:
            '${(aiInput['avgProteinGrams'] as num).toStringAsFixed(1)} ${l10n.gram}'
      ),
      (
        label: l10n.fat,
        value:
            '${(aiInput['avgFatGrams'] as num).toStringAsFixed(1)} ${l10n.gram}'
      ),
      (
        label: l10n.carbs,
        value:
            '${(aiInput['avgCarbsGrams'] as num).toStringAsFixed(1)} ${l10n.gram}'
      ),
      (
        label: l10n.fiber,
        value:
            '${(aiInput['avgFiberGrams'] as num).toStringAsFixed(1)} ${l10n.gram}'
      ),
      (
        label: l10n.sugar,
        value:
            '${(aiInput['avgSugarGrams'] as num).toStringAsFixed(1)} ${l10n.gram}'
      ),
      (
        label: l10n.sodium,
        value:
            '${(aiInput['avgSodiumMg'] as num).toStringAsFixed(0)} ${l10n.mg}'
      ),
      (
        label: l10n.potassium,
        value:
            '${(aiInput['avgPotassiumMg'] as num).toStringAsFixed(0)} ${l10n.mg}'
      ),
      (
        label: l10n.calcium,
        value:
            '${(aiInput['avgCalciumMg'] as num).toStringAsFixed(0)} ${l10n.mg}'
      ),
      (
        label: l10n.iron,
        value: '${(aiInput['avgIronMg'] as num).toStringAsFixed(1)} ${l10n.mg}'
      ),
      (
        label: l10n.vitaminA,
        value:
            '${(aiInput['avgVitaminAMcg'] as num).toStringAsFixed(0)} ${l10n.mcg}'
      ),
      (
        label: l10n.vitaminC,
        value:
            '${(aiInput['avgVitaminCMg'] as num).toStringAsFixed(1)} ${l10n.mg}'
      ),
      (
        label: l10n.vitaminD,
        value:
            '${(aiInput['avgVitaminDMcg'] as num).toStringAsFixed(1)} ${l10n.mcg}'
      ),
    ];

    Widget buildMetricRow(({String label, String value}) item, int index) {
      final isEven = index.isEven;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: isEven
              ? theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              item.value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.statsAverageValuesPeriod}: ${_periodLabel(context)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (var i = 0; i < metrics.length; i++)
                  buildMetricRow(metrics[i], i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiReportCard(
    BuildContext context,
    ThemeData theme,
    List<Recipe> recipes,
    bool aiAssistantEnabled,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.watch<ProfileProvider>().profile;
    if (profile != null && !profile.isAiAnalyticsAvailable) {
      return Card(
        color: Colors.amber.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: AppStyles.largeBorderRadius,
          side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(Symbols.workspace_premium, color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              Text(
                l10n.aiAnalyticsOnlyInPremium,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.push('/subscription', extra: SubscriptionTier.premium),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.upgradeToPremium),
              ),
            ],
          ),
        ),
      );
    }

    if (!aiAssistantEnabled) {
      return Card(
        color: const Color.fromARGB(255, 147, 242, 154).withAlpha(20),
        shape: RoundedRectangleBorder(
          borderRadius: AppStyles.largeBorderRadius,
          side: BorderSide(
              color: const Color.fromARGB(252, 179, 250, 209).withAlpha(51)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            l10n.statsAiDisabledInSettings,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final isPreparing =
        _isDebouncePending || (_aiOverview == null && !_aiError);
    final overviewText = _aiOverview?.trim() ?? '';
    return Card(
      color: const Color.fromARGB(255, 147, 242, 154).withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
        side: BorderSide(
            color: const Color.fromARGB(252, 179, 250, 209).withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.statsAnalysisFor(_periodLabel(context)),
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(255),
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (!isPreparing && !_aiError && overviewText.isNotEmpty)
              _buildAiOverviewSections(theme, overviewText),
            const SizedBox(height: 8),
            if (isPreparing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подготовка',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(minHeight: 3),
                    ),
                  ),
                ],
              )
            else if (_aiError)
              Text(
                l10n.statsAiError,
                style: theme.textTheme.bodySmall,
              )
            else if (_aiRecommendations.isEmpty && overviewText.isEmpty)
              Text(
                l10n.statsAiError,
                style: theme.textTheme.bodySmall,
              )
            else if (_aiRecommendations.isEmpty)
              const SizedBox.shrink()
            else
              ..._aiRecommendations.map((item) {
                final when = item['when'] ?? '';
                final action = item['action'] ?? '';
                final recipeName = item['recipeName'] ?? '';
                final matchedRecipe = _findRecipeByName(recipeName, recipes);
                final whenLabel = _localizedMealTime(when, l10n);

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.statsAiMealTimeLabel}: $whenLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(action, style: theme.textTheme.bodySmall),
                      if (recipeName.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${l10n.statsAiRecipeLabel}: $recipeName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (matchedRecipe != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              context.push(
                                '/recipe_detail',
                                extra: {'recipe': matchedRecipe},
                              );
                            },
                            icon: const Icon(Symbols.open_in_new, size: 16),
                            label: Text(l10n.statsAiOpenRecipe),
                          ),
                        )
                      else if (recipeName.isNotEmpty)
                        Text(
                          l10n.statsAiRecipeNotFound,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                l10n.statsAiDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiOverviewSections(ThemeData theme, String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);

    if (paragraphs.isEmpty) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withAlpha(204),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: i == paragraphs.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.16),
              ),
            ),
            child: Text(
              paragraphs[i],
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.35,
                color: theme.colorScheme.onSurface.withAlpha(214),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton(
      {required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected ? AppColors.primary : theme.cardColor,
      borderRadius: AppStyles.buttonRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.buttonRadius,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected
                    ? AppColors.onPrimary
                    : theme.colorScheme.onSurface.withAlpha(178),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<double> data;
  final double goal;
  final Color lineColor;
  final Color gradientColor;
  final List<String>? labels;
  final bool isWeight;
  final bool hideZeroValues;
  final String? goalLabel;
  final String? unit;

  const _LineChart({
    required this.data,
    required this.goal,
    required this.lineColor,
    required this.gradientColor,
    this.labels,
    this.isWeight = false,
    this.hideZeroValues = false,
    this.goalLabel,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bool shouldHideZeroValues = isWeight || hideZeroValues;
    final List<double> chartData =
        shouldHideZeroValues ? data.where((d) => d > 0).toList() : data;
    final bool hasData = chartData.isNotEmpty;

    double minY = hasData ? chartData.reduce(min) : 0;
    double maxY = hasData ? chartData.reduce(max) : goal;

    minY = min(minY, goal);
    maxY = max(maxY, goal);

    if (minY == maxY) {
      minY -= 10;
      maxY += 10;
    }

    final double verticalPadding = (maxY - minY) * 0.2;
    minY -= verticalPadding;
    maxY += verticalPadding;

    if (minY < 0 && chartData.every((d) => d >= 0)) {
      minY = 0;
    }

    List<LineChartBarData> generateLineBars() {
      if (shouldHideZeroValues) {
        final List<LineChartBarData> lineBars = [];
        List<FlSpot> currentSegment = [];

        for (int i = 0; i < data.length; i++) {
          if (data[i] > 0) {
            currentSegment.add(FlSpot(i.toDouble(), data[i]));
          } else {
            if (currentSegment.isNotEmpty) {
              lineBars.add(LineChartBarData(
                spots: currentSegment,
                isCurved: true,
                color: lineColor,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: false),
              ));
              currentSegment = [];
            }
          }
        }
        if (currentSegment.isNotEmpty) {
          lineBars.add(LineChartBarData(
            spots: currentSegment,
            isCurved: true,
            color: lineColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ));
        }
        return lineBars;
      } else {
        return [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: lineColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [gradientColor, gradientColor.withAlpha(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ];
      }
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
          child: hasData
              ? LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => theme.cardColor,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(isWeight ? 1 : 0)} ${unit ?? (isWeight ? 'кг' : 'ккал')}',
                              TextStyle(
                                color: spot.bar.color ?? lineColor,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: theme.dividerColor.withAlpha(50),
                          strokeWidth: 1,
                          dashArray: [4, 2],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(
                                    value.toStringAsFixed(isWeight ? 1 : 0),
                                    style: theme.textTheme.bodySmall),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: labels != null,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (labels == null ||
                                value.toInt() >= labels!.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Text(labels![value.toInt()],
                                  style: theme.textTheme.bodySmall),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: generateLineBars(),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: goal,
                          color: theme.dividerColor.withAlpha(204),
                          strokeWidth: 2,
                          dashArray: [8, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 5, bottom: 2),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.dividerColor),
                            labelResolver: (_) =>
                                goalLabel ??
                                (isWeight
                                    ? 'Цель: ${goal.toStringAsFixed(1)} кг'
                                    : 'Цель: ${goal.toInt()} ккал'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                  l10n.statsNoDataToDisplay,
                  style: theme.textTheme.bodySmall,
                )),
        ),
      ),
    );
  }
}
