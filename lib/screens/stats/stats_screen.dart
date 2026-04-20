import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../models/daily_log.dart';
import '../../models/user_profile.dart';
import '../../services/daily_log_service.dart';
import '../../services/profile_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, dynamic>> _loadData() async {
    developer.log('Starting to load data for stats screen...',
        name: 'StatsScreen');
    final now = DateTime.now();
    final startDate = switch (_period) {
      _StatsPeriod.week => DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1)),
      _StatsPeriod.month => DateTime.utc(now.year, now.month, 1),
      _StatsPeriod.year => DateTime.utc(now.year, 1, 1),
    };
    final endDate = switch (_period) {
      _StatsPeriod.week => startDate.add(const Duration(days: 6)),
      _StatsPeriod.month => DateTime.utc(now.year, now.month + 1, 0),
      _StatsPeriod.year => DateTime.utc(now.year, 12, 31),
    };

    final logs = await _logService.getLogsForPeriod(startDate, endDate);
    final profile = await _profileService.loadProfile();

    List<double> caloriesData;
    List<double> weightData;
    if (_period == _StatsPeriod.year) {
      caloriesData = List<double>.filled(12, 0);
      weightData = List<double>.filled(12, 0);

      for (int month = 1; month <= 12; month++) {
        final monthLogs = logs.where((log) => log.date.month == month).toList();
        caloriesData[month - 1] = monthLogs.fold<double>(
          0,
          (sum, log) => sum + log.totalNutrients.calories,
        );

        final monthWeightLogs =
            monthLogs.where((log) => log.weight != null).toList();
        if (monthWeightLogs.isNotEmpty) {
          weightData[month - 1] = monthWeightLogs.last.weight ?? 0.0;
        }
      }
    } else {
      caloriesData = logs.map((log) => log.totalNutrients.calories).toList();
      weightData = logs.map((log) => log.weight ?? 0.0).toList();
    }

    int logCount = logs.where((log) => !log.isEmpty).length;
    if (logCount == 0) logCount = 1;

    final totalCarbs =
        logs.fold<double>(0, (sum, log) => sum + log.totalNutrients.carbs);
    final totalProtein =
        logs.fold<double>(0, (sum, log) => sum + log.totalNutrients.protein);
    final totalFat =
        logs.fold<double>(0, (sum, log) => sum + log.totalNutrients.fat);
    final totalMacros = totalCarbs + totalProtein + totalFat;

    final avgCarbs = totalMacros > 0 ? (totalCarbs / totalMacros) * 100 : 0;
    final avgProtein = totalMacros > 0 ? (totalProtein / totalMacros) * 100 : 0;
    final avgFat = totalMacros > 0 ? (totalFat / totalMacros) * 100 : 0;

    final avgSteps =
        logs.fold<int>(0, (sum, log) => sum + log.steps) ~/ logCount;
    final latestStepsLog = logs.lastWhere((log) => log.steps > 0,
        orElse: () => DailyLog.empty(now));
    final latestSteps = latestStepsLog.steps;

    final latestWeightLog = logs.lastWhere((log) => log.weight != null,
        orElse: () => DailyLog.empty(now));
    final latestWeight = latestWeightLog.weight ?? profile.weight;
    final weightLogs = logs.where((log) => log.weight != null).toList();
    final avgWeight = weightLogs.isEmpty
        ? latestWeight
        : weightLogs.fold<double>(0, (sum, log) => sum + (log.weight ?? 0)) /
            weightLogs.length;

    int workouts = 0;
    int totalActivityCalories = 0;
    for (final log in logs) {
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
    final avgWater =
        logs.fold<int>(0, (sum, log) => sum + log.waterIntake) ~/ logCount;
    final latestWaterLog = logs.lastWhere((log) => log.waterIntake > 0,
        orElse: () => DailyLog.empty(now));
    final latestWater = latestWaterLog.waterIntake;

    const aiReport = 'Отчет от AI временно отключен.';

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
      'profile': profile,
      'aiReport': aiReport,
      'periodLabel': _periodLabel(),
    };
  }

  String _periodLabel() {
    switch (_period) {
      case _StatsPeriod.week:
        return 'недели';
      case _StatsPeriod.month:
        return 'месяца';
      case _StatsPeriod.year:
        return 'года';
    }
  }

  List<String>? _chartLabels() {
    switch (_period) {
      case _StatsPeriod.week:
        return const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      case _StatsPeriod.month:
        return null;
      case _StatsPeriod.year:
        return const [
          'Янв',
          'Фев',
          'Мар',
          'Апр',
          'Май',
          'Июн',
          'Июл',
          'Авг',
          'Сен',
          'Окт',
          'Ноя',
          'Дек'
        ];
    }
  }

  void _onPeriodChanged(_StatsPeriod period) {
    setState(() {
      _period = period;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Ошибка загрузки данных: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Нет данных для анализа.'));
          }

          final data = snapshot.data!;
          final UserProfile profile = data['profile'];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                            'Аналитика помогает увидеть общую картину\n'
                            'по питанию, воде, весу и активности за период.\n'
                            'Используйте ее, чтобы вовремя корректировать цели\n'
                            'и отслеживать устойчивый прогресс без перегруза.',
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
                Text('Динамика калорий', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildCaloriesChart(
                    theme, data['calories'], profile.calorieGoal.toDouble()),
                const SizedBox(height: 24),
                Text('Динамика веса', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildWeightChart(theme, data['weight'], profile.weightGoal),
                const SizedBox(height: 24),
                Text('Среднее БЖУ', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
                _buildPieChartAndLegend(
                    theme,
                    (data['avgCarbs'] as num).toDouble(),
                    (data['avgProtein'] as num).toDouble(),
                    (data['avgFat'] as num).toDouble()),
                const SizedBox(height: 24),
                Text('Прогресс', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 16),
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
                  profile,
                ),
                Text('Отчет от AI', style: theme.textTheme.headlineSmall),
                _buildAiReportCard(
                    theme, data['aiReport'], data['periodLabel']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodToggle(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppStyles.buttonRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              text: 'Неделя',
              isSelected: _period == _StatsPeriod.week,
              onTap: () => _onPeriodChanged(_StatsPeriod.week),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              text: 'Месяц',
              isSelected: _period == _StatsPeriod.month,
              onTap: () => _onPeriodChanged(_StatsPeriod.month),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              text: 'Год',
              isSelected: _period == _StatsPeriod.year,
              onTap: () => _onPeriodChanged(_StatsPeriod.year),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart(
      ThemeData theme, List<double> calories, double goal) {
    return _LineChart(
      data: calories,
      goal: goal,
      lineColor: AppColors.primary,
      gradientColor: AppColors.primary.withAlpha(77),
      labels: _chartLabels(),
      hideZeroValues: true,
    );
  }

  Widget _buildWeightChart(
      ThemeData theme, List<double> weightData, double goal) {
    return _LineChart(
      data: weightData,
      goal: goal,
      lineColor: Colors.orange,
      gradientColor: Colors.orange.withAlpha(77),
      labels: _chartLabels(),
      isWeight: true,
    );
  }

  Widget _buildPieChartAndLegend(
      ThemeData theme, double carbs, double protein, double fat) {
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
                      text: 'Углеводы',
                      percentage: carbs.round()),
                  const SizedBox(height: 12),
                  ChartLegendItem(
                      color: Colors.orange,
                      text: 'Белки',
                      percentage: protein.round()),
                  const SizedBox(height: 12),
                  ChartLegendItem(
                      color: Colors.blue,
                      text: 'Жиры',
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
                        child: Text('Нет данных',
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
    UserProfile profile,
  ) {
    final waterGoalLiters = profile.waterGoal / 1000.0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        ProgressCard(
            icon: Symbols.footprint,
            title: 'Шаги',
            primaryLine: 'Среднее: $avgSteps шагов',
            secondaryLine: 'Последнее: $latestSteps шагов',
            color: AppColors.primary,
            goal: profile.stepsGoal),
        ProgressCard(
            icon: Symbols.weight,
            title: 'Вес',
            primaryLine: 'Среднее: ${avgWeight.toStringAsFixed(1)} кг',
            secondaryLine: 'Последнее: ${latestWeight.toStringAsFixed(1)} кг',
            color: Colors.orange,
            goal: profile.weightGoal,
            isWeight: true),
        ProgressCard(
            icon: Symbols.fitness_center,
            title: 'Активность',
            primaryLine: 'Среднее: $avgActivityCalories ккал',
            secondaryLine: 'Тренировок: $workouts',
            color: Colors.blue),
        ProgressCard(
            icon: Symbols.water_drop,
            title: 'Вода',
            primaryLine: 'Среднее: ${(avgWater / 1000).toStringAsFixed(1)} л',
            secondaryLine:
                'Последнее: ${(latestWater / 1000).toStringAsFixed(1)} л',
            color: Colors.lightBlue,
            goal: waterGoalLiters,
            isWater: true),
      ],
    );
  }

  Widget _buildAiReportCard(
      ThemeData theme, String aiReport, String periodLabel) {
    return Card(
      color: const Color.fromARGB(255, 147, 242, 154).withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
        side: BorderSide(
            color: const Color.fromARGB(252, 179, 250, 209).withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            const Icon(Symbols.smart_toy,
                color: AppColors.primary, size: 32, fill: 1),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Анализ $periodLabel',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(255),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    aiReport,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withAlpha(204)),
                  ),
                ],
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

  const _LineChart({
    required this.data,
    required this.goal,
    required this.lineColor,
    required this.gradientColor,
    this.labels,
    this.isWeight = false,
    this.hideZeroValues = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                              '${spot.y.toStringAsFixed(isWeight ? 1 : 0)} ${isWeight ? 'кг' : 'ккал'}',
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
                            labelResolver: (_) => isWeight
                                ? 'Цель: ${goal.toStringAsFixed(1)} кг'
                                : 'Цель: ${goal.toInt()} ккал',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                  'Нет данных для отображения',
                  style: theme.textTheme.bodySmall,
                )),
        ),
      ),
    );
  }
}
