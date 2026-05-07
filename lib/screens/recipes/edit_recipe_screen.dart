import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/services/cloud_data_service.dart';
import 'package:nutri_log/services/firebase_auth_service.dart';
import 'package:nutri_log/services/firebase_bootstrap_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe? recipe;
  final Recipe? initialDraft;
  final String? initialClarification;

  const EditRecipeScreen(
      {super.key, this.recipe, this.initialDraft, this.initialClarification});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  static const List<String> unitOptions = [
    'g',
    'mg',
    'kg',
    'pcs',
    'pack',
    'pkg',
    'l',
    'ml',
    'tsp',
    'tbsp',
    'cup',
  ];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _formKey = GlobalKey<FormState>();
  final _recipeService = RecipeService();
  final _geminiRecipeService = GeminiRecipeService();

  // Main info
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _clarificationController;
  IconData _selectedIcon = Symbols.restaurant;

  // Nutrient controllers
  final Map<String, TextEditingController> _nutrientControllers = {};
  final List<_IngredientFormItem> _ingredientItems = [];
  bool _autoCalculateCalories = true;
  bool _isSyncingCalories = false;
  bool _isAiCalculating = false;
  String? _aiStatus;
  bool _isAiError = false;
  int _aiRequestId = 0;
  bool _isPublic = false;
  bool _isDonating = false;
  bool _isDonated = false;
  bool _isDonateAiChecking = false;
  bool _isDonateAiApproved = false;
  String? _donateAiStatus;
  Timer? _donateAiDebounce;
  int _donateAiRequestId = 0;

  final List<String> _nutrientKeys = [
    'calories',
    'protein',
    'carbs',
    'fat',
    'fiber',
    'sugar',
    'saturated_fat',
    'polyunsaturated_fat',
    'monounsaturated_fat',
    'trans_fat',
    'cholesterol',
    'sodium',
    'potassium',
    'vitamin_a',
    'vitamin_c',
    'vitamin_d',
    'calcium',
    'iron'
  ];

  @override
  void initState() {
    super.initState();
    final sourceRecipe = widget.recipe ?? widget.initialDraft;

    _nameController = TextEditingController(text: sourceRecipe?.name ?? '');
    _descriptionController =
        TextEditingController(text: sourceRecipe?.description ?? '');
    _clarificationController =
        TextEditingController(text: widget.initialClarification ?? '');
    _selectedIcon = sourceRecipe?.icon ?? Symbols.restaurant;
    _isPublic = sourceRecipe?.isPublic ?? false;
    _isDonated = sourceRecipe?.isDonated ?? false;

    _nameController.addListener(_onDonateValidationInputChanged);
    _descriptionController.addListener(_onDonateValidationInputChanged);
    _clarificationController.addListener(_onDonateValidationInputChanged);

    // Если initialDraft (создание по фото/описанию) — нутриенты всегда пустые, расчет только через AI
    final isFromDraft = widget.initialDraft != null;

    // Инициализация контроллеров нутриентов
    for (var key in _nutrientKeys) {
      _nutrientControllers[key] = TextEditingController(
        text: isFromDraft
            ? '0.0'
            : (sourceRecipe?.nutrients[key]?.toString() ?? '0.0'),
      );
    }

    final loadedIngredients = sourceRecipe?.ingredients ?? const [];
    if (loadedIngredients.isNotEmpty) {
      for (final ingredient in loadedIngredients) {
        final item = _IngredientFormItem(
          name: ingredient.name,
          quantity:
              ingredient.quantity <= 0 ? '' : ingredient.quantity.toString(),
          unit: ingredient.unit,
          isAmbiguous: ingredient.isAmbiguous,
        );
        _attachIngredientListeners(item);
        _ingredientItems.add(item);
      }
    }

    _nutrientControllers['calories']
        ?.addListener(_onDonateValidationInputChanged);

    _autoCalculateCalories = _shouldEnableAutoCalories();
    _nutrientControllers['protein']?.addListener(_onMacroChanged);
    _nutrientControllers['carbs']?.addListener(_onMacroChanged);
    _nutrientControllers['fat']?.addListener(_onMacroChanged);

    unawaited(_applyInitialAutomation(isFromDraft: isFromDraft));

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _onDonateValidationInputChanged());
  }

  void _attachIngredientListeners(_IngredientFormItem item) {
    item.nameController.addListener(_onDonateValidationInputChanged);
    item.quantityController.addListener(_onDonateValidationInputChanged);
  }

  Future<void> _applyInitialAutomation({required bool isFromDraft}) async {
    if (isFromDraft) {
      bool isAutoAiEnabled = true;
      try {
        final settings = await NotificationSettingsService().load();
        isAutoAiEnabled = settings.recipeAiAutoNutritionEnabled;
      } catch (_) {
        // Если настройки недоступны, используем безопасное поведение по умолчанию.
      }

      if (!mounted) return;
      if (isAutoAiEnabled && _ingredientItems.isNotEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _recalculateNutrientsWithAi());
      }
      return;
    }

    if (_autoCalculateCalories) {
      _applyAutoCalories();
    }
  }

  void _detachIngredientListeners(_IngredientFormItem item) {
    item.nameController.removeListener(_onDonateValidationInputChanged);
    item.quantityController.removeListener(_onDonateValidationInputChanged);
  }

  void _onDonateValidationInputChanged() {
    if (!mounted || _isDonated) return;

    if (!_isFormReadyForDonate) {
      _donateAiDebounce?.cancel();
      if (_isDonateAiChecking ||
          _isDonateAiApproved ||
          _donateAiStatus != null) {
        setState(() {
          _isDonateAiChecking = false;
          _isDonateAiApproved = false;
          _donateAiStatus = null;
        });
      }
      return;
    }

    _donateAiDebounce?.cancel();
    if (_isDonateAiApproved || _donateAiStatus != l10n.recipeAiCalculating) {
      setState(() {
        _isDonateAiApproved = false;
        _donateAiStatus = l10n.recipeAiCalculating;
      });
    }
    _donateAiDebounce = Timer(const Duration(milliseconds: 700), () {
      _runDonateAiModeration();
    });
  }

  Future<DonateRecipeModerationResult?> _runDonateAiModeration() async {
    if (!_isFormReadyForDonate || _isDonated) return null;

    final requestId = ++_donateAiRequestId;
    if (mounted) {
      setState(() {
        _isDonateAiChecking = true;
        _isDonateAiApproved = false;
        _donateAiStatus = l10n.recipeAiCalculating;
      });
    }

    try {
      final nutrients = <String, double>{};
      for (final key in _nutrientKeys) {
        nutrients[key] = _parseAmount(_nutrientControllers[key]!.text);
      }

      final ingredients = _ingredientItems
          .map((item) => RecipeIngredient(
                name: item.nameController.text.trim(),
                quantity: _parseAmount(item.quantityController.text),
                unit: item.unit.trim(),
              ))
          .where((i) => i.name.isNotEmpty)
          .toList(growable: false);

      final result =
          await _geminiRecipeService.validateRecipeForCommunityDonation(
        recipeName: _nameController.text.trim(),
        recipeDescription: _descriptionController.text.trim(),
        clarification: _clarificationController.text.trim(),
        ingredients: ingredients,
        nutrients: nutrients,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted || requestId != _donateAiRequestId) return null;

      setState(() {
        _isDonateAiChecking = false;
        _isDonateAiApproved = result.approved;
        _donateAiStatus = result.reason;
      });
      return result;
    } on GeminiRecipeException catch (e) {
      if (!mounted || requestId != _donateAiRequestId) return null;
      setState(() {
        _isDonateAiChecking = false;
        _isDonateAiApproved = false;
        _donateAiStatus = e.message;
      });
      return null;
    } catch (_) {
      if (!mounted || requestId != _donateAiRequestId) return null;
      setState(() {
        _isDonateAiChecking = false;
        _isDonateAiApproved = false;
        _donateAiStatus = l10n.recipeAiFailed;
      });
      return null;
    }
  }

  bool _shouldEnableAutoCalories() {
    final sourceRecipe = widget.recipe ?? widget.initialDraft;
    if (sourceRecipe == null) return true;

    final recipeNutrients = sourceRecipe.nutrients;
    final protein = recipeNutrients['protein'] ?? 0;
    final carbs = recipeNutrients['carbs'] ?? 0;
    final fat = recipeNutrients['fat'] ?? 0;
    final calories = recipeNutrients['calories'] ?? 0;
    final calculated = protein * 4 + carbs * 4 + fat * 9;
    return (calories - calculated).abs() < 0.2;
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  String _formatNumber(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded.truncateToDouble() == rounded) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  void _onMacroChanged() {
    if (!_autoCalculateCalories || _isSyncingCalories) return;
    _applyAutoCalories();
  }

  void _applyAutoCalories() {
    final protein = _parseAmount(_nutrientControllers['protein']?.text ?? '0');
    final carbs = _parseAmount(_nutrientControllers['carbs']?.text ?? '0');
    final fat = _parseAmount(_nutrientControllers['fat']?.text ?? '0');
    final calories = protein * 4 + carbs * 4 + fat * 9;

    _isSyncingCalories = true;
    _nutrientControllers['calories']?.text = _formatNumber(calories);
    _isSyncingCalories = false;
  }

  void _addIngredientRow() {
    setState(() {
      final item = _IngredientFormItem();
      _attachIngredientListeners(item);
      _ingredientItems.add(item);
    });
  }

  void _removeIngredientRow(int index) {
    final item = _ingredientItems.removeAt(index);
    _detachIngredientListeners(item);
    item.dispose();
    setState(() {});
  }

  Future<void> _recalculateNutrientsWithAi() async {
    final ingredients = _ingredientItems
        .map(
          (item) => RecipeIngredient(
            name: item.nameController.text.trim(),
            quantity: _parseAmount(item.quantityController.text),
            unit: item.unit.trim(),
          ),
        )
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) {
      if (mounted) {
        setState(() {
          _aiStatus = l10n.recipeAiAddIngredients;
          _isAiError = true;
          _isAiCalculating = false;
        });
      }
      return;
    }

    final requestId = ++_aiRequestId;
    if (mounted) {
      setState(() {
        _isAiCalculating = true;
        _aiStatus = l10n.recipeAiCalculating;
        _isAiError = false;
        _autoCalculateCalories = false; // Отключаем авто БЖУ при расчёте AI
      });
    }

    try {
      final nutrients = await _geminiRecipeService.estimateNutrients(
        recipeName: _nameController.text,
        recipeDescription: _descriptionController.text,
        clarification: _clarificationController.text,
        ingredients: ingredients,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted || requestId != _aiRequestId) return;

      _isSyncingCalories = true;
      for (final key in _nutrientKeys) {
        _nutrientControllers[key]?.text = _formatNumber(nutrients[key] ?? 0);
      }
      _isSyncingCalories = false;

      setState(() {
        _isAiCalculating = false;
        _aiStatus = l10n.recipeAiUpdated;
        _isAiError = false;
      });
    } on GeminiRecipeException catch (e) {
      if (!mounted || requestId != _aiRequestId) return;
      setState(() {
        _isAiCalculating = false;
        _aiStatus = e.message;
        _isAiError = true;
      });
    } catch (_) {
      if (!mounted || requestId != _aiRequestId) return;
      setState(() {
        _isAiCalculating = false;
        _aiStatus = l10n.recipeAiFailed;
        _isAiError = true;
      });
    }
  }

  @override
  void dispose() {
    _donateAiDebounce?.cancel();
    _nutrientControllers['protein']?.removeListener(_onMacroChanged);
    _nutrientControllers['carbs']?.removeListener(_onMacroChanged);
    _nutrientControllers['fat']?.removeListener(_onMacroChanged);
    _nutrientControllers['calories']
        ?.removeListener(_onDonateValidationInputChanged);
    _nameController.removeListener(_onDonateValidationInputChanged);
    _descriptionController.removeListener(_onDonateValidationInputChanged);
    _clarificationController.removeListener(_onDonateValidationInputChanged);
    _nameController.dispose();
    _clarificationController.dispose();
    _descriptionController.dispose();
    for (var controller in _nutrientControllers.values) {
      controller.dispose();
    }
    for (final ingredientItem in _ingredientItems) {
      _detachIngredientListeners(ingredientItem);
      ingredientItem.dispose();
    }
    super.dispose();
  }

  void _showIconPicker() {
    final icons = [
      Symbols.restaurant,
      Symbols.lunch_dining,
      Symbols.local_bar,
      Symbols.cake,
      Symbols.fastfood,
      Symbols.breakfast_dining,
      Symbols.ramen_dining,
      Symbols.icecream,
      Symbols.local_pizza,
      Symbols.set_meal,
      Symbols.dinner_dining,
      Symbols.blender,
      Symbols.soup_kitchen,
      Symbols.coffee,
      Symbols.wine_bar,
      Symbols.liquor,
      Symbols.bakery_dining,
      Symbols.egg,
      Symbols.egg_alt,
      Symbols.cooking,
      Symbols.kebab_dining,
      Symbols.takeout_dining,
      Symbols.rice_bowl,
      Symbols.cookie,
      Symbols.donut_large,
      Symbols.local_cafe,
      Symbols.local_drink,
      Symbols.tapas,
      Symbols.flatware,
      Symbols.outdoor_grill,
      Symbols.kitchen,
      Symbols.microwave,
      Symbols.skillet,
      Symbols.nutrition,
      Symbols.eco,
      Symbols.restaurant_menu
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canvasColor = theme.brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight;
        final unselectedBg = theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100;
        final unselectedIcon = theme.brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade700;
        return AlertDialog(
          backgroundColor: canvasColor,
          title: Text(
            l10n.selectIconDialogTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                final icon = icons[index];
                final isSelected = _selectedIcon == icon;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : unselectedBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? AppColors.primary : unselectedIcon,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveRecipe() async {
    if (_isDonated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.donateRecipeAlreadyDonated),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final Map<String, double> nutrients = {};
      for (var key in _nutrientKeys) {
        nutrients[key] = _parseAmount(_nutrientControllers[key]!.text);
      }

      final ingredients = _ingredientItems
          .map(
            (item) => RecipeIngredient(
              name: item.nameController.text.trim(),
              quantity: _parseAmount(item.quantityController.text),
              unit: item.unit.trim(),
            ),
          )
          .where((ingredient) => ingredient.name.isNotEmpty)
          .toList();

      final recipe = Recipe(
        id: widget.recipe?.id ??
            'recipe_${DateTime.now().microsecondsSinceEpoch}_${_nameController.text.trim().hashCode}',
        name: _nameController.text,
        description: _descriptionController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isUserRecipe: true,
        isPublic: _isPublic,
        ingredients: ingredients,
        instructions:
            (widget.recipe ?? widget.initialDraft)?.instructions ?? [],
      );

      if (widget.recipe == null) {
        await _recipeService.addRecipe(recipe);
      } else {
        await _recipeService.updateRecipe(recipe);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _deleteRecipe() async {
    if (widget.recipe == null) return;
    await _recipeService.deleteRecipe(widget.recipe!.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  bool get _isFormReadyForDonate {
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasIngredients = _ingredientItems
        .any((item) => item.nameController.text.trim().isNotEmpty);
    final hasCalories =
        _parseAmount(_nutrientControllers['calories']?.text ?? '') > 0;
    return hasName && hasIngredients && hasCalories;
  }

  Future<void> _donateRecipe() async {
    if (!_isDonateAiApproved || _isDonateAiChecking) {
      final moderation = await _runDonateAiModeration();
      if (!mounted) return;
      if (moderation == null || !moderation.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_donateAiStatus ?? l10n.recipeAiFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final cloudService = CloudDataService.instance;
    await FirebaseBootstrapService.ensureInitialized();
    if (FirebaseAuthService.instance.currentUser == null ||
        !cloudService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.donateRecipeSignInRequired),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isDonating = true);
    try {
      // Сначала сохраняем/обновляем локальный рецепт без закрытия экрана.
      final nutrients = <String, double>{};
      for (final key in _nutrientKeys) {
        nutrients[key] = _parseAmount(_nutrientControllers[key]!.text);
      }
      final ingredients = _ingredientItems
          .map((item) => RecipeIngredient(
                name: item.nameController.text.trim(),
                quantity: _parseAmount(item.quantityController.text),
                unit: item.unit.trim(),
              ))
          .where((i) => i.name.isNotEmpty)
          .toList();

      final localRecipe = Recipe(
        id: widget.recipe?.id ??
            'recipe_${DateTime.now().microsecondsSinceEpoch}_${_nameController.text.trim().hashCode}',
        name: _nameController.text.trim(),
        description: _descriptionController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isUserRecipe: true,
        isPublic: _isPublic,
        isDonated: _isDonated,
        ingredients: ingredients,
        instructions: widget.recipe?.instructions ?? [],
      );

      if (widget.recipe == null) {
        await _recipeService.addRecipe(localRecipe);
      } else {
        await _recipeService.updateRecipe(localRecipe);
      }

      final donationRecipe = localRecipe.copyWith(
        isUserRecipe: false,
        isPublic: true,
        isDonated: true,
      );
      await cloudService.donateRecipe(donationRecipe.toJson());

      // Помечаем локальную копию как переданную сообществу.
      await _recipeService.updateRecipe(
        localRecipe.copyWith(
          isUserRecipe: false,
          isPublic: true,
          isDonated: true,
        ),
      );

      if (!mounted) return;
      context.go('/recipes');
    } on StateError {
      if (!mounted) return;
      setState(() => _isDonating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.donateRecipeSignInRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isDonating = false);
      final message = e.code == 'permission-denied'
          ? l10n.donateRecipePermissionDenied
          : '${l10n.donateRecipeError}: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDonating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.donateRecipeError}: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildDonateCard() {
    final theme = Theme.of(context);
    final isEnabled = _isFormReadyForDonate &&
        !_isDonated &&
        _isDonateAiApproved &&
        !_isDonateAiChecking;
    final accentColor = _isDonated ? Colors.green.shade600 : Colors.deepOrange;
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.cardRadius,
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDonated ? Symbols.volunteer_activism : Symbols.share,
                  size: 20,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isDonated
                        ? l10n.donateRecipeAlreadyDonated
                        : l10n.donateRecipeCardTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.donateRecipeCardDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (_isDonated || _isDonateAiApproved)
                    ? Colors.green.withValues(alpha: 0.1)
                    : (_isDonateAiChecking
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_isDonated || _isDonateAiApproved)
                      ? Colors.green.withValues(alpha: 0.35)
                      : (_isDonateAiChecking
                          ? Colors.orange.withValues(alpha: 0.35)
                          : Colors.red.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  if (_isDonateAiChecking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      (_isDonated || _isDonateAiApproved)
                          ? Symbols.verified
                          : Symbols.warning,
                      size: 16,
                      color: (_isDonated || _isDonateAiApproved)
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isDonated
                          ? l10n.donateRecipeAlreadyDonated
                          : (_donateAiStatus ??
                              'Для передачи рецепта в сообщество требуется полная AI-проверка на цензуру и валидность.'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (isEnabled && !_isDonating) ? _donateRecipe : null,
                icon: _isDonating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isDonated
                        ? Symbols.check_circle
                        : Symbols.volunteer_activism),
                label: Text(_isDonated
                    ? l10n.donateRecipeAlreadyDonated
                    : l10n.donateRecipeButton),
                style: FilledButton.styleFrom(
                  backgroundColor: isEnabled ? accentColor : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityCard() {
    final theme = Theme.of(context);
    final canManageVisibility = widget.recipe?.isUserRecipe ?? true;
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.makePublic,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isPublic ? l10n.publicRecipe : l10n.privateRecipe,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isPublic
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _isPublic,
              onChanged: canManageVisibility && !_isDonated
                  ? (value) {
                      HapticFeedback.selectionClick();
                      setState(() => _isPublic = value);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(
            widget.recipe == null ? l10n.newRecipeTitle : l10n.editRecipeTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save, weight: 600),
            onPressed: _isDonated ? null : _saveRecipe,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: glassBodyPadding(
            context,
            left: 16,
            top: 8,
            right: 16,
            bottom: 110,
          ),
          child: Column(
            children: [
              _buildMainInfoCard(),
              const SizedBox(height: 20),
              _buildAiClarificationCard(),
              const SizedBox(height: 20),
              _buildIngredientsCard(),
              const SizedBox(height: 20),
              _buildNutrientsCard(),
              const SizedBox(height: 24),
              _buildVisibilityCard(),
              const SizedBox(height: 12),
              _buildDonateCard(),
              if (widget.recipe != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _isDonated ? null : _deleteRecipe,
                    icon: const Icon(Symbols.delete),
                    label: Text(l10n.removeRecipeTooltip),
                    style: TextButton.styleFrom(
                      foregroundColor: _isDonated ? Colors.grey : Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mainInfo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: _showIconPicker,
                borderRadius: BorderRadius.circular(50),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child:
                      Icon(_selectedIcon, size: 48, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: AppStyles.underlineInputDecoration(
                  label: l10n.recipeNameLabel),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.enterName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: AppStyles.underlineInputDecoration(
                  label: l10n.recipeDescriptionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.nutritionValuePerPortion,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isAiCalculating ? null : _recalculateNutrientsWithAi,
                icon: const Icon(Symbols.calculate),
                label: Text(l10n.calculateNutrition),
              ),
            ),
            const SizedBox(height: 8),
            if (_aiStatus != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_isAiError ? Colors.red : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isAiError ? Colors.red : AppColors.primary)
                        .withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAiError ? Symbols.error : Symbols.info,
                      size: 18,
                      color:
                          _isAiError ? Colors.red.shade700 : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _aiStatus!,
                        style: TextStyle(
                          color: _isAiError
                              ? Colors.red.shade700
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                l10n.recipeAiDisclaimer,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _nutrientRow([('calories', l10n.calories, l10n.kcal)],
                      isReadOnly: _autoCalculateCalories),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.autoMacros, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: _autoCalculateCalories,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() => _autoCalculateCalories = value);
                        if (value) _applyAutoCalories();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.mainNutrients,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('protein', l10n.protein, l10n.grams),
              ('carbs', l10n.carbs, l10n.grams),
              ('fat', l10n.fat, l10n.grams)
            ]),
            const SizedBox(height: 14),
            Text(l10n.nutritionDetails,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('sugar', l10n.sugarSub, l10n.grams),
              ('fiber', l10n.fiberSub, l10n.grams)
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('saturated_fat', l10n.saturatedFatSub, l10n.grams),
              ('polyunsaturated_fat', l10n.polyunsaturatedFatSub, l10n.grams)
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('monounsaturated_fat', l10n.monounsaturatedFatSub, l10n.grams),
              ('trans_fat', l10n.transFatSub, l10n.grams)
            ]),
            const SizedBox(height: 8),
            _nutrientRow([('cholesterol', l10n.cholesterolSub, l10n.mg)]),
            const SizedBox(height: 14),
            Text(l10n.minerals,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('sodium', l10n.sodium, l10n.mg),
              ('potassium', l10n.potassium, l10n.mg)
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('calcium', l10n.calcium, l10n.mg),
              ('iron', l10n.iron, l10n.mg)
            ]),
            const SizedBox(height: 14),
            Text(l10n.vitamins,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_a', l10n.vitaminA, l10n.mcg),
              ('vitamin_c', l10n.vitaminC, l10n.mg),
              ('vitamin_d', l10n.vitaminD, l10n.mcg)
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAiClarificationCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.cardRadius,
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Symbols.auto_awesome,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.aiClarificationTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.aiClarificationDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: TextField(
                controller: _clarificationController,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  labelText: l10n.aiClarificationLabel,
                  hintText: l10n.aiClarificationHint,
                  alignLabelWithHint: true,
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.72),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.ingredients,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: l10n.addIngredient,
                  onPressed: _addIngredientRow,
                  icon: const Icon(Symbols.add_circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_ingredientItems.length, (index) {
              final item = _ingredientItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: item.nameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: AppStyles.underlineInputDecoration(
                              label: l10n.ingredientLabel,
                            ).copyWith(
                              suffixIcon: item.isAmbiguous
                                  ? Tooltip(
                                      message: l10n.ingredientAmbiguousHint,
                                      child: Icon(
                                        Symbols.help,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                    )
                                  : null,
                              enabledBorder: item.isAmbiguous
                                  ? UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.orange.shade400,
                                          width: 1.5),
                                    )
                                  : null,
                              focusedBorder: item.isAmbiguous
                                  ? UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.orange.shade700,
                                          width: 2),
                                    )
                                  : null,
                            ),
                            minLines: 1,
                            maxLines: 2,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (item.isAmbiguous) {
                                setState(() => item.isAmbiguous = false);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: item.quantityController,
                            style: const TextStyle(fontSize: 13),
                            decoration: AppStyles.underlineInputDecoration(
                                label: l10n.quantityLabel),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*[\.,]?\d*'))
                            ],
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: item.unit.isEmpty
                                ? unitOptions.first
                                : item.unit,
                            items: unitOptions
                                .map((unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(
                                        _unitLabel(unit),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => item.unit = value);
                                _onDonateValidationInputChanged();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: l10n.unitLabel,
                              border: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: l10n.delete,
                          onPressed: () => _removeIngredientRow(index),
                          icon: const Icon(
                            Symbols.remove_circle,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            Text(
              l10n.ingredientExamples,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(List<(String, String, String)> fields,
      {bool isReadOnly = false}) {
    return Row(
      children: fields.map((field) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _nutrientTextFormField(
              field.$1,
              _nutrientControllers[field.$1]!,
              field.$2,
              field.$3,
              readOnly: isReadOnly && field.$1 == 'calories',
            ),
          ),
        );
      }).toList(),
    );
  }

  String _unitLabel(String unit) {
    switch (unit) {
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

  Widget _nutrientTextFormField(
    String nutrientKey,
    TextEditingController controller,
    String label,
    String suffix, {
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration:
          AppStyles.underlineInputDecoration(label: label, suffix: suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: nutrientKey == 'calories'
          ? [
              TextInputFormatter.withFunction((oldValue, newValue) {
                final text = newValue.text;
                if (text.isEmpty) return newValue;
                final normalized = text.replaceAll(',', '.');
                if (!RegExp(r'^\d*(?:\.\d{0,1})?$').hasMatch(normalized)) {
                  return oldValue;
                }
                return newValue;
              }),
            ]
          : [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d*')),
            ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return null;
        }
        if (double.tryParse(value.replaceAll(',', '.')) == null) {
          return l10n.enterCorrectNumber;
        }
        if (nutrientKey == 'calories') {
          final normalized = value.replaceAll(',', '.').trim();
          final dotIndex = normalized.indexOf('.');
          if (dotIndex >= 0) {
            final fraction = normalized.substring(dotIndex + 1);
            if (fraction.length > 1) {
              return l10n.enterCorrectNumber;
            }
          }
        }
        return null;
      },
    );
  }
}

String _normalizeIngredientUnit(String unit) {
  final v = unit.trim().toLowerCase();
  const mapping = {
    'г': 'g',
    'гр': 'g',
    'гр.': 'g',
    'gram': 'g',
    'grams': 'g',
    'грамм': 'g',
    'граммов': 'g',
    'мл': 'ml',
    'мл.': 'ml',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'л': 'l',
    'л.': 'l',
    'литр': 'l',
    'liter': 'l',
    'litre': 'l',
    'liters': 'l',
    'кг': 'kg',
    'кг.': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'мг': 'mg',
    'мг.': 'mg',
    'milligram': 'mg',
    'milligrams': 'mg',
    'шт': 'pcs',
    'шт.': 'pcs',
    'штук': 'pcs',
    'штука': 'pcs',
    'piece': 'pcs',
    'pieces': 'pcs',
    'pc': 'pcs',
    'упак': 'pack',
    'упаковка': 'pack',
    'пак': 'pack',
    'package': 'pack',
    'packages': 'pack',
    'пкг': 'pkg',
    'pkg.': 'pkg',
    'ч.л.': 'tsp',
    'ч.л': 'tsp',
    'чл': 'tsp',
    'teaspoon': 'tsp',
    'teaspoons': 'tsp',
    'ч л': 'tsp',
    'ст.л.': 'tbsp',
    'ст.л': 'tbsp',
    'стл': 'tbsp',
    'tablespoon': 'tbsp',
    'tablespoons': 'tbsp',
    'ст л': 'tbsp',
    'стакан': 'cup',
    'стакана': 'cup',
    'cups': 'cup',
  };
  if (mapping.containsKey(v)) return mapping[v]!;
  const validOptions = [
    'g',
    'mg',
    'kg',
    'pcs',
    'pack',
    'pkg',
    'l',
    'ml',
    'tsp',
    'tbsp',
    'cup'
  ];
  if (validOptions.contains(v)) return v;
  return 'g';
}

class _IngredientFormItem {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  String unit;
  bool isAmbiguous;

  _IngredientFormItem({
    String name = '',
    String quantity = '',
    String unit = '',
    this.isAmbiguous = false,
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity),
        unit = _normalizeIngredientUnit(unit);

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
