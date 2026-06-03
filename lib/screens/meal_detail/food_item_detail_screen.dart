import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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

class _NutritionDetailsList extends StatefulWidget {
  final NutritionalInfo nutrients;

  const _NutritionDetailsList({required this.nutrients});

  @override
  State<_NutritionDetailsList> createState() => _NutritionDetailsListState();
}

class _NutritionDetailsListState extends State<_NutritionDetailsList> {
  bool _isExpanded = false;

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
      case 'fluoride':
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
                      '${widget.nutrients.calories.toStringAsFixed(1)} ${l10n.kcal}'),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.protein,
                      '${widget.nutrients.protein.toStringAsFixed(1)} ${l10n.grams}'),
                  _buildDetailRow(theme, l10n.carbs,
                      '${widget.nutrients.carbs.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: false),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.sugarSub,
                            '${widget.nutrients.sugar.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.fiberSub,
                            '${widget.nutrients.fiber.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDivider(),
                  _buildDetailRow(theme, l10n.fat,
                      '${widget.nutrients.fat.toStringAsFixed(1)} ${l10n.grams}'),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        _buildDetailRow(theme, l10n.saturatedFatSub,
                            '${widget.nutrients.saturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.polyunsaturatedFatSub,
                            '${widget.nutrients.polyunsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.monounsaturatedFatSub,
                            '${widget.nutrients.monounsaturatedFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.transFatSub,
                            '${widget.nutrients.transFat.toStringAsFixed(1)} ${l10n.grams}',
                            isSub: true),
                        _buildDetailRow(theme, l10n.cholesterolSub,
                            '${widget.nutrients.cholesterol.toStringAsFixed(1)} ${l10n.mg}',
                            isSub: true),
                      ],
                    ),
                  ),
                  _buildDetailRow(theme,
                      l10n.localeName == 'ru' ? 'Алкоголь' : (l10n.localeName == 'uk' ? 'Алкоголь' : 'Alcohol'),
                      '${widget.nutrients.alcohol.toStringAsFixed(1)} ${l10n.grams}',
                      isSub: false),
                  const SizedBox(height: 16),
                  Center(
                    child: InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.primary.withValues(alpha: _isExpanded ? 0.15 : 0.08),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isExpanded ? Symbols.keyboard_arrow_up : Symbols.keyboard_arrow_down,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isExpanded
                                  ? (l10n.localeName == 'ru' ? 'Свернуть детали' : (l10n.localeName == 'uk' ? 'Згорнути деталі' : 'Hide details'))
                                  : (l10n.localeName == 'ru' ? 'Показать витамины и минералы' : (l10n.localeName == 'uk' ? 'Показати вітаміни та мінерали' : 'Show vitamins and minerals')),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isExpanded
                          ? Column(
                              children: [
                                _buildDivider(),
                                _buildDetailRow(theme, l10n.minerals, '', isSub: false),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    children: [
                                      _buildDetailRow(theme, l10n.sodium,
                                          '${widget.nutrients.sodium.toStringAsFixed(1)} ${l10n.mg}',
                                          isSub: true),
                                      _buildDetailRow(theme, l10n.potassium,
                                          '${widget.nutrients.potassium.toStringAsFixed(1)} ${l10n.mg}',
                                          isSub: true),
                                      _buildDetailRow(theme, l10n.calcium,
                                          '${widget.nutrients.calcium.toStringAsFixed(1)} ${l10n.mg}',
                                          isSub: true),
                                      _buildDetailRow(theme, l10n.iron,
                                          '${widget.nutrients.iron.toStringAsFixed(1)} ${l10n.mg}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('magnesium', l10n),
                                          '${widget.nutrients.magnesium.toStringAsFixed(1)} ${_getUnitForKey('magnesium', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('phosphorus', l10n),
                                          '${widget.nutrients.phosphorus.toStringAsFixed(1)} ${_getUnitForKey('phosphorus', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('zinc', l10n),
                                          '${widget.nutrients.zinc.toStringAsFixed(1)} ${_getUnitForKey('zinc', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('copper', l10n),
                                          '${widget.nutrients.copper.toStringAsFixed(1)} ${_getUnitForKey('copper', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('manganese', l10n),
                                          '${widget.nutrients.manganese.toStringAsFixed(1)} ${_getUnitForKey('manganese', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('selenium', l10n),
                                          '${widget.nutrients.selenium.toStringAsFixed(1)} ${_getUnitForKey('selenium', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('iodine', l10n),
                                          '${widget.nutrients.iodine.toStringAsFixed(1)} ${_getUnitForKey('iodine', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('chromium', l10n),
                                          '${widget.nutrients.chromium.toStringAsFixed(1)} ${_getUnitForKey('chromium', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('molybdenum', l10n),
                                          '${widget.nutrients.molybdenum.toStringAsFixed(1)} ${_getUnitForKey('molybdenum', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('fluoride', l10n),
                                          '${widget.nutrients.fluoride.toStringAsFixed(1)} ${_getUnitForKey('fluoride', l10n)}',
                                          isSub: true),
                                    ],
                                  ),
                                ),
                                _buildDivider(),
                                _buildDetailRow(theme, l10n.vitamins, '', isSub: false),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    children: [
                                      _buildDetailRow(theme, l10n.vitaminA,
                                          '${widget.nutrients.vitaminA.toStringAsFixed(1)} ${l10n.mcg}',
                                          isSub: true),
                                      _buildDetailRow(theme, l10n.vitaminC,
                                          '${widget.nutrients.vitaminC.toStringAsFixed(1)} ${l10n.mg}',
                                          isSub: true),
                                      _buildDetailRow(theme, l10n.vitaminD,
                                          '${widget.nutrients.vitaminD.toStringAsFixed(1)} ${l10n.mcg}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_e', l10n),
                                          '${widget.nutrients.vitaminE.toStringAsFixed(1)} ${_getUnitForKey('vitamin_e', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_k', l10n),
                                          '${widget.nutrients.vitaminK.toStringAsFixed(1)} ${_getUnitForKey('vitamin_k', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_b1', l10n),
                                          '${widget.nutrients.vitaminB1.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b1', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_b2', l10n),
                                          '${widget.nutrients.vitaminB2.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b2', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_b3', l10n),
                                          '${widget.nutrients.vitaminB3.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b3', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_b5', l10n),
                                          '${widget.nutrients.vitaminB5.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b5', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('vitamin_b6', l10n),
                                          '${widget.nutrients.vitaminB6.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b6', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(
                                          theme,
                                          _nutrientLabel('vitamin_b7', l10n),
                                          '${widget.nutrients.vitaminB7.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b7', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(
                                          theme,
                                          _nutrientLabel('vitamin_b9', l10n),
                                          '${widget.nutrients.vitaminB9.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b9', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(
                                          theme,
                                          _nutrientLabel('vitamin_b12', l10n),
                                          '${widget.nutrients.vitaminB12.toStringAsFixed(1)} ${_getUnitForKey('vitamin_b12', l10n)}',
                                          isSub: true),
                                    ],
                                  ),
                                ),
                                _buildDivider(),
                                _buildDetailRow(theme, l10n.heavyMetalsAndContaminants, '',
                                    isSub: false),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    children: [
                                      _buildDetailRow(theme, _nutrientLabel('lead', l10n),
                                          '${widget.nutrients.lead.toStringAsFixed(1)} ${_getUnitForKey('lead', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('mercury', l10n),
                                          '${widget.nutrients.mercury.toStringAsFixed(1)} ${_getUnitForKey('mercury', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('cadmium', l10n),
                                          '${widget.nutrients.cadmium.toStringAsFixed(1)} ${_getUnitForKey('cadmium', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('arsenic', l10n),
                                          '${widget.nutrients.arsenic.toStringAsFixed(1)} ${_getUnitForKey('arsenic', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(theme, _nutrientLabel('nitrates', l10n),
                                          '${widget.nutrients.nitrates.toStringAsFixed(1)} ${_getUnitForKey('nitrates', l10n)}',
                                          isSub: true),
                                      _buildDetailRow(
                                          theme,
                                          _nutrientLabel('pesticides', l10n),
                                          '${widget.nutrients.pesticides.toStringAsFixed(1)} ${_getUnitForKey('pesticides', l10n)}',
                                          isSub: true),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
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
          if (value.isNotEmpty)
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
}
