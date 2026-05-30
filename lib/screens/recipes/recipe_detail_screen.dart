import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_log/models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../services/gemini_recipe_service.dart';
import '../../services/cloud_data_service.dart';
import '../../services/recipe_advice_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final bool selectionMode;
  final bool isSelected;
  final bool hideEdit;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.selectionMode = false,
    this.isSelected = false,
    this.hideEdit = false,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _geminiRecipeService = GeminiRecipeService();
  String _personalAdvice = '';
  bool _isLoadingAdvice = false;

  String _localizeInline({
    required String ru,
    required String en,
    required String uk,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'en') return en;
    if (code == 'uk') return uk;
    return ru;
  }

  String _nutrientLabel(String key, AppLocalizations l10n) {
    switch (key) {
      case 'calories':
        return l10n.calories;
      case 'protein':
        return l10n.protein;
      case 'carbs':
        return l10n.carbs;
      case 'fat':
        return l10n.fat;
      case 'fiber':
        return l10n.fiberSub;
      case 'sugar':
        return l10n.sugarSub;
      case 'saturated_fat':
        return l10n.saturatedFatSub;
      case 'polyunsaturated_fat':
        return l10n.polyunsaturatedFatSub;
      case 'monounsaturated_fat':
        return l10n.monounsaturatedFatSub;
      case 'trans_fat':
        return l10n.transFatSub;
      case 'cholesterol':
        return l10n.cholesterolSub;
      case 'sodium':
        return l10n.sodium;
      case 'potassium':
        return l10n.potassium;
      case 'calcium':
        return l10n.calcium;
      case 'iron':
        return l10n.iron;
      case 'vitamin_a':
        return l10n.vitaminA;
      case 'vitamin_c':
        return l10n.vitaminC;
      case 'vitamin_d':
        return l10n.vitaminD;
      
      // Extra Vitamins
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

      // Extra Minerals
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

      // Heavy Metals & Contaminants
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
      case 'calories':
        return l10n.kcal;
      case 'protein':
      case 'carbs':
      case 'fat':
      case 'fiber':
      case 'sugar':
      case 'saturated_fat':
      case 'polyunsaturated_fat':
      case 'monounsaturated_fat':
      case 'trans_fat':
        return l10n.grams;
      case 'cholesterol':
      case 'sodium':
      case 'potassium':
      case 'calcium':
      case 'iron':
      case 'vitamin_c':
      case 'vitamin_b1':
      case 'vitamin_b2':
      case 'vitamin_b3':
      case 'vitamin_b5':
      case 'vitamin_b6':
      case 'magnesium':
      case 'phosphorus':
      case 'zinc':
      case 'copper':
      case 'manganese':
      case 'fluoride':
        return l10n.mg;
      default:
        return l10n.mcg;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPersonalAdvice();
  }

  String _calculateContextHash(String context, Recipe recipe) {
    final ingredientsStr = recipe.ingredients
        .map((ing) => '${ing.name}|${ing.quantity}|${ing.unit}')
        .join(',');
    final nutrientsStr = recipe.nutrients.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    final recipeData =
        '${recipe.name}|$ingredientsStr|$nutrientsStr|${recipe.description}|${recipe.clarification}';
    return base64Encode(utf8.encode('$context|$recipeData'));
  }

  bool _isFetchingAdvice = false;

  Future<void> _loadPersonalAdvice() async {
    if (_isFetchingAdvice) return;
    _isFetchingAdvice = true;

    final profile = context.read<ProfileProvider>().profile;
    if (profile == null) {
      _isFetchingAdvice = false;
      return;
    }

    if (!profile.isPersonalAdviceAvailable) {
      _isFetchingAdvice = false;
      return;
    }

    final richSummary = profile.richContextSummary(context);
    final currentHash =
        _calculateContextHash(richSummary, widget.recipe);

    final adviceService = RecipeAdviceService();
    final cachedData = await adviceService.getAdvice(widget.recipe.id);

    if (cachedData != null) {
      if (cachedData['hash'] == currentHash) {
        if (mounted) {
          setState(() {
            _personalAdvice = cachedData['advice'] as String;
            _isLoadingAdvice = false;
          });
        }
        _isFetchingAdvice = false;
        return;
      }
    }

    // Always fetch fresh expert advice (personalized if fields filled, light advice if empty)
    if (mounted) {
      await _generateNewAdvice(richSummary, currentHash);
    }
    _isFetchingAdvice = false;
  }

  Future<void> _generateNewAdvice(String healthConditions, String hash) async {
    if (!mounted) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    setState(() => _isLoadingAdvice = true);
    try {
      final advice = await _geminiRecipeService.generateMedicalAdvice(
        recipeName: widget.recipe.name,
        recipeDescription: widget.recipe.description,
        ingredients: widget.recipe.ingredients,
        nutrients: widget.recipe.nutrients,
        healthConditions: healthConditions,
        clarification: widget.recipe.clarification,
        locale: languageCode,
      );

      if (mounted) {
        setState(() {
          _personalAdvice = advice;
          _isLoadingAdvice = false;
        });

        final profile = context.read<ProfileProvider>().profile;
        if (profile != null) {
          await RecipeAdviceService().saveAdvice(widget.recipe.id, advice, hash);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAdvice = false);
      }
    }
  }

  Future<void> _openEditScreen(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => EditRecipeScreen(recipe: widget.recipe)),
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
        title: Text(widget.recipe.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.selectionMode)
            IconButton(
              icon: const Icon(Symbols.add_circle),
              onPressed: () => Navigator.of(context).pop(true),
              tooltip: l10n.addToMeal,
            )
          else if (widget.recipe.isUserRecipe && !widget.recipe.isDonated && !widget.hideEdit)
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
            _buildPersonalAdviceCard(context),
            const SizedBox(height: 24),
            if (widget.recipe.ingredients.isNotEmpty) ...[
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
    final l10n = AppLocalizations.of(context)!;
    final createdAt = _tryParseCreatedAt(widget.recipe.id);
    final locale = Localizations.localeOf(context).languageCode;
    final createdAtLabel = createdAt != null
        ? DateFormat.yMd(locale).add_Hm().format(createdAt)
        : l10n.recipeDateUnknown;

    final isPublicRecipe = widget.recipe.isPublic || widget.recipe.isDonated;
    final statusLabel = isPublicRecipe ? l10n.publicRecipe : l10n.privateRecipe;
    final statusColor =
        isPublicRecipe ? Colors.blue.shade700 : Colors.green.shade700;

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
                child: Icon(widget.recipe.icon,
                    size: 56, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                widget.recipe.name,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (widget.recipe.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    widget.recipe.description,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _metaChip(
                    icon: Symbols.schedule,
                    text: '${l10n.recipeCreated}: $createdAtLabel',
                    textColor: Colors.grey.shade700,
                    background: Colors.grey.shade100,
                  ),
                  _metaChip(
                    icon: Symbols.public,
                    text: statusLabel,
                    textColor: statusColor,
                    background: statusColor.withValues(alpha: 0.12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String text,
    required Color textColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _tryParseCreatedAt(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('_');
    if (parts.length >= 2) {
      final ts = int.tryParse(parts[1]);
      if (ts != null && ts > 0) {
        final isMicroseconds = ts > 9999999999999;
        return DateTime.fromMillisecondsSinceEpoch(
          isMicroseconds ? ts ~/ 1000 : ts,
        );
      }
    }

    final numeric = int.tryParse(trimmed);
    if (numeric != null && numeric > 0) {
      final isMicroseconds = numeric > 9999999999999;
      return DateTime.fromMillisecondsSinceEpoch(
        isMicroseconds ? numeric ~/ 1000 : numeric,
      );
    }

    return null;
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
            ...widget.recipe.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Symbols.circle, size: 8, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _ingredientDisplayValue(context, ingredient),
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

  String _ingredientDisplayValue(
    BuildContext context,
    RecipeIngredient ingredient,
  ) {
    if (ingredient.quantity <= 0 && ingredient.unit.isEmpty) {
      return ingredient.name;
    }

    final isInteger =
        ingredient.quantity.truncateToDouble() == ingredient.quantity;
    final quantityText = isInteger
        ? ingredient.quantity.toInt().toString()
        : ingredient.quantity.toStringAsFixed(1);
    final localizedUnit = _localizedUnitLabel(context, ingredient.unit);
    final amountText =
        localizedUnit.isEmpty ? quantityText : '$quantityText $localizedUnit';
    return '${ingredient.name} — $amountText';
  }

  String _localizedUnitLabel(BuildContext context, String unit) {
    final l10n = AppLocalizations.of(context)!;
    switch (unit.trim().toLowerCase()) {
      case 'g':
        return l10n.grams;
      case 'mg':
        return l10n.mg;
      case 'kg':
        return l10n.kilograms;
      case 'pcs':
        return l10n.pieces;
      case 'pack':
        return l10n.pack;
      case 'pkg':
      case 'package':
        return l10n.package;
      case 'l':
        return l10n.liters;
      case 'ml':
        return l10n.milliliters;
      case 'tsp':
        return l10n.teaspoon;
      case 'tbsp':
        return l10n.tablespoon;
      case 'cup':
        return l10n.glass;
      default:
        return unit;
    }
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
            _nutrientRow(
                l10n.calories, widget.recipe.nutrients['calories'], l10n.kcal),
            const Divider(height: 24),
            _nutrientGroup(l10n.mainNutrients, [
              _nutrientRow(
                  l10n.protein, widget.recipe.nutrients['protein'], l10n.grams),
              _nutrientRow(
                  l10n.carbs, widget.recipe.nutrients['carbs'], l10n.grams,
                  subRows: [
                    _nutrientSubRow(l10n.sugarSub,
                        widget.recipe.nutrients['sugar'], l10n.grams),
                    _nutrientSubRow(l10n.fiberSub,
                        widget.recipe.nutrients['fiber'], l10n.grams),
                  ]),
              _nutrientRow(l10n.fat, widget.recipe.nutrients['fat'], l10n.grams,
                  subRows: [
                    _nutrientSubRow(l10n.saturatedFatSub,
                        widget.recipe.nutrients['saturated_fat'], l10n.grams),
                    _nutrientSubRow(
                        l10n.polyunsaturatedFatSub,
                        widget.recipe.nutrients['polyunsaturated_fat'],
                        l10n.grams),
                    _nutrientSubRow(
                        l10n.monounsaturatedFatSub,
                        widget.recipe.nutrients['monounsaturated_fat'],
                        l10n.grams),
                    _nutrientSubRow(l10n.transFatSub,
                        widget.recipe.nutrients['trans_fat'], l10n.grams),
                    _nutrientSubRow(l10n.cholesterolSub,
                        widget.recipe.nutrients['cholesterol'], l10n.mg),
                  ]),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.minerals, [
              _nutrientRow(
                  l10n.sodium, widget.recipe.nutrients['sodium'], l10n.mg),
              _nutrientRow(l10n.potassium, widget.recipe.nutrients['potassium'],
                  l10n.mg),
              _nutrientRow(
                  l10n.calcium, widget.recipe.nutrients['calcium'], l10n.mg),
              _nutrientRow(l10n.iron, widget.recipe.nutrients['iron'], l10n.mg),
              _nutrientRow(
                  _nutrientLabel('magnesium', l10n), widget.recipe.nutrients['magnesium'], _getUnitForKey('magnesium', l10n)),
              _nutrientRow(
                  _nutrientLabel('phosphorus', l10n), widget.recipe.nutrients['phosphorus'], _getUnitForKey('phosphorus', l10n)),
              _nutrientRow(
                  _nutrientLabel('zinc', l10n), widget.recipe.nutrients['zinc'], _getUnitForKey('zinc', l10n)),
              _nutrientRow(
                  _nutrientLabel('copper', l10n), widget.recipe.nutrients['copper'], _getUnitForKey('copper', l10n)),
              _nutrientRow(
                  _nutrientLabel('manganese', l10n), widget.recipe.nutrients['manganese'], _getUnitForKey('manganese', l10n)),
              _nutrientRow(
                  _nutrientLabel('selenium', l10n), widget.recipe.nutrients['selenium'], _getUnitForKey('selenium', l10n)),
              _nutrientRow(
                  _nutrientLabel('iodine', l10n), widget.recipe.nutrients['iodine'], _getUnitForKey('iodine', l10n)),
              _nutrientRow(
                  _nutrientLabel('chromium', l10n), widget.recipe.nutrients['chromium'], _getUnitForKey('chromium', l10n)),
              _nutrientRow(
                  _nutrientLabel('molybdenum', l10n), widget.recipe.nutrients['molybdenum'], _getUnitForKey('molybdenum', l10n)),
              _nutrientRow(
                  _nutrientLabel('fluoride', l10n), widget.recipe.nutrients['fluoride'], _getUnitForKey('fluoride', l10n)),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.vitamins, [
              _nutrientRow(l10n.vitaminA, widget.recipe.nutrients['vitamin_a'],
                  l10n.mcg),
              _nutrientRow(
                  l10n.vitaminC, widget.recipe.nutrients['vitamin_c'], l10n.mg),
              _nutrientRow(l10n.vitaminD, widget.recipe.nutrients['vitamin_d'],
                  l10n.mcg),
              _nutrientRow(
                  _nutrientLabel('vitamin_e', l10n), widget.recipe.nutrients['vitamin_e'], _getUnitForKey('vitamin_e', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_k', l10n), widget.recipe.nutrients['vitamin_k'], _getUnitForKey('vitamin_k', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b1', l10n), widget.recipe.nutrients['vitamin_b1'], _getUnitForKey('vitamin_b1', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b2', l10n), widget.recipe.nutrients['vitamin_b2'], _getUnitForKey('vitamin_b2', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b3', l10n), widget.recipe.nutrients['vitamin_b3'], _getUnitForKey('vitamin_b3', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b5', l10n), widget.recipe.nutrients['vitamin_b5'], _getUnitForKey('vitamin_b5', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b6', l10n), widget.recipe.nutrients['vitamin_b6'], _getUnitForKey('vitamin_b6', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b7', l10n), widget.recipe.nutrients['vitamin_b7'], _getUnitForKey('vitamin_b7', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b9', l10n), widget.recipe.nutrients['vitamin_b9'], _getUnitForKey('vitamin_b9', l10n)),
              _nutrientRow(
                  _nutrientLabel('vitamin_b12', l10n), widget.recipe.nutrients['vitamin_b12'], _getUnitForKey('vitamin_b12', l10n)),
            ]),
            const Divider(height: 24),
            _nutrientGroup(
              l10n.heavyMetalsAndContaminants,
              [
                _nutrientRow(
                    _nutrientLabel('lead', l10n), widget.recipe.nutrients['lead'], _getUnitForKey('lead', l10n)),
                _nutrientRow(
                    _nutrientLabel('mercury', l10n), widget.recipe.nutrients['mercury'], _getUnitForKey('mercury', l10n)),
                _nutrientRow(
                    _nutrientLabel('cadmium', l10n), widget.recipe.nutrients['cadmium'], _getUnitForKey('cadmium', l10n)),
                _nutrientRow(
                    _nutrientLabel('arsenic', l10n), widget.recipe.nutrients['arsenic'], _getUnitForKey('arsenic', l10n)),
                _nutrientRow(
                    _nutrientLabel('nitrates', l10n), widget.recipe.nutrients['nitrates'], _getUnitForKey('nitrates', l10n)),
                _nutrientRow(
                    _nutrientLabel('pesticides', l10n), widget.recipe.nutrients['pesticides'], _getUnitForKey('pesticides', l10n)),
              ],
            ),
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
  Widget _buildPremiumAdviceStub(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.05),
            Colors.deepPurple.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.amber.shade700, Colors.orange.shade600],
                  ).createShader(bounds),
                  child: const Icon(
                    Symbols.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.featurePersonalAdvice} (Premium)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.personalAdvicePremiumOnly,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade800,
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade800, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/subscription', extra: SubscriptionTier.premium);
                  },
                  icon: const Icon(Symbols.workspace_premium, size: 18, color: Colors.white),
                  label: Text(
                    l10n.upgradeToPremium,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalAdviceCard(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (profile == null || !profile.isPersonalAdviceAvailable) {
      return _buildPremiumAdviceStub(context, theme, l10n);
    }

    if (_personalAdvice.isEmpty) {
      if (!_isLoadingAdvice) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadPersonalAdvice();
        });
      }

      final locale = Localizations.localeOf(context).languageCode;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text(
                locale == 'ru'
                    ? 'ИИ анализирует совместимость рецепта...'
                    : (locale == 'uk'
                        ? 'ШІ аналізує сумісність рецепту...'
                        : 'AI is analyzing recipe compatibility...'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final isNewFormat = _personalAdvice.contains('[[IS_COMPATIBLE]]');
    bool isCompatible = true;
    String incompatibleReason = '';

    if (isNewFormat) {
      final isCompatibleMatch = RegExp(r'\[\[IS_COMPATIBLE\]\](.*?)(?=\[\[|$)').firstMatch(_personalAdvice);
      final incompatibleReasonMatch = RegExp(r'\[\[INCOMPATIBLE_REASON\]\](.*?)(?=\[\[|$)').firstMatch(_personalAdvice);

      isCompatible = isCompatibleMatch?.group(1)?.trim().toLowerCase() == 'true';
      incompatibleReason = incompatibleReasonMatch?.group(1)?.trim() ?? '';
    }

    Color cardBgColor = Colors.blue.withValues(alpha: 0.04);
    Color cardBorderColor = Colors.blue.withValues(alpha: 0.15);
    Color titleColor = Colors.blue.shade900;
    IconData headerIcon = Symbols.psychology;

    if (_personalAdvice.isNotEmpty) {
      if (isNewFormat) {
        if (!isCompatible) {
          cardBgColor = Colors.red.withValues(alpha: 0.04);
          cardBorderColor = Colors.red.withValues(alpha: 0.15);
          titleColor = Colors.red.shade900;
          headerIcon = Symbols.warning;
        } else {
          cardBgColor = Colors.green.withValues(alpha: 0.04);
          cardBorderColor = Colors.green.withValues(alpha: 0.15);
          titleColor = Colors.green.shade900;
          headerIcon = Symbols.check_circle;
        }
      }
    }

    return Card(
      color: cardBgColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  headerIcon,
                  color: titleColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isNewFormat 
                        ? (isCompatible ? 'Совместимо с вашей диетой' : 'Не рекомендуется')
                        : 'Анализ и рекомендации ИИ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ),
                if (_isLoadingAdvice)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axis: Axis.vertical,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _personalAdvice.isNotEmpty
                  ? Column(
                      key: const ValueKey('advice-content-loaded'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDisclaimer(l10n, theme),
                        const SizedBox(height: 12),
                        if (isNewFormat && !isCompatible && incompatibleReason.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Symbols.error_med, color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    incompatibleReason,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ..._buildGroupedAdvice(_personalAdvice, theme, l10n),
                      ],
                    )
                  : _isLoadingAdvice
                      ? Center(
                          key: const ValueKey('advice-content-loading'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(strokeWidth: 2),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.moderationChecking,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Text(
                          'Загрузка легких рекомендаций по питанию...',
                          key: const ValueKey('advice-content-idle'),
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.info, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.healthAdviceDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Colors.orange.shade800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedAdvice(
      String advice, ThemeData theme, AppLocalizations l10n) {
    final isNewFormat = advice.contains('[[IS_COMPATIBLE]]');
    if (isNewFormat) {
      final adviceMatch = RegExp(r'\[\[ADVICE\]\](.*?)(?=\[\[|$)').firstMatch(advice);
      final mainAdvice = adviceMatch?.group(1)?.trim() ?? advice;
      return [
        Text(
          mainAdvice,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.45,
            color: Colors.black87,
          ),
        ),
      ];
    }

    final doctorMatch =
        RegExp(r'\[\[DOCTOR\]\](.*?)(?=\[\[|$)').firstMatch(advice);
    final dietitianMatch =
        RegExp(r'\[\[DIETITIAN\]\](.*?)(?=\[\[|$)').firstMatch(advice);
    final trainerMatch =
        RegExp(r'\[\[TRAINER\]\](.*?)(?=\[\[|$)').firstMatch(advice);

    final doctorText = doctorMatch?.group(1)?.trim() ?? '';
    final dietitianText = dietitianMatch?.group(1)?.trim() ?? '';
    final trainerText = trainerMatch?.group(1)?.trim() ?? '';

    if (doctorText.isEmpty && dietitianText.isEmpty && trainerText.isEmpty) {
      return [
        Text(advice, style: theme.textTheme.bodySmall),
      ];
    }

    return [
      if (doctorText.isNotEmpty)
        _buildExpertRow(
          icon: Symbols.medical_services,
          label: _localizeExpert('doctor', l10n),
          text: doctorText,
          color: Colors.red.shade400,
          theme: theme,
        ),
      if (dietitianText.isNotEmpty)
        _buildExpertRow(
          icon: Symbols.nutrition,
          label: _localizeExpert('dietitian', l10n),
          text: dietitianText,
          color: Colors.green.shade600,
          theme: theme,
        ),
      if (trainerText.isNotEmpty)
        _buildExpertRow(
          icon: Symbols.fitness_center,
          label: _localizeExpert('trainer', l10n),
          text: trainerText,
          color: Colors.orange.shade700,
          theme: theme,
        ),
    ];
  }

  String _localizeExpert(String key, AppLocalizations l10n) {
    final raw = l10n.healthConditionsTitle; // "Врач, Диетолог, Тренер"
    final parts = raw.contains('(')
        ? raw.substring(raw.indexOf('(') + 1, raw.indexOf(')')).split(',')
        : raw.split(',');

    if (parts.length < 3) return key;

    return switch (key) {
      'doctor' => parts[0].trim(),
      'dietitian' => parts[1].trim(),
      'trainer' => parts[2].trim(),
      _ => key,
    };
  }

  Widget _buildExpertRow({
    required IconData icon,
    required String label,
    required String text,
    required Color color,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
