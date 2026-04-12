import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../styles/app_styles.dart';

class FoodItemDetailScreen extends StatelessWidget {
  final FoodItem item;

  const FoodItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            _NutritionDetailsList(nutrients: item.nutrients),
          ],
        ),
      ),
    );
  }
}

class _NutritionDetailsList extends StatelessWidget {
  final NutritionalInfo nutrients;

  const _NutritionDetailsList({required this.nutrients});

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
                _buildDetailRow(theme, 'Калории', '${nutrients.calories} ккал'),
                _buildDivider(),
                _buildDetailRow(theme, 'Белки', '${nutrients.protein.toStringAsFixed(1)} г'),
                _buildDetailRow(theme, 'Углеводы', '${nutrients.carbs.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   в т.ч. Сахар', '${nutrients.sugar.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   в т.ч. Клетчатка', '${nutrients.fiber.toStringAsFixed(1)} г', isSub: true),
                 _buildDivider(),
                _buildDetailRow(theme, 'Жиры', '${nutrients.fat.toStringAsFixed(1)} г'),
                _buildDetailRow(theme, '   Насыщенные', '${nutrients.saturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Полиненасыщенные', '${nutrients.polyunsaturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Мононенасыщенные', '${nutrients.monounsaturatedFat.toStringAsFixed(1)} г', isSub: true),
                _buildDetailRow(theme, '   Трансжиры', '${nutrients.transFat.toStringAsFixed(1)} г', isSub: true),
                _buildDivider(),
                 _buildDetailRow(theme, 'Холестерин', '${nutrients.cholesterol.toStringAsFixed(0)} мг'),
                 _buildDetailRow(theme, 'Натрий', '${nutrients.sodium.toStringAsFixed(0)} мг'),
                 _buildDetailRow(theme, 'Калий', '${nutrients.potassium.toStringAsFixed(0)} мг'),
                  _buildDivider(),
                 _buildDetailRow(theme, 'Витамин A', '${nutrients.vitaminA.toStringAsFixed(1)} мкг'),
                 _buildDetailRow(theme, 'Витамин C', '${nutrients.vitaminC.toStringAsFixed(1)} мг'),
                 _buildDetailRow(theme, 'Витамин D', '${nutrients.vitaminD.toStringAsFixed(1)} мкг'),
                 _buildDetailRow(theme, 'Кальций', '${nutrients.calcium.toStringAsFixed(1)} мг'),
                 _buildDetailRow(theme, 'Железо', '${nutrients.iron.toStringAsFixed(1)} мг'),
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
