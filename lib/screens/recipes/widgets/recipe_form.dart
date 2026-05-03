import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_styles.dart';

class RecipeForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbsController;

  const RecipeForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.descriptionController,
    required this.caloriesController,
    required this.proteinController,
    required this.fatController,
    required this.carbsController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(context, nameController, l10n.recipeNameLabel),
            const SizedBox(height: 16),
            _buildTextField(
                context, descriptionController, l10n.recipeDescriptionLabel,
                maxLines: 3),
            const SizedBox(height: 24),
            Text(l10n.recipeNutritionPer100g,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.defaultBorderRadius),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildNutrientField(
                        context, caloriesController, l10n.calories, l10n.kcal),
                    const Divider(height: 24),
                    _buildNutrientField(
                        context, proteinController, l10n.protein, l10n.grams),
                    const Divider(height: 24),
                    _buildNutrientField(
                        context, fatController, l10n.fat, l10n.grams),
                    const Divider(height: 24),
                    _buildNutrientField(
                        context, carbsController, l10n.carbs, l10n.grams),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context, TextEditingController controller, String label,
      {int maxLines = 1}) {
    final border = OutlineInputBorder(
      borderRadius: AppStyles.defaultBorderRadius,
      borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withAlpha(128)), // 50% opacity
    );
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.fieldCannotBeEmpty;
        }
        return null;
      },
    );
  }

  Widget _buildNutrientField(BuildContext context,
      TextEditingController controller, String label, String suffix) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: InputBorder.none,
        filled: false,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context)!.fieldCannotBeEmpty;
        }
        if (double.tryParse(value.replaceAll(',', '.')) == null) {
          return AppLocalizations.of(context)!.invalidFormat;
        }
        return null;
      },
    );
  }
}
