import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/recipes_screen.dart';
import 'package:nutri_log/screens/recipes/recipe_detail_screen.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import '../../models/food_item.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';

class MealDetailScreen extends StatefulWidget {
  final String mealName;
  final List<FoodItem> items;
  final DateTime date;

  const MealDetailScreen({
    super.key,
    required this.mealName,
    required this.items,
    required this.date,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final DailyLogService _dailyLogService = DailyLogService();
  late List<FoodItem> _foodItems;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _foodItems = List<FoodItem>.from(widget.items);
  }

  Future<void> _addFromRecipes() async {
    final selectedRecipes = await Navigator.of(context).push<List<Recipe>>(
      MaterialPageRoute(
        builder: (_) => const RecipesScreen(selectionMode: true),
      ),
    );

    if (selectedRecipes == null || selectedRecipes.isEmpty) return;

    await _dailyLogService.addRecipesToMeal(
      widget.date,
      widget.mealName,
      selectedRecipes,
    );

    final updatedLog = await _dailyLogService.getLogForDate(widget.date);
    if (!mounted) return;

    setState(() {
      _foodItems = List<FoodItem>.from(updatedLog.meals[widget.mealName] ?? []);
      _hasChanges = true;
    });
  }

  Future<void> _removeFoodItemAt(int index) async {
    await _dailyLogService.removeFoodItemFromMeal(
      widget.date,
      widget.mealName,
      index,
    );

    if (!mounted) return;

    setState(() {
      _foodItems.removeAt(index);
      _hasChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Блюдо удалено из приема пищи',
            style: TextStyle(fontSize: 18)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(top: 0, left: 16, right: 16),
      ),
    );
  }

  Future<void> _openFoodItemAsRecipeDetail(FoodItem item) async {
    final recipe = _toSavedRecipeSnapshot(item);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  Recipe _toSavedRecipeSnapshot(FoodItem item) {
    return Recipe(
      id: 'meal_${item.name}_${item.description.hashCode}',
      name: item.name,
      description: item.description,
      nutrients: {
        'calories': item.nutrients.calories,
        'protein': item.nutrients.protein,
        'carbs': item.nutrients.carbs,
        'fat': item.nutrients.fat,
        'saturated_fat': item.nutrients.saturatedFat,
        'polyunsaturated_fat': item.nutrients.polyunsaturatedFat,
        'monounsaturated_fat': item.nutrients.monounsaturatedFat,
        'trans_fat': item.nutrients.transFat,
        'cholesterol': item.nutrients.cholesterol,
        'sodium': item.nutrients.sodium,
        'potassium': item.nutrients.potassium,
        'fiber': item.nutrients.fiber,
        'sugar': item.nutrients.sugar,
        'vitamin_a': item.nutrients.vitaminA,
        'vitamin_c': item.nutrients.vitaminC,
        'vitamin_d': item.nutrients.vitaminD,
        'calcium': item.nutrients.calcium,
        'iron': item.nutrients.iron,
      },
      icon: item.icon,
      ingredients:
          item.recipeIngredients.map(RecipeIngredient.fromJson).toList(),
      instructions: item.recipeInstructions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalNutrients = _foodItems.fold<NutritionalInfo>(
      NutritionalInfo.zero,
      (sum, item) => sum + item.nutrients,
    );

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasChanges);
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: buildGlassAppBar(
          title: Text(widget.mealName),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          actions: [
            IconButton(
              icon: const Icon(Symbols.add_circle_outline),
              onPressed: _addFromRecipes,
              tooltip: 'Добавить из рецептов',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: glassBodyPadding(context, top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealSummaryCard(totalNutrients: totalNutrients),
              const SizedBox(height: 24),
              _FoodItemsList(
                foodItems: _foodItems,
                onRemove: _removeFoodItemAt,
                onItemTap: _openFoodItemAsRecipeDetail,
              ),
              const SizedBox(height: 24),
              _NutritionDetailsList(totalNutrients: totalNutrients),
            ],
          ),
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

    final carbsPercent = carbsGoal > 0
        ? (totalNutrients.carbs / carbsGoal).clamp(0.0, 1.0)
        : 0.0;
    final proteinPercent = proteinGoal > 0
        ? (totalNutrients.protein / proteinGoal).clamp(0.0, 1.0)
        : 0.0;
    final fatPercent =
        fatGoal > 0 ? (totalNutrients.fat / fatGoal).clamp(0.0, 1.0) : 0.0;

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
                Expanded(
                    child: _MacronutrientCard(
                        name: 'Углеводы',
                        value: '${totalNutrients.carbs.round()}г',
                        total: '${carbsGoal.round()}г',
                        percentage: carbsPercent,
                        color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: _MacronutrientCard(
                        name: 'Белки',
                        value: '${totalNutrients.protein.round()}г',
                        total: '${proteinGoal.round()}г',
                        percentage: proteinPercent,
                        color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: _MacronutrientCard(
                        name: 'Жиры',
                        value: '${totalNutrients.fat.round()}г',
                        total: '${fatGoal.round()}г',
                        percentage: fatPercent,
                        color: Colors.blue)),
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
              Text(value,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('/ $total',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.textTheme.bodySmall?.color)),
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
  final ValueChanged<int> onRemove;
  final ValueChanged<FoodItem> onItemTap;

  const _FoodItemsList({
    required this.foodItems,
    required this.onRemove,
    required this.onItemTap,
  });

  Future<bool?> _confirmDelete(BuildContext context, String itemName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить блюдо?'),
        content: Text('"$itemName" будет удалено из этого приема пищи.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Рецепты в приеме пищи', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        foodItems.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: foodItems.length,
                itemBuilder: (context, index) {
                  final item = foodItems[index];
                  return Dismissible(
                    key: ValueKey('${item.name}_${item.description}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(220),
                        borderRadius: AppStyles.cardRadius,
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(
                        Symbols.delete,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, item.name),
                    onDismissed: (_) => onRemove(index),
                    child: _FoodListItem(
                      item: item,
                      onTap: () => onItemTap(item),
                      onDeleteTap: () async {
                        final confirmed =
                            await _confirmDelete(context, item.name);
                        if (confirmed == true) {
                          onRemove(index);
                        }
                      },
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
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
            Text('Нажмите "+", чтобы добавить продукт',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}

class _FoodListItem extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;
  final VoidCallback onDeleteTap;

  const _FoodListItem({
    required this.item,
    required this.onTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: InkWell(
        borderRadius: AppStyles.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child:
                    Icon(item.icon, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(item.description,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.textTheme.bodySmall?.color),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.nutrients.calories} ккал',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: onDeleteTap,
                    icon: const Icon(Symbols.delete_outline),
                    color: theme.colorScheme.primary,
                    tooltip: 'Удалить рецепт',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
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
            shape: RoundedRectangleBorder(
                borderRadius: AppStyles.largeBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDetailRow(
                      theme, 'Калории', '${totalNutrients.calories} ккал'),
                  _buildDivider(),
                  _buildDetailRow(theme, 'Белки',
                      '${totalNutrients.protein.toStringAsFixed(1)} г'),
                  _buildDetailRow(theme, 'Углеводы',
                      '${totalNutrients.carbs.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   в т.ч. Сахар',
                      '${totalNutrients.sugar.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   в т.ч. Клетчатка',
                      '${totalNutrients.fiber.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDivider(),
                  _buildDetailRow(theme, 'Жиры',
                      '${totalNutrients.fat.toStringAsFixed(1)} г'),
                  _buildDetailRow(theme, '   Насыщенные',
                      '${totalNutrients.saturatedFat.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   Полиненасыщенные',
                      '${totalNutrients.polyunsaturatedFat.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   Мононенасыщенные',
                      '${totalNutrients.monounsaturatedFat.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   Трансжиры',
                      '${totalNutrients.transFat.toStringAsFixed(1)} г',
                      isSub: true),
                  _buildDetailRow(theme, '   Холестерин',
                      '${totalNutrients.cholesterol.toStringAsFixed(0)} мг',
                      isSub: true),
                  _buildDivider(),
                  _buildCategoryTitle(theme, 'Минералы'),
                  _buildDetailRow(theme, 'Натрий',
                      '${totalNutrients.sodium.toStringAsFixed(0)} мг'),
                  _buildDetailRow(theme, 'Калий',
                      '${totalNutrients.potassium.toStringAsFixed(0)} мг'),
                  _buildDetailRow(theme, 'Кальций',
                      '${totalNutrients.calcium.toStringAsFixed(1)} мг'),
                  _buildDetailRow(theme, 'Железо',
                      '${totalNutrients.iron.toStringAsFixed(1)} мг'),
                  _buildDivider(),
                  _buildCategoryTitle(theme, 'Витамины'),
                  _buildDetailRow(theme, 'Витамин A',
                      '${totalNutrients.vitaminA.toStringAsFixed(1)} мкг'),
                  _buildDetailRow(theme, 'Витамин C',
                      '${totalNutrients.vitaminC.toStringAsFixed(1)} мг'),
                  _buildDetailRow(theme, 'Витамин D',
                      '${totalNutrients.vitaminD.toStringAsFixed(1)} мкг'),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value,
      {bool isSub = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isSub
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.textTheme.bodySmall?.color)
                  : theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.normal)),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildCategoryTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
