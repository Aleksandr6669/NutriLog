import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;
import '../../models/food_item.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';

class MealDetailScreen extends StatelessWidget {
  final String mealName;

  const MealDetailScreen({super.key, required this.mealName});

  // Mock data for demonstration with detailed nutritional info
  static final Map<String, List<FoodItem>> _mockData = {
    'Завтрак': [
      FoodItem(
        icon: Symbols.local_cafe,
        name: 'Кофе', 
        description: 'Черный, без сахара', 
        nutrients: NutritionalInfo(calories: 5, protein: 0.3, carbs: 0.8, fat: 0.1)
      ),
      FoodItem(
        icon: Symbols.breakfast_dining, 
        name: 'Овсянка', 
        description: 'На воде с ягодами', 
        nutrients: NutritionalInfo(calories: 150, protein: 5, carbs: 27, fat: 2.5, fiber: 4, sugar: 1, potassium: 150)
      ),
      FoodItem(
        icon: Symbols.egg, 
        name: 'Яичница', 
        description: 'Из двух яиц', 
        nutrients: NutritionalInfo(calories: 165, protein: 13, carbs: 1, fat: 11, saturatedFat: 3.5, cholesterol: 370, vitaminD: 10)
      ),
    ],
    'Обед': [
       FoodItem(
        icon: Symbols.restaurant,
        name: 'Грибной суп',
        description: '250 мл',
        nutrients: NutritionalInfo(calories: 210, protein: 8, carbs: 15, fat: 13, saturatedFat: 5, sodium: 600, fiber: 3),
      ),
      FoodItem(
        icon: Symbols.lunch_dining,
        name: 'Куриная грудка',
        description: 'Запеченная, 150г',
        nutrients: NutritionalInfo(calories: 240, protein: 45, carbs: 0, fat: 5, saturatedFat: 1.5, cholesterol: 130, potassium: 400, iron: 6),
      ),
      FoodItem(
        icon: Symbols.eco,
        name: 'Салат овощной',
        description: 'С оливковым маслом',
        nutrients: NutritionalInfo(calories: 70, protein: 1, carbs: 8, fat: 4, monounsaturatedFat: 3, fiber: 2, vitaminA: 25, vitaminC: 30),
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final foodItems = _mockData[mealName] ?? [];
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
                Expanded(child: _MacroCircle(label: 'Углеводы', amount: totalNutrients.carbs, goal: carbsGoal, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _MacroCircle(label: 'Белки', amount: totalNutrients.protein, goal: proteinGoal, color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: _MacroCircle(label: 'Жиры', amount: totalNutrients.fat, goal: fatGoal, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCircle extends StatelessWidget {
  final String label;
  final double amount;
  final double goal;
  final Color color;

  const _MacroCircle({required this.label, required this.amount, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal > 0 ? (amount / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: 260, height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
              Text('${amount.round()}г', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          )
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodyMedium)
      ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
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
                 _buildDetailRow(theme, 'Витамин A', '${totalNutrients.vitaminA}%'),
                 _buildDetailRow(theme, 'Витамин C', '${totalNutrients.vitaminC}%'),
                 _buildDetailRow(theme, 'Витамин D', '${totalNutrients.vitaminD}%'),
                 _buildDetailRow(theme, 'Кальций', '${totalNutrients.calcium}%'),
                 _buildDetailRow(theme, 'Железо', '${totalNutrients.iron}%'),
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
