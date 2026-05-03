import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final bool selectionMode;
  final bool isSelected;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.selectionMode = false,
    this.isSelected = false,
  });

  Future<void> _openEditScreen(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: recipe)),
    );
    if (result == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(recipe.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (selectionMode)
            IconButton(
              icon: const Icon(Symbols.add_circle),
              onPressed: () => Navigator.of(context).pop(true),
              tooltip: isSelected
                  ? l10n.addOneMoreToMeal
                  : l10n.addToMeal,
            )
          else if (recipe.isUserRecipe)
            IconButton(
              icon: const Icon(Symbols.edit, weight: 400),
              onPressed: () => _openEditScreen(context),
              tooltip: l10n.editRecipeTooltip,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: glassBodyPadding(
          context,
          left: 16,
          top: 8,
          right: 16,
          bottom: 8,
        ),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            if (recipe.ingredients.isNotEmpty) ...[
              _buildIngredientsCard(context),
              const SizedBox(height: 24),
            ],
            _buildNutrientsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(recipe.icon,
                    size: 56, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                recipe.name,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (recipe.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    recipe.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ingredients,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recipe.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Symbols.circle, size: 8, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ingredient.displayValue,
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nutritionValuePerPortion,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _nutrientRow(l10n.calories, recipe.nutrients['calories'], l10n.kcal),
            const Divider(height: 24),
            _nutrientGroup(l10n.mainNutrients, [
              _nutrientRow(l10n.protein, recipe.nutrients['protein'], l10n.grams),
              _nutrientRow(l10n.carbs, recipe.nutrients['carbs'], l10n.grams,
                  subRows: [
                    _nutrientSubRow(
                        l10n.sugarSub, recipe.nutrients['sugar'], l10n.grams),
                    _nutrientSubRow(
                        l10n.fiberSub, recipe.nutrients['fiber'], l10n.grams),
                  ]),
              _nutrientRow(l10n.fat, recipe.nutrients['fat'], l10n.grams, subRows: [
                _nutrientSubRow(
                    l10n.saturatedFatSub, recipe.nutrients['saturated_fat'], l10n.grams),
                _nutrientSubRow(l10n.polyunsaturatedFatSub,
                    recipe.nutrients['polyunsaturated_fat'], l10n.grams),
                _nutrientSubRow(l10n.monounsaturatedFatSub,
                    recipe.nutrients['monounsaturated_fat'], l10n.grams),
                _nutrientSubRow(
                    l10n.transFatSub, recipe.nutrients['trans_fat'], l10n.grams),
                _nutrientSubRow(
                    l10n.cholesterolSub, recipe.nutrients['cholesterol'], l10n.mg),
              ]),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.minerals, [
              _nutrientRow(l10n.sodium, recipe.nutrients['sodium'], l10n.mg),
              _nutrientRow(l10n.potassium, recipe.nutrients['potassium'], l10n.mg),
              _nutrientRow(l10n.calcium, recipe.nutrients['calcium'], l10n.mg),
              _nutrientRow(l10n.iron, recipe.nutrients['iron'], l10n.mg),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.vitamins, [
              _nutrientRow(l10n.vitaminA, recipe.nutrients['vitamin_a'], l10n.mcg),
              _nutrientRow(l10n.vitaminC, recipe.nutrients['vitamin_c'], l10n.mg),
              _nutrientRow(l10n.vitaminD, recipe.nutrients['vitamin_d'], l10n.mcg),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _nutrientGroup(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ...rows,
      ],
    );
  }

  Widget _nutrientRow(String label, double? value, String unit,
      {List<Widget> subRows = const []}) {
    final displayValue = (value ?? 0.0).toStringAsFixed(1);
    final visibleSubRows = subRows.whereType<Widget>().toList();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            Text('$displayValue $unit', style: const TextStyle(fontSize: 16)),
          ],
        ),
        if (visibleSubRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Column(children: visibleSubRows),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _nutrientSubRow(String label, double? value, String unit) {
    final displayValue = (value ?? 0.0).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          Text('$displayValue $unit',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
