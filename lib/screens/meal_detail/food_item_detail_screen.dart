import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class FoodItemDetailScreen extends StatelessWidget {
  final FoodItem item;

  const FoodItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(title: Text(item.name)),
      body: SingleChildScrollView(
        padding: glassBodyPadding(context, top: 16, bottom: 16),
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
                      '${nutrients.calories} ${l10n.kcal}'),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.protein,
                      '${nutrients.protein.toStringAsFixed(1)} ${l10n.grams}'),
                  _buildDetailRow(theme, l10n.carbs,
                      '${nutrients.carbs.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.sugarSub}',
                      '${nutrients.sugar.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.fiberSub}',
                      '${nutrients.fiber.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.fat,
                      '${nutrients.fat.toStringAsFixed(1)} ${l10n.grams}'),
                  _buildDetailRow(theme, '   ${l10n.saturatedFatSub}',
                      '${nutrients.saturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.polyunsaturatedFatSub}',
                      '${nutrients.polyunsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.monounsaturatedFatSub}',
                      '${nutrients.monounsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.transFatSub}',
                      '${nutrients.transFat.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: true),
                  _buildDetailRow(theme, '   ${l10n.cholesterolSub}',
                      '${nutrients.cholesterol.toStringAsFixed(0)} ${l10n.mg}',
                      isSub: true),
                  _buildDivider(),
                  _buildCategoryTitle(theme, l10n.minerals),
                  _buildDetailRow(theme, l10n.sodium,
                      '${nutrients.sodium.toStringAsFixed(0)} ${l10n.mg}'),
                  _buildDetailRow(theme, l10n.potassium,
                      '${nutrients.potassium.toStringAsFixed(0)} ${l10n.mg}'),
                  _buildDetailRow(theme, l10n.calcium,
                      '${nutrients.calcium.toStringAsFixed(1)} ${l10n.mg}'),
                  _buildDetailRow(theme, l10n.iron,
                      '${nutrients.iron.toStringAsFixed(1)} ${l10n.mg}'),
                  _buildDivider(),
                  _buildCategoryTitle(theme, l10n.vitamins),
                  _buildDetailRow(theme, l10n.vitaminA,
                      '${nutrients.vitaminA.toStringAsFixed(1)} ${l10n.mcg}'),
                  _buildDetailRow(theme, l10n.vitaminC,
                      '${nutrients.vitaminC.toStringAsFixed(1)} ${l10n.mg}'),
                  _buildDetailRow(theme, l10n.vitaminD,
                      '${nutrients.vitaminD.toStringAsFixed(1)} ${l10n.mcg}'),
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
