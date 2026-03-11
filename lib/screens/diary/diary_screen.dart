import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/fatsecret_food.dart';
import '../../providers/diary_provider.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Consumer<DiaryProvider>(
      builder: (context, diaryProvider, child) {
        final meals = diaryProvider.meals;
        final totalCaloriesConsumed = meals.values
            .expand((element) => element)
            .fold<double>(0, (sum, item) => sum + (item.servings?.first.calories ?? 0));

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Symbols.calendar_today, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 8),
                Text('Сегодня', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Symbols.notifications, color: theme.colorScheme.primary),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Symbols.search, color: theme.colorScheme.primary),
                onPressed: () => context.go('/search'),
              ),
            ],
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCaloriesProgress(context, totalCaloriesConsumed.toInt()),
                const SizedBox(height: 24),
                _buildMacronutrients(context, meals),
                const SizedBox(height: 24),
                _buildMealsSection(context, meals),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaloriesProgress(BuildContext context, int consumed) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    const int goal = 2100;
    final remaining = goal - consumed;
    final progress = consumed > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 16,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(remaining.toString(),
                          style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2)),
                      Text('ОСТАЛОСЬ ККАЛ', style: textTheme.labelMedium?.copyWith(color: Colors.grey, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, Symbols.restaurant, consumed.toString(), 'ЕДА'),
              _buildStatItem(context, Symbols.local_fire_department, '160', 'УПР-ИЯ'),
              _buildStatItem(context, Symbols.flag, goal.toString(), 'ЦЕЛЬ'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildMacronutrients(BuildContext context, Map<String, List<FatsecretFood>> allMeals) {
    final totalCarbs = allMeals.values
        .expand((i) => i)
        .fold<double>(0, (sum, item) => sum + (item.servings?.first.carbohydrate ?? 0));
    final totalProtein = allMeals.values
        .expand((i) => i)
        .fold<double>(0, (sum, item) => sum + (item.servings?.first.protein ?? 0));
    final totalFat =
        allMeals.values.expand((i) => i).fold<double>(0, (sum, item) => sum + (item.servings?.first.fat ?? 0));

    return Row(
      children: [
        Expanded(child: _buildMacroCard(context, 'Углеводы', totalCarbs, 250)),
        const SizedBox(width: 12),
        Expanded(child: _buildMacroCard(context, 'Белки', totalProtein, 150)),
        const SizedBox(width: 12),
        Expanded(child: _buildMacroCard(context, 'Жиры', totalFat, 70)),
      ],
    );
  }

  Widget _buildMacroCard(BuildContext context, String title, double current, double total) {
    final theme = Theme.of(context);
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${current.toInt()}г', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' / ${total.toInt()}г', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ));
  }

  Widget _buildMealsSection(BuildContext context, Map<String, List<FatsecretFood>> allMeals) {
    final theme = Theme.of(context);

    final mealConfigs = {
      'Завтрак': {'icon': Symbols.wb_sunny, 'recommendation': '450 - 600 ккал'},
      'Обед': {'icon': Symbols.lunch_dining, 'recommendation': '600 - 800 ккал'},
      'Ужин': {'icon': Symbols.nights_stay, 'recommendation': '450 - 600 ккал'},
      'Перекус': {'icon': Symbols.cookie, 'recommendation': '150 - 250 ккал'},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Приемы пищи', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('История')),
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: allMeals.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final mealName = allMeals.keys.elementAt(index);
            final mealItems = allMeals[mealName]!;
            final mealConfig = mealConfigs[mealName]!;
            final totalCalories =
                mealItems.fold<double>(0, (sum, item) => sum + (item.servings?.first.calories ?? 0));
            final isFaded = mealItems.isEmpty;

            return _buildMealCard(
              context,
              mealConfig['icon'] as IconData,
              mealName, // Pass the meal name here
              mealConfig['recommendation'] as String,
              '${totalCalories.toInt()} ккал',
              mealItems,
              isFaded: isFaded,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String calories,
    List<FatsecretFood> items,
    {bool isFaded = false}
  ) {
    final theme = Theme.of(context);
    final color = isFaded ? Colors.grey : theme.colorScheme.primary;

    return Opacity(
      opacity: isFaded ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text(subtitle,
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(calories, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/search'),
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        backgroundColor: color,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: isFaded ? 0 : 5,
                        shadowColor: color.withOpacity(0.5),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                )
              ],
            ),
            if (items.isNotEmpty) ...[
              const Divider(height: 24, thickness: 0.5),
              ...items.map((item) => _buildFoodItemTile(context, title, item)) // Pass meal name (title) here
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItemTile(BuildContext context, String mealName, FatsecretFood item) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          // Placeholder image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
                width: 40, height: 40, color: Colors.grey.shade300, child: const Icon(Symbols.restaurant, color: Colors.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text('${item.servings?.first.servingDescription ?? 'N/A'}, ${item.servings?.first.calories?.toInt() ?? 0} ккал',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {
              Provider.of<DiaryProvider>(context, listen: false).removeFood(mealName, item);
            },
          ),
        ],
      ),
    );
  }
}
