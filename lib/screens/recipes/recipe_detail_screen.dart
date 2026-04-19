import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/styles/app_styles.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(recipe.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (recipe.isUserRecipe)
            IconButton(
              icon: const Icon(Symbols.edit, weight: 400),
              onPressed: () => _openEditScreen(context),
              tooltip: 'Редактировать рецепт',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            if (recipe.ingredients.isNotEmpty) ...[
              _buildIngredientsCard(),
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

  Widget _buildIngredientsCard() {
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
            const Text(
              'Состав',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recipe.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Symbols.circle, size: 8, color: Colors.grey),
                    ),
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
            const Text(
              'Пищевая ценность (на порцию)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _nutrientRow('Калории', recipe.nutrients['calories'], 'ккал'),
            const Divider(height: 24),
            _nutrientGroup('Основные', [
              _nutrientRow('Белки', recipe.nutrients['protein'], 'г'),
              _nutrientRow('Углеводы', recipe.nutrients['carbs'], 'г',
                  subRows: [
                    _nutrientSubRow(
                        'в т.ч. Сахар', recipe.nutrients['sugar'], 'г'),
                    _nutrientSubRow(
                        'в т.ч. Клетчатка', recipe.nutrients['fiber'], 'г'),
                  ]),
              _nutrientRow('Жиры', recipe.nutrients['fat'], 'г', subRows: [
                _nutrientSubRow(
                    'Насыщенные', recipe.nutrients['saturated_fat'], 'г'),
                _nutrientSubRow('Полиненасыщенные',
                    recipe.nutrients['polyunsaturated_fat'], 'г'),
                _nutrientSubRow('Мононенасыщенные',
                    recipe.nutrients['monounsaturated_fat'], 'г'),
                _nutrientSubRow(
                    'Трансжиры', recipe.nutrients['trans_fat'], 'г'),
              ]),
            ]),
            const Divider(height: 24),
            _nutrientGroup('Минералы', [
              _nutrientRow('Холестерин', recipe.nutrients['cholesterol'], 'мг'),
              _nutrientRow('Натрий', recipe.nutrients['sodium'], 'мг'),
              _nutrientRow('Калий', recipe.nutrients['potassium'], 'мг'),
            ]),
            const Divider(height: 24),
            _nutrientGroup('Витамины', [
              _nutrientRow('Витамин A', recipe.nutrients['vitamin_a'], 'мкг'),
              _nutrientRow('Витамин C', recipe.nutrients['vitamin_c'], 'мг'),
              _nutrientRow('Витамин D', recipe.nutrients['vitamin_d'], 'мкг'),
              _nutrientRow('Кальций', recipe.nutrients['calcium'], 'мг'),
              _nutrientRow('Железо', recipe.nutrients['iron'], 'мг'),
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
        if (subRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Column(children: subRows),
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
