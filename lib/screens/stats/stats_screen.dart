import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../models/daily_log.dart';
import '../../models/user_profile.dart';
import '../../services/daily_log_service.dart';
import '../../services/gemini_recipe_service.dart';
import '../../services/profile_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'widgets/chart_legend_item.dart';
import 'widgets/progress_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _StatsPeriod { week, month, year }

class _StatsScreenState extends State<StatsScreen> {
  _StatsPeriod _period = _StatsPeriod.week;
  final DailyLogService _logService = DailyLogService();
  final ProfileService _profileService = ProfileService();
  final GeminiRecipeService _geminiRecipeService = GeminiRecipeService();
  late Future<Map<String, dynamic>> _statsFuture;
  String? _aiReport;
  bool _aiError = false;
  int _dataRequestId = 0;
  int _aiStartedForRequestId = -1;

  @override
  void initState() {
    super.initState();
    _reloadStats();
  }

  void _reloadStats() {
    _dataRequestId++;
    _aiStartedForRequestId = -1;
    setState(() {
      _aiReport = null;
      _aiError = false;
      _statsFuture = _loadData();
    });
  }

  Future<Map<String, dynamic>> _loadData() async {
    developer.log('Starting to load data for stats screen...',
        name: 'StatsScreen');
    final now = DateTime.now();
    final startDate = switch (_period) {
      _StatsPeriod.week => now.subtract(const Duration(days: 6)),
      _StatsPeriod.month => now.subtract(const Duration(days: 29)),
      _StatsPeriod.year => now.subtract(const Duration(days: 364)),
    };
    final endDate = now;

    final logs = await _logService.getLogsForPeriod(startDate, endDate);
    final profile = await _profileService.loadProfile();

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
      'aiInput': {
        'periodLabel': _period.name,
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
      },
    };
  }

  Future<void> _loadAiReport(
      Map<String, dynamic> aiInput, int requestId) async {
    try {
      final aiReport = await _geminiRecipeService.generateStatsReport(
        periodLabel: aiInput['periodLabel'] as String,
        calorieGoal: aiInput['calorieGoal'] as int,
        proteinGoal: aiInput['proteinGoal'] as int,
        fatGoal: aiInput['fatGoal'] as int,
        carbsGoal: aiInput['carbsGoal'] as int,
        avgCalories: (aiInput['avgCalories'] as num).toDouble(),
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
      );

      if (!mounted || requestId != _dataRequestId) return;
      setState(() {
        _aiReport = aiReport;
        _aiError = false;
      });
    } on GeminiRecipeException catch (e) {
      developer.log('AI report error: ${e.message}', name: 'StatsScreen');
      if (!mounted || requestId != _dataRequestId) return;
      setState(() {
        _aiError = true;
      });
    } catch (e) {
      developer.log('AI report error: $e', name: 'StatsScreen');
      if (!mounted || requestId != _dataRequestId) return;
      setState(() {
        _aiError = true;
      });
    }
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(l10n.statsErrorLoading(snapshot.error.toString())));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text(l10n.statsNoDataForAnalysis));
          }

          final data = snapshot.data!;
          final requestId = _dataRequestId;
          if (_aiStartedForRequestId != requestId) {
            _aiStartedForRequestId = requestId;
            _loadAiReport(data['aiInput'] as Map<String, dynamic>, requestId);
          }
          final UserProfile profile = data['profile'];
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
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppStyles.largeBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Symbols.info,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.statsInfoText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(l10n.statsCaloriesDynamics,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildCaloriesChart(context, theme, data['calories'],
                    profile.calorieGoal.toDouble()),
                const SizedBox(height: 24),
                Text(l10n.statsWeightDynamics,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildWeightChart(
                    context, theme, data['weight'], profile.weightGoal),
                const SizedBox(height: 24),
                Text(l10n.statsAvgMacros, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildPieChartAndLegend(
                    context,
                    theme,
                    (data['avgCarbs'] as num).toDouble(),
                    (data['avgProtein'] as num).toDouble(),
                    (data['avgFat'] as num).toDouble()),
                const SizedBox(height: 24),
                Text(l10n.statsProgress, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                _buildProgressCards(
                  theme,
                  data['avgSteps'],
                  data['latestSteps'],
                  data['avgWeight'],
                  data['latestWeight'],
                  data['avgActivityCalories'],
                  data['workouts'],
                  data['avgWater'],
                  data['latestWater'],
                  stepsTrend,
                  weightTrend,
                  activityTrend,
                  waterTrend,
                  profile,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Symbols.smart_toy,
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.statsAiReportTitle,
                        style: theme.textTheme.headlineSmall),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAiReportCard(context, theme),
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

  Widget _buildAiReportCard(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final String reportText;
    if (_aiError) {
      reportText = l10n.statsAiError;
    } else if (_aiReport == null) {
      reportText = l10n.statsAiLoading;
    } else {
      reportText = _aiReport!;
    }
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
            Text(
              reportText,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withAlpha(204)),
            ),
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
