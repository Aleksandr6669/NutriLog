import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/user_profile.dart';
import '../../services/gemini_recipe_service.dart';
import '../../services/cloud_data_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final bool selectionMode;
  final bool isSelected;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.selectionMode = false,
    this.isSelected = false,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _geminiRecipeService = GeminiRecipeService();
  String _personalAdvice = '';
  bool _isLoadingAdvice = false;
  String _lastAdviceContextHash = '';

  @override
  void initState() {
    super.initState();
    _loadPersonalAdvice();
  }

  String _calculateContextHash(String context, Recipe recipe) {
    // Простой хэш на основе контекста профиля и данных рецепта
    final recipeData = '${recipe.name}${recipe.ingredients.length}${recipe.nutrients['calories']}';
    return base64Encode(utf8.encode('$context|$recipeData'));
  }

  Future<void> _loadPersonalAdvice() async {
    final profile = context.read<ProfileProvider>().profile;
    if (profile == null) return;

    final currentHash = _calculateContextHash(profile.healthConditions, widget.recipe);
    
    // 1. Пытаемся загрузить из локального кэша
    final prefs = await SharedPreferences.getInstance();
    final userId = CloudDataService.instance.currentUserId ?? 'guest';
    final cacheKey = 'personal_advice_${userId}_${widget.recipe.id}';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      final decoded = json.decode(cachedData);
      if (decoded['hash'] == currentHash) {
        if (mounted) {
          setState(() {
            _personalAdvice = decoded['advice'];
            _lastAdviceContextHash = currentHash;
          });
          return;
        }
      }
    }

    // 2. Если нет в кэше или хэш не совпадает — загружаем из облака или генерируем
    if (CloudDataService.instance.isSignedIn) {
      final cloudData = await CloudDataService.instance.readMap('personalRecipeAdvice_${widget.recipe.id}');
      if (cloudData != null && cloudData['hash'] == currentHash) {
        final advice = cloudData['advice'] as String;
        if (mounted) {
          setState(() {
            _personalAdvice = advice;
            _lastAdviceContextHash = currentHash;
          });
          // Сохраняем в локальный кэш
          await prefs.setString(cacheKey, json.encode({'advice': advice, 'hash': currentHash}));
          return;
        }
      }
    }

    // 3. Если и там нет — генерируем (если доступны ИИ фичи для личных советов)
    if (profile.isPersonalAdviceAvailable) {
      await _generateNewAdvice(profile.healthConditions, currentHash);
    }
  }

  Future<void> _generateNewAdvice(String healthConditions, String hash) async {
    if (healthConditions.isEmpty) return;
    
    setState(() => _isLoadingAdvice = true);
    try {
      final advice = await _geminiRecipeService.generateMedicalAdvice(
        recipeName: widget.recipe.name,
        recipeDescription: widget.recipe.description,
        ingredients: widget.recipe.ingredients,
        nutrients: widget.recipe.nutrients,
        healthConditions: healthConditions,
        clarification: widget.recipe.clarification,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (mounted) {
        setState(() {
          _personalAdvice = advice;
          _lastAdviceContextHash = hash;
          _isLoadingAdvice = false;
        });

        // Сохраняем в локальный кэш
        final profile = context.read<ProfileProvider>().profile;
        if (profile != null) {
          final prefs = await SharedPreferences.getInstance();
          final userId = CloudDataService.instance.currentUserId ?? 'guest';
          final cacheKey = 'personal_advice_${userId}_${widget.recipe.id}';
          await prefs.setString(cacheKey, json.encode({'advice': advice, 'hash': hash}));

          // Сохраняем в облако
          if (CloudDataService.instance.isSignedIn) {
            await CloudDataService.instance.writeMap('personalRecipeAdvice_${widget.recipe.id}', {
              'advice': advice,
              'hash': hash,
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
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
      MaterialPageRoute(builder: (_) => EditRecipeScreen(recipe: widget.recipe)),
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
          else if (widget.recipe.isUserRecipe && !widget.recipe.isDonated)
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
            // Показываем персональный совет если он есть или грузится
            if (_personalAdvice.isNotEmpty || _isLoadingAdvice) ...[
              _buildPersonalAdviceCard(context),
              const SizedBox(height: 24),
            ],
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
              _nutrientRow(l10n.carbs, widget.recipe.nutrients['carbs'], l10n.grams,
                  subRows: [
                    _nutrientSubRow(
                        l10n.sugarSub, widget.recipe.nutrients['sugar'], l10n.grams),
                    _nutrientSubRow(
                        l10n.fiberSub, widget.recipe.nutrients['fiber'], l10n.grams),
                  ]),
              _nutrientRow(l10n.fat, widget.recipe.nutrients['fat'], l10n.grams,
                  subRows: [
                    _nutrientSubRow(l10n.saturatedFatSub,
                        widget.recipe.nutrients['saturated_fat'], l10n.grams),
                    _nutrientSubRow(l10n.polyunsaturatedFatSub,
                        widget.recipe.nutrients['polyunsaturated_fat'], l10n.grams),
                    _nutrientSubRow(l10n.monounsaturatedFatSub,
                        widget.recipe.nutrients['monounsaturated_fat'], l10n.grams),
                    _nutrientSubRow(l10n.transFatSub,
                        widget.recipe.nutrients['trans_fat'], l10n.grams),
                    _nutrientSubRow(l10n.cholesterolSub,
                        widget.recipe.nutrients['cholesterol'], l10n.mg),
                  ]),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.minerals, [
              _nutrientRow(l10n.sodium, widget.recipe.nutrients['sodium'], l10n.mg),
              _nutrientRow(
                  l10n.potassium, widget.recipe.nutrients['potassium'], l10n.mg),
              _nutrientRow(l10n.calcium, widget.recipe.nutrients['calcium'], l10n.mg),
              _nutrientRow(l10n.iron, widget.recipe.nutrients['iron'], l10n.mg),
            ]),
            const Divider(height: 24),
            _nutrientGroup(l10n.vitamins, [
              _nutrientRow(
                  l10n.vitaminA, widget.recipe.nutrients['vitamin_a'], l10n.mcg),
              _nutrientRow(
                  l10n.vitaminC, widget.recipe.nutrients['vitamin_c'], l10n.mg),
              _nutrientRow(
                  l10n.vitaminD, widget.recipe.nutrients['vitamin_d'], l10n.mcg),
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

  Widget _buildPersonalAdviceCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = context.read<ProfileProvider>().profile;
    final isRestricted = profile != null && !profile.isPersonalAdviceAvailable;

    return Card(
      color: isRestricted ? Colors.grey.shade100 : Colors.blue.shade50.withValues(alpha: 0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.cardRadius,
        side: BorderSide(color: isRestricted ? Colors.grey.shade300 : Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isRestricted ? Symbols.lock : Symbols.smart_toy,
                    color: isRestricted ? Colors.grey.shade600 : Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.healthAdviceTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isRestricted ? Colors.grey.shade800 : Colors.blue.shade900,
                    ),
                  ),
                ),
                if (_isLoadingAdvice && !isRestricted)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (isRestricted)
                Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.personalAdvicePremiumOnly,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/subscription', extra: SubscriptionTier.premium),
                      icon: const Icon(Symbols.bolt, size: 18),
                      label: Text(l10n.upgradeToPremium),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              if (_personalAdvice.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.info, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.statsAiNotMedicalAdvice,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLoadingAdvice && _personalAdvice.isEmpty)
                Text(
                  '...',
                  style: TextStyle(color: Colors.blue.shade900),
                )
              else
                Text(
                  _personalAdvice,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.blue.shade900,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
