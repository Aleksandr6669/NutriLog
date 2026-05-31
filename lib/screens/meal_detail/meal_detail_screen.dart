import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/recipes_screen.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import '../../models/food_item.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/daily_log_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class MealDetailScreen extends StatefulWidget {
  final String mealKey;
  final List<FoodItem> items;
  final DateTime date;

  const MealDetailScreen({
    super.key,
    required this.mealKey,
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
    if (_foodItems.isEmpty) {
      _loadMealItemsFromLog();
    }
  }

  Future<void> _loadMealItemsFromLog() async {
    final log = await _dailyLogService.getLogForDate(widget.date);
    if (!mounted) return;
    setState(() {
      _foodItems = List<FoodItem>.from(log.meals[widget.mealKey] ?? const []);
    });
  }

  Future<void> _addFromRecipes() async {
    HapticFeedback.selectionClick();
    final selectedRecipes = await Navigator.of(context).push<List<Recipe>>(
      MaterialPageRoute(
        builder: (_) => const RecipesScreen(
          selectionMode: true,
        ),
      ),
    );

    if (selectedRecipes == null || selectedRecipes.isEmpty) return;
    if (!mounted) return;
    final provider = context.read<DailyLogProvider>();
    await _dailyLogService.addRecipesToMeal(
      widget.date,
      widget.mealKey,
      selectedRecipes,
    );

    await provider.refreshCurrentLog();

    if (!mounted) return;

    setState(() {
      _foodItems =
          List<FoodItem>.from(provider.currentLog?.meals[widget.mealKey] ?? []);
      _hasChanges = true;
    });
  }

  Future<void> _removeFoodItemAt(int index) async {
    HapticFeedback.mediumImpact();
    final provider = context.read<DailyLogProvider>();

    await _dailyLogService.removeFoodItemFromMeal(
      widget.date,
      widget.mealKey,
      index,
    );

    await provider.refreshCurrentLog();

    if (!mounted) return;

    setState(() {
      _foodItems =
          List<FoodItem>.from(provider.currentLog?.meals[widget.mealKey] ?? []);
      _hasChanges = true;
    });
  }

  Future<void> _openFoodItemAsRecipeDetail(FoodItem item) async {
    final recipe = _toSavedRecipeSnapshot(item);
    if (!mounted) return;

    await context.push(
      '/recipe_detail',
      extra: {'recipe': recipe},
    );
  }

  Recipe _toSavedRecipeSnapshot(FoodItem item) {
    return Recipe(
      id: item.id ?? 'meal_${item.name}_${item.description.hashCode}',
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
        'vitamin_e': item.nutrients.vitaminE,
        'vitamin_k': item.nutrients.vitaminK,
        'vitamin_b1': item.nutrients.vitaminB1,
        'vitamin_b2': item.nutrients.vitaminB2,
        'vitamin_b3': item.nutrients.vitaminB3,
        'vitamin_b5': item.nutrients.vitaminB5,
        'vitamin_b6': item.nutrients.vitaminB6,
        'vitamin_b7': item.nutrients.vitaminB7,
        'vitamin_b9': item.nutrients.vitaminB9,
        'vitamin_b12': item.nutrients.vitaminB12,
        'magnesium': item.nutrients.magnesium,
        'phosphorus': item.nutrients.phosphorus,
        'zinc': item.nutrients.zinc,
        'copper': item.nutrients.copper,
        'manganese': item.nutrients.manganese,
        'selenium': item.nutrients.selenium,
        'iodine': item.nutrients.iodine,
        'chromium': item.nutrients.chromium,
        'molybdenum': item.nutrients.molybdenum,
        'fluoride': item.nutrients.fluoride,
        'lead': item.nutrients.lead,
        'mercury': item.nutrients.mercury,
        'cadmium': item.nutrients.cadmium,
        'arsenic': item.nutrients.arsenic,
        'nitrates': item.nutrients.nitrates,
        'pesticides': item.nutrients.pesticides,
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
    final l10n = AppLocalizations.of(context)!;
    final mealName = switch (widget.mealKey) {
      'breakfast' => l10n.breakfast,
      'lunch' => l10n.lunch,
      'dinner' => l10n.dinner,
      'snacks' => l10n.snacks,
      _ => l10n.meals,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: buildGlassAppBar(
          title: Text(mealName),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(_hasChanges),
          ),
          actions: [
            IconButton(
              icon: const Icon(Symbols.add_circle_outline),
              onPressed: _addFromRecipes,
              tooltip: l10n.addFromRecipes,
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
              const SizedBox(height: 12),
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
    final l10n = AppLocalizations.of(context)!;
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
            Text(l10n.mealSummary, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _MacronutrientCard(
                        name: l10n.carbs,
                        value: '${totalNutrients.carbs.round()}${l10n.grams}',
                        total: '${carbsGoal.round()}${l10n.grams}',
                        percentage: carbsPercent,
                        color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: _MacronutrientCard(
                        name: l10n.protein,
                        value: '${totalNutrients.protein.round()}${l10n.grams}',
                        total: '${proteinGoal.round()}${l10n.grams}',
                        percentage: proteinPercent,
                        color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(
                    child: _MacronutrientCard(
                        name: l10n.fat,
                        value: '${totalNutrients.fat.round()}${l10n.grams}',
                        total: '${fatGoal.round()}${l10n.grams}',
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

  // confirmDelete больше не нужен

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.recipesInMeal, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          l10n.swipeToDeleteHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 8),
        foodItems.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: foodItems.length,
                itemBuilder: (context, index) {
                  // Отображаем в обратном порядке (новое вверху)
                  final originalIndex = foodItems.length - 1 - index;
                  final item = foodItems[originalIndex];
                  return Dismissible(
                    key: ValueKey(
                        '${item.name}_${item.description}_$originalIndex'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(220),
                        borderRadius: AppStyles.cardRadius,
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.delete,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Symbols.delete,
                            color: Colors.white,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) async => true,
                    onDismissed: (_) => onRemove(originalIndex),
                    child: _FoodListItem(
                      item: item,
                      onTap: () => onItemTap(item),
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            Icon(Symbols.fastfood, size: 60, color: theme.dividerColor),
            const SizedBox(height: 16),
            Text(l10n.nothingAddedYet, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.pressPlusToAddFood,
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

  const _FoodListItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child:
                    Icon(item.icon, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.textTheme.bodySmall?.color),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.nutrients.calories} ${l10n.kcal}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Icon(
                    Symbols.info,
                    color: theme.colorScheme.primary,
                    size: 20,
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

  String _nutrientLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'magnesium':
        return l10n.magnesium;
      case 'phosphorus':
        return l10n.phosphorus;
      case 'zinc':
        return l10n.zinc;
      case 'copper':
        return l10n.copper;
      case 'manganese':
        return l10n.manganese;
      case 'selenium':
        return l10n.selenium;
      case 'iodine':
        return l10n.iodine;
      case 'chromium':
        return l10n.chromium;
      case 'molybdenum':
        return l10n.molybdenum;
      case 'fluoride':
        return l10n.fluoride;
      case 'vitamin_e':
        return l10n.vitaminE;
      case 'vitamin_k':
        return l10n.vitaminK;
      case 'vitamin_b1':
        return l10n.vitaminB1;
      case 'vitamin_b2':
        return l10n.vitaminB2;
      case 'vitamin_b3':
        return l10n.vitaminB3;
      case 'vitamin_b5':
        return l10n.vitaminB5;
      case 'vitamin_b6':
        return l10n.vitaminB6;
      case 'vitamin_b7':
        return l10n.vitaminB7;
      case 'vitamin_b9':
        return l10n.vitaminB9;
      case 'vitamin_b12':
        return l10n.vitaminB12;
      case 'lead':
        return l10n.lead;
      case 'mercury':
        return l10n.mercury;
      case 'cadmium':
        return l10n.cadmium;
      case 'arsenic':
        return l10n.arsenic;
      case 'nitrates':
        return l10n.nitrates;
      case 'pesticides':
        return l10n.pesticides;
      default:
        return key;
    }
  }

  String _getUnitForKey(String key, AppLocalizations l10n) {
    switch (key) {
      case 'magnesium':
      case 'phosphorus':
      case 'zinc':
      case 'copper':
      case 'manganese':
      case 'fluoride':
      case 'vitamin_e':
      case 'vitamin_b1':
      case 'vitamin_b2':
      case 'vitamin_b3':
      case 'vitamin_b5':
      case 'vitamin_b6':
      case 'lead':
      case 'nitrates':
        return l10n.mg;
      default:
        return l10n.mcg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.nutritionValue, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
            shape: RoundedRectangleBorder(
                borderRadius: AppStyles.largeBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDetailRow(theme, l10n.calories,
                      '${totalNutrients.calories.toStringAsFixed(1)} ${l10n.kcal}'),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.protein,
                      '${totalNutrients.protein.toStringAsFixed(1)} ${l10n.grams}'),
                  _buildDetailRow(theme, l10n.carbs,
                      '${totalNutrients.carbs.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: false),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.sugarSub,
                            '${totalNutrients.sugar.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.fiberSub,
                            '${totalNutrients.fiber.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.fat,
                      '${totalNutrients.fat.toStringAsFixed(1)} ${l10n.grams}'),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.saturatedFatSub,
                            '${totalNutrients.saturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.polyunsaturatedFatSub,
                            '${totalNutrients.polyunsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.monounsaturatedFatSub,
                            '${totalNutrients.monounsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.transFatSub,
                            '${totalNutrients.transFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.cholesterolSub,
                            '${totalNutrients.cholesterol.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDetailRow(theme,
                      l10n.localeName == 'ru' ? 'Алкоголь' : (l10n.localeName == 'uk' ? 'Алкоголь' : 'Alcohol'),
                      '${totalNutrients.alcohol.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: false),
                  _buildDivider(),
                  _buildCategoryTitle(theme, l10n.minerals),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.sodium,
                            '${totalNutrients.sodium.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.potassium,
                            '${totalNutrients.potassium.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.calcium,
                            '${totalNutrients.calcium.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.iron,
                            '${totalNutrients.iron.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('magnesium', l10n),
                            '${totalNutrients.magnesium.toStringAsFixed(1)} ${_getUnitForKey('magnesium', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('phosphorus', l10n),
                            '${totalNutrients.phosphorus.toStringAsFixed(1)} ${_getUnitForKey('phosphorus', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('zinc', l10n),
                            '${totalNutrients.zinc.toStringAsFixed(1)} ${_getUnitForKey('zinc', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('copper', l10n),
                            '${totalNutrients.copper.toStringAsFixed(1)} ${_getUnitForKey('copper', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('manganese', l10n),
                            '${totalNutrients.manganese.toStringAsFixed(1)} ${_getUnitForKey('manganese', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('selenium', l10n),
                            '${totalNutrients.selenium.toStringAsFixed(1)} ${_getUnitForKey('selenium', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('iodine', l10n),
                            '${totalNutrients.iodine.toStringAsFixed(1)} ${_getUnitForKey('iodine', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('chromium', l10n),
                            '${totalNutrients.chromium.toStringAsFixed(1)} ${_getUnitForKey('chromium', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('molybdenum', l10n),
                            '${totalNutrients.molybdenum.toStringAsFixed(1)} ${_getUnitForKey('molybdenum', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('fluoride', l10n),
                            '${totalNutrients.fluoride.toStringAsFixed(1)} ${_getUnitForKey('fluoride', l10n)}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDivider(),
                  _buildCategoryTitle(theme, l10n.vitamins),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.vitaminA,
                            '${totalNutrients.vitaminA.toStringAsFixed(1)} ${l10n.mcg}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.vitaminC,
                            '${totalNutrients.vitaminC.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.vitaminD,
                            '${totalNutrients.vitaminD.toStringAsFixed(1)} ${l10n.mcg}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_e', l10n),
                            '${totalNutrients.vitaminE.toStringAsFixed(1)} ${_getUnitForKey('vitamin_e', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_k', l10n),
                            '${totalNutrients.vitaminK.toStringAsFixed(1)} ${_getUnitForKey('vitamin_k', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b1', l10n),
                            '${totalNutrients.vitaminB1.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b1', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b2', l10n),
                            '${totalNutrients.vitaminB2.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b2', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b3', l10n),
                            '${totalNutrients.vitaminB3.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b3', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b5', l10n),
                            '${totalNutrients.vitaminB5.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b5', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b6', l10n),
                            '${totalNutrients.vitaminB6.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b6', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b7', l10n),
                            '${totalNutrients.vitaminB7.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b7', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b9', l10n),
                            '${totalNutrients.vitaminB9.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b9', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('vitamin_b12', l10n),
                            '${totalNutrients.vitaminB12.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b12', l10n)}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDivider(),
                  _buildCategoryTitle(theme, l10n.heavyMetalsAndContaminants),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, _nutrientLabel('lead', l10n),
                            '${totalNutrients.lead.toStringAsFixed(1)} ${_getUnitForKey('lead', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('mercury', l10n),
                            '${totalNutrients.mercury.toStringAsFixed(1)} ${_getUnitForKey('mercury', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('cadmium', l10n),
                            '${totalNutrients.cadmium.toStringAsFixed(1)} ${_getUnitForKey('cadmium', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('arsenic', l10n),
                            '${totalNutrients.arsenic.toStringAsFixed(1)} ${_getUnitForKey('arsenic', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('nitrates', l10n),
                            '${totalNutrients.nitrates.toStringAsFixed(1)} ${_getUnitForKey('nitrates', l10n)}',
                            isSub: true),
                        _buildDetailRow(theme, _nutrientLabel('pesticides', l10n),
                            '${totalNutrients.pesticides.toStringAsFixed(1)} ${_getUnitForKey('pesticides', l10n)}',
                            isSub: true),
                      ],
                    ),
                  ),
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
                      ?.copyWith(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
