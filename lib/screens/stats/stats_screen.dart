import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import 'dart:math';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isWeekly = true; // Переключатель Неделя/Месяц

  // --- Mock Data ---
  List<double> get _weeklyCalories => [2100, 2300, 2200, 2500, 2400, 2600, 2000];
  List<double> get _monthlyCalories => List.generate(30, (i) => 2000 + Random().nextDouble() * 600);

  List<double> get _weeklyWeight => [75.5, 75.2, 75.3, 75.0, 74.8, 74.9, 74.6];
  List<double> get _monthlyWeight => List.generate(30, (i) => 75 - (i * 0.1) + (Random().nextDouble() * 0.4 - 0.2));

  final double _avgCarbs = 45;
  final double _avgProtein = 30;
  final double _avgFat = 25;
  // ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Увеличен нижний отступ
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodToggle(theme),
            const SizedBox(height: 24),
            Text('Динамика калорий', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildCaloriesChart(theme),
            const SizedBox(height: 24),
            Text('Динамика веса', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildWeightChart(theme),
            const SizedBox(height: 24),
            Text('Среднее БЖУ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildPieChartAndLegend(theme),
            const SizedBox(height: 24),
            Text('Прогресс', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildProgressCards(theme),
            const SizedBox(height: 16), // Уменьшен отступ
            Text('Отчет от AI', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildAiReportCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle(ThemeData theme) {
    return Center(
      child: ToggleButtons(
        isSelected: [_isWeekly, !_isWeekly],
        onPressed: (index) {
          setState(() {
            _isWeekly = index == 0;
          });
        },
        borderRadius: AppStyles.defaultBorderRadius,
        selectedColor: Colors.white,
        fillColor: AppColors.primary,
        color: AppColors.primary,
        constraints: BoxConstraints(minWidth: (MediaQuery.of(context).size.width - 40) / 2, minHeight: 40),
        children: const [
          Text('Неделя'),
          Text('Месяц'),
        ],
      ),
    );
  }

  Widget _buildCaloriesChart(ThemeData theme) {
    final data = _isWeekly ? _weeklyCalories : _monthlyCalories;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
         shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
         child: Padding(
            padding: const EdgeInsets.only(top: 24, right: 24, bottom: 12, left: 12),
           child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                minY: 1500,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(sideTitles: _bottomTitles()),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
         ),
      ),
    );
  }

  Widget _buildWeightChart(ThemeData theme) {
    final data = _isWeekly ? _weeklyWeight : _monthlyWeight;
    final minY = data.reduce(min).floorToDouble() - 1;
    final maxY = data.reduce(max).ceilToDouble() + 1;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
         shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
         child: Padding(
            padding: const EdgeInsets.only(top: 24, right: 24, bottom: 12, left: 12),
           child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i])),
                    isCurved: true,
                    color: Colors.green.shade600,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(sideTitles: _bottomTitles()),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
         ),
      ),
    );
  }


  SideTitles _bottomTitles() {
    return SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (double value, TitleMeta meta) {
        String text = '';
        if (_isWeekly) {
          const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
          if (value.toInt() < days.length) {
             text = days[value.toInt()];
          }
        } else {
          if ((value.toInt() + 1) % 5 == 0) {
            text = (value.toInt() + 1).toString();
          }
        }
        return SideTitleWidget(
          meta: meta, 
          space: 4,
          child: Text(text, style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _buildPieChartAndLegend(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: AspectRatio(
                aspectRatio: 1,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(value: _avgCarbs, color: AppColors.primary, title: '${_avgCarbs.round()}%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(value: _avgProtein, color: Colors.orange, title: '${_avgProtein.round()}%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(value: _avgFat, color: Colors.blue, title: '${_avgFat.round()}%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(theme, AppColors.primary, 'Углеводы', '~${(2200 * _avgCarbs / 100 / 4).round()} г'),
                  const SizedBox(height: 12),
                  _buildLegendItem(theme, Colors.orange, 'Белки', '~${(2200 * _avgProtein / 100 / 4).round()} г'),
                  const SizedBox(height: 12),
                  _buildLegendItem(theme, Colors.blue, 'Жиры', '~${(2200 * _avgFat / 100 / 9).round()} г'),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, Color color, String name, String value) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.bodyMedium),
            Text(value, style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCards(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      padding: EdgeInsets.zero,
      children: [
        _buildProgressCard(theme, 'Шаги', '8,450', '+1.2к', true), 
        _buildProgressCard(theme, 'Средний вес', '75.2 кг', '-0.8 кг', false),
        _buildProgressCard(theme, 'Тренировки', '3 в нед.', '+1', true),
        _buildProgressCard(theme, 'Выпито воды', '1.8 л', '+200 мл', true),
      ],
    );
  }

  Widget _buildProgressCard(ThemeData theme, String title, String value, String change, bool isPositive) {
    final color = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.mediumBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.labelMedium),
            Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                 Text(change, style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAiReportCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Symbols.auto_awesome, color: AppColors.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Еженедельный отчет', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Отличная работа на этой неделе! Ваш вес стабильно снижается, а калорийность остается в пределах нормы. Попробуйте добавить еще одну тренировку и увеличить количество шагов до 10 000 в день для лучшего результата.',
                    style: theme.textTheme.bodyMedium,
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
