import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../providers/diary_provider.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _selectedChipIndex = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Анализ', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Symbols.share), onPressed: () {})],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Consumer<DiaryProvider>(
        builder: (context, diaryProvider, child) {
          final totalCalories = diaryProvider.meals.values
              .expand((e) => e)
              .fold(0.0, (sum, item) => sum + (item.servings?.first.calories ?? 0));
          final totalCarbs = diaryProvider.meals.values
              .expand((e) => e)
              .fold(0.0, (sum, item) => sum + (item.servings?.first.carbohydrate ?? 0));
          final totalProtein = diaryProvider.meals.values
              .expand((e) => e)
              .fold(0.0, (sum, item) => sum + (item.servings?.first.protein ?? 0));
          final totalFat = diaryProvider.meals.values
              .expand((e) => e)
              .fold(0.0, (sum, item) => sum + (item.servings?.first.fat ?? 0));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTimeToggle(context),
                const SizedBox(height: 24),
                _buildCaloriesChart(context, totalCalories),
                const SizedBox(height: 24),
                _buildMacronutrientsChart(context, totalCarbs, totalProtein, totalFat),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeToggle(BuildContext context) {
    final chips = ['День', 'Неделя', 'Месяц'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chips.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: ChoiceChip(
            label: Text(chips[index]),
            selected: _selectedChipIndex == index,
            onSelected: (selected) {
              if (selected) setState(() => _selectedChipIndex = index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildCaloriesChart(BuildContext context, double totalCalories) {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Калории', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Icon(Symbols.show_chart, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), (i == 6 ? totalCalories / 100 : i * 20 + 5).toDouble())),
                    isCurved: true,
                    color: theme.primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: theme.primaryColor.withOpacity(0.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacronutrientsChart(BuildContext context, double carbs, double protein, double fat) {
    final theme = Theme.of(context);
    final totalMacros = carbs + protein + fat;
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Макронутриенты', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Icon(Symbols.pie_chart, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: protein, color: const Color(0xFF5B92E5), title: '${(protein / totalMacros * 100).toStringAsFixed(0)}%', radius: 60),
                  PieChartSectionData(value: fat, color: const Color(0xFFF5A623), title: '${(fat / totalMacros * 100).toStringAsFixed(0)}%', radius: 60),
                  PieChartSectionData(value: carbs, color: const Color(0xFFF3646E), title: '${(carbs / totalMacros * 100).toStringAsFixed(0)}%', radius: 60),
                ],
                centerSpaceRadius: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
