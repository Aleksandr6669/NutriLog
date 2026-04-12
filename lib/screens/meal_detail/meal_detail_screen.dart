import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../recipes/recipe_detail_screen.dart';

class MealDetailScreen extends StatelessWidget {
  final String mealName;
  final List<FoodItem> items;

  const MealDetailScreen({super.key, required this.mealName, required this.items});

  @override
  Widget build(BuildContext context) {
    final foodItems = items;
    final totalNutrients = foodItems.fold<NutritionalInfo>(
      NutritionalInfo.zero,
      (sum, item) => sum + item.nutrients,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(mealName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add_circle_outline),
            onPressed: () { 
              // TODO: Implement add food functionality
            },
            tooltip: 'Добавить продукт',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MealSummaryCard(totalNutrients: totalNutrients),
            const SizedBox(height: 24),
            _FoodItemsList(foodItems: foodItems),
            const SizedBox(height: 24),
            _NutritionDetailsList(totalNutrients: totalNutrients),
          ],
        ),
      ),
    );
  }
}

class _MealSummaryCard extends StatelessWidget {
  final NutritionalInfo totalNutrients;

  const _MealSummaryCard({required this.totalNutrients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mock goals for demonstration
    const double proteinGoal = 50;
    const double carbsGoal = 100;
    const double fatGoal = 30;

    final carbsPercent = carbsGoal > 0 ? (totalNutrients.carbs / carbsGoal).clamp(0.0, 1.0) : 0.0;
    final proteinPercent = proteinGoal > 0 ? (totalNutrients.protein / proteinGoal).clamp(0.0, 1.0) : 0.0;
    final fatPercent = fatGoal > 0 ? (totalNutrients.fat / fatGoal).clamp(0.0, 1.0) : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
             Text('Сводка за прием пищи', style: theme.textTheme.headlineSmall),
             const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _MacronutrientCard(
                  name: 'Углеводы',
                  value: '${totalNutrients.carbs.round()}г',
                  total: '${carbsGoal.round()}г',
                  percentage: carbsPercent,
                  color: AppColors.primary
                )),
                const SizedBox(width: 12),
                Expanded(child: _MacronutrientCard(
                  name: 'Белки',
                  value: '${totalNutrients.protein.round()}г',
                  total: '${proteinGoal.round()}г',
                  percentage: proteinPercent,
                  color: Colors.orange
                )),
                const SizedBox(width: 12),
                Expanded(child: _MacronutrientCard(
                  name: 'Жиры',
                  value: '${totalNutrients.fat.round()}г',
                  total: '${fatGoal.round()}г',
                  percentage: fatPercent,
                  color: Colors.blue
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacronutrientCard extends StatelessWidget {
  final String name;
  final String value;
  final String total;
  final double percentage;
  final Color color;

  const _MacronutrientCard({
    required this.name,
    required this.value,
    required this.total,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text('/ $total', style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: color.withAlpha(51), // 20% opacity
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodItemsList extends StatelessWidget {
  final List<FoodItem> foodItems;

  const _FoodItemsList({required this.foodItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Продукты', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        foodItems.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: foodItems.length,
              itemBuilder: (context, index) => _FoodListItem(item: foodItems[index]),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
      ],
    );
  }
   Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            Icon(Symbols.fastfood, size: 60, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text('Еще ничего не добавлено', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Нажмите "+", чтобы добавить продукт', style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}

class _FoodListItem extends StatelessWidget {
  final FoodItem item;
  const _FoodListItem({required this.item});

  void _navigateToDetail(BuildContext context, FoodItem item) {
    // Конвертируем FoodItem в Recipe, чтобы использовать существующий экран
    final recipe = Recipe(
      name: item.name,
      description: item.description,
      icon: item.icon,
      nutrients: item.nutrients,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: InkWell(
        borderRadius: AppStyles.cardRadius,
        onTap: () => _navigateToDetail(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26), // 10% opacity
                  borderRadius: AppStyles.mediumBorderRadius,
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(item.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text('${item.nutrients.calories} ккал', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionDetailsList extends StatelessWidget {
  final NutritionalInfo totalNutrients;

  const _NutritionDetailsList({required this.totalNutrients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Пищевая ценность', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildDetailRow(theme, 'Калории', '${totalNutrients.calories} ккал'),
                _buildDivider(),
                _buildDetailRow(theme, 'Белки', '${totalNutrients.protein.toStringAsFixed(1)} г'),
                _buildDetailRow(theme, 'Углеводы', '${totalNutrients.carbs.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   в т.ч. Сахар', '${totalNutrients.sugar.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   в т.ч. Клетчатка', '${totalNutrients.fiber.toStringAsFixed(1)} г', isSub: true),
                 _buildDivider(),
                _buildDetailRow(theme, 'Жиры', '${totalNutrients.fat.toStringAsFixed(1)} г'),
                _buildDetailRow(theme, '   Насыщенные', '${totalNutrients.saturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Полиненасыщенные', '${totalNutrients.polyunsaturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Мононенасыщенные', '${totalNutrients.monounsaturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Трансжиры', '${totalNutrients.transFat.toStringAsFixed(1)} г', isSub: true),
                _buildDivider(),
                 _buildDetailRow(theme, 'Холестерин', '${totalNutrients.cholesterol.toStringAsFixed(0)} мг'),
                 _buildDetailRow(theme, 'Натрий', '${totalNutrients.sodium.toStringAsFixed(0)} мг'),
                 _buildDetailRow(theme, 'Калий', '${totalNutrients.potassium.toStringAsFixed(0)} мг'),
                  _buildDivider(),
                 _buildDetailRow(theme, 'Витамин A', '${totalNutrients.vitaminA.toStringAsFixed(1)} мкг'),
                 _buildDetailRow(theme, 'Витамин C', '${totalNutrients.vitaminC.toStringAsFixed(1)} мг'),
                 _buildDetailRow(theme, 'Витамин D', '${totalNutrients.vitaminD.toStringAsFixed(1)} мкг'),
                 _buildDetailRow(theme, 'Кальций', '${totalNutrients.calcium.toStringAsFixed(1)} мг'),
                 _buildDetailRow(theme, 'Железо', '${totalNutrients.iron.toStringAsFixed(1)} мг'),
              ],
            ),
          )
        ),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value, {bool isSub = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: isSub 
              ? theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)
              : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.normal)
          ),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(height: 1, thickness: 1),
    );
  }
}
