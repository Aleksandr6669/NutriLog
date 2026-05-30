import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/services/cloud_data_service.dart';
import 'package:nutri_log/services/firebase_auth_service.dart';
import 'package:nutri_log/services/firebase_bootstrap_service.dart';
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
  late TextEditingController _healthAdviceController;
  IconData _selectedIcon = Symbols.restaurant;

  // Nutrient controllers
  final Map<String, TextEditingController> _nutrientControllers = {};
  final List<_IngredientFormItem> _ingredientItems = [];
  bool _autoCalculateCalories = true;
  bool _isSyncingCalories = false;
  bool _isAiError = false;
  bool _isNutritionCalculated = false;
  bool _isAiCalculating = false;
  String? _aiStatus;

  bool _isPublic = false;
  bool _isDonated = false;
  bool _isReadyProduct = false;

  // Separate states for Donate (Community) moderation
  bool _isDonateAiChecking = false;
  bool _isDonateAiApproved = false;
  String? _donateAiStatus;
  String? _donateAiFixSuggestions;

  Timer? _donateAiDebounce;
  Timer? _nutritionAiDebounce;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nutrientsActionKey = GlobalKey();
  int _aiRequestId = 0;
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
    'calcium',
    'iron',
    'vitamin_a',
    'vitamin_c',
    'vitamin_d',
    'vitamin_e',
    'vitamin_k',
    'vitamin_b1',
    'vitamin_b2',
    'vitamin_b3',
    'vitamin_b5',
    'vitamin_b6',
    'vitamin_b7',
    'vitamin_b9',
    'vitamin_b12',
    'magnesium',
    'phosphorus',
    'zinc',
    'copper',
    'manganese',
    'selenium',
    'iodine',
    'chromium',
    'molybdenum',
    'fluoride',
    'lead',
    'mercury',
    'cadmium',
    'arsenic',
    'nitrates',
    'pesticides',
  ];

  @override
  void initState() {
    super.initState();
    final sourceRecipe = widget.recipe ?? widget.initialDraft;

    _nameController = TextEditingController(text: sourceRecipe?.name ?? '');
    _descriptionController =
        TextEditingController(text: sourceRecipe?.description ?? '');
    _clarificationController = TextEditingController(
        text: widget.initialClarification ?? sourceRecipe?.clarification ?? '');
    _healthAdviceController = TextEditingController(
        text: (widget.initialDraft?.healthAdvice ??
                sourceRecipe?.healthAdvice ??
                '')
            .trim());
    _selectedIcon = sourceRecipe?.icon ?? Symbols.restaurant;
    _isPublic = sourceRecipe?.isPublic ?? false;
    _isDonated = sourceRecipe?.isDonated ?? false;
    _isReadyProduct = sourceRecipe?.isReadyProduct ?? false;

    _nameController.addListener(_onDonateValidationInputChanged);
    _descriptionController.addListener(_onDonateValidationInputChanged);
    _clarificationController.addListener(_onDonateValidationInputChanged);
    _healthAdviceController.addListener(_onDonateValidationInputChanged);

    // Если initialDraft (создание по фото/описанию) — нутриенты заполняются данными от AI
    final isFromDraft = widget.initialDraft != null;
    final isNewRecipe = widget.recipe == null;

    // Считаем рассчитанным, если это существующий рецепт или черновик с нутриентами
    _isNutritionCalculated = !isNewRecipe || isFromDraft;

    for (var key in _nutrientKeys) {
      final initialValue = sourceRecipe?.nutrients[key]?.toString() ?? '0.0';
      final controller = TextEditingController(text: initialValue);
      controller.addListener(_onNutrientChanged);
      _nutrientControllers[key] = controller;
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onDonateValidationInputChanged();
    });
  }

  void _attachIngredientListeners(_IngredientFormItem item) {
    item.nameController.addListener(_onIngredientChanged);
    item.quantityController.addListener(_onIngredientChanged);
  }

  void _onIngredientChanged() {
    _resetModeration(resetCalculated: true);
  }

  void _onNutrientChanged() {
    if (!_isNutritionCalculated) {
      setState(() {
        _isNutritionCalculated = true;
      });
    }
    _resetModeration(resetCalculated: false);
  }

  void _resetModeration({bool resetCalculated = true}) {
    if (_isDonateAiApproved ||
        _isPublic ||
        (resetCalculated && _isNutritionCalculated)) {
      if (mounted) {
        setState(() {
          _isDonateAiApproved = false;
          _isPublic = false;
          _donateAiStatus = null;
          if (resetCalculated) {
            _isNutritionCalculated = false;
          }
        });
      }
    }
  }

  Future<void> _applyInitialAutomation({required bool isFromDraft}) async {
    if (_autoCalculateCalories) {
      _applyAutoCalories();
    }
  }

  void _detachIngredientListeners(_IngredientFormItem item) {
    item.nameController.removeListener(_onDonateValidationInputChanged);
    item.quantityController.removeListener(_onDonateValidationInputChanged);
  }

  void _onDonateValidationInputChanged() {
    if (_isDonated) return;

    setState(() {
      // If we change input, current AI status becomes stale if it was previously set
      if (_donateAiStatus != null &&
          _donateAiStatus != l10n.moderationNotChecked) {
        _isDonateAiApproved = false;
        _donateAiStatus = l10n.moderationStale;
        _donateAiFixSuggestions = null;
      }
    });
  }



  Future<void> _runDonateModeration() async {
    if (!_isFormReadyForDonate || _isDonated) return;

    final profile = context.read<ProfileProvider>().profile;
    if (profile == null || !profile.isAiFeatureAvailable) {
      setState(() {
        _isDonateAiChecking = false;
        _donateAiStatus = l10n.featureNotAvailableInFree;
        _isDonateAiApproved = false;
      });
      return;
    }

    final requestId = ++_donateAiRequestId;
    setState(() {
      _isDonateAiChecking = true;
      _donateAiStatus = l10n.moderationChecking;
      _donateAiFixSuggestions = null;
    });

    try {
      final result =
          await _geminiRecipeService.validateRecipeForCommunityDonation(
        recipeName: _nameController.text,
        recipeDescription: _descriptionController.text,
        clarification: _clarificationController.text,
        ingredients: _ingredientItems
            .map((item) => RecipeIngredient(
                  name: item.nameController.text.trim(),
                  quantity: _parseAmount(item.quantityController.text),
                  unit: item.unit.trim(),
                ))
            .where((i) => i.name.isNotEmpty)
            .toList(),
        locale: Localizations.localeOf(context).languageCode,
        isReadyProduct: _isReadyProduct,
      );

      if (!mounted || requestId != _donateAiRequestId) return;

      setState(() {
        _isDonateAiChecking = false;
        _isDonateAiApproved = result.approved;
        _donateAiStatus = result.reason;
        _donateAiFixSuggestions = result.fixSuggestions;
        if (result.healthAdvice.isNotEmpty &&
            _healthAdviceController.text.trim().isEmpty) {
          _healthAdviceController.text = result.healthAdvice;
        }
      });
    } catch (e) {
      if (!mounted || requestId != _donateAiRequestId) return;
      setState(() {
        _isDonateAiChecking = false;
        _donateAiStatus = e.toString();
      });
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

  String _nutrientLabel(String key) {
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

  String _getUnitForKey(String key) {
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

  Map<String, double> _collectCurrentNutrients() {
    final nutrients = <String, double>{};
    for (final key in _nutrientKeys) {
      nutrients[key] = _parseAmount(_nutrientControllers[key]?.text ?? '0');
    }
    return nutrients;
  }

  static const List<String> _blockedWords = [
    'говно',
    'дерьм',
    'какаш',
    'ссан',
    'моча',
    'блев',
    'shit',
    'poop',
    'piss',
    'vomit',
    'semen',
    'cum',
    'feces',
  ];

  String? _findBlockedWord(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return null;
    for (final word in _blockedWords) {
      if (word.isNotEmpty && normalized.contains(word)) {
        return word;
      }
    }
    return null;
  }

  String? _blockedWordErrorInAllInputs() {
    String? checkField(String fieldLabel, String value) {
      final blockedWord = _findBlockedWord(value);
      if (blockedWord == null) return null;
      return _localizeInline(
        ru: 'Недопустимое слово в поле "$fieldLabel".',
        en: 'Inappropriate word found in "$fieldLabel".',
        uk: 'Недопустиме слово у полі "$fieldLabel".',
      );
    }

    final directFields = <(String, String)>[
      (l10n.recipeNameLabel, _nameController.text),
      (l10n.recipeDescriptionLabel, _descriptionController.text),
      (l10n.aiClarificationLabel, _clarificationController.text),
    ];

    for (final field in directFields) {
      final issue = checkField(field.$1, field.$2);
      if (issue != null) return issue;
    }

    for (var i = 0; i < _ingredientItems.length; i++) {
      final item = _ingredientItems[i];
      final indexHuman = i + 1;
      final ingredientNameLabel = _localizeInline(
          ru: 'Ингредиент $indexHuman',
          en: 'Ingredient $indexHuman',
          uk: 'Інгредієнт $indexHuman');
      final ingredientQtyLabel = _localizeInline(
          ru: 'Количество $indexHuman',
          en: 'Amount $indexHuman',
          uk: 'Кількість $indexHuman');
      final ingredientUnitLabel = _localizeInline(
          ru: 'Единица $indexHuman',
          en: 'Unit $indexHuman',
          uk: 'Одиниця $indexHuman');

      final issueName =
          checkField(ingredientNameLabel, item.nameController.text);
      if (issueName != null) return issueName;
      final issueQty =
          checkField(ingredientQtyLabel, item.quantityController.text);
      if (issueQty != null) return issueQty;
      final issueUnit = checkField(ingredientUnitLabel, item.unit);
      if (issueUnit != null) return issueUnit;
    }

    for (final key in _nutrientKeys) {
      final value = _nutrientControllers[key]?.text ?? '';
      final issue = checkField(_nutrientLabel(key), value);
      if (issue != null) return issue;
    }

    return null;
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

    final profile = context.read<ProfileProvider>().profile;
    if (profile == null || !profile.isAiFeatureAvailable) {
      if (mounted) {
        setState(() {
          _aiStatus = l10n.featureNotAvailableInFree;
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
      final profile = context.read<ProfileProvider>().profile;
      final result = await _geminiRecipeService.estimateNutrients(
        recipeName: _nameController.text,
        recipeDescription: _descriptionController.text,
        clarification: _clarificationController.text,
        ingredients: ingredients,
        locale: Localizations.localeOf(context).languageCode,
        healthConditions: '',
        profile: profile,
        aiContext: profile?.aiContext ?? '',
      );

      if (!mounted || requestId != _aiRequestId) return;

      _isSyncingCalories = true;
      for (final key in _nutrientKeys) {
        _nutrientControllers[key]?.text =
            _formatNumber(result.nutrients[key] ?? 0);
      }
      _isSyncingCalories = false;

      setState(() {
        if (result.healthAdvice.isNotEmpty &&
            _healthAdviceController.text.trim().isEmpty) {
          _healthAdviceController.text = result.healthAdvice;
        }
        _isAiCalculating = false;
        _aiStatus = l10n.recipeAiUpdated;
        _isAiError = false;
        _isNutritionCalculated = true;
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

  void _cancelAiNutritionCalculation() {
    if (!_isAiCalculating) return;
    final languageCode = Localizations.localeOf(context).languageCode;
    final canceledMessage = languageCode == 'uk'
        ? 'Розрахунок харчової цінності зупинено.'
        : (languageCode == 'en'
            ? 'Nutrition calculation stopped.'
            : 'Расчет пищевой ценности остановлен.');

    setState(() {
      _aiRequestId++;
      _isAiCalculating = false;
      _isAiError = true;
      _aiStatus = canceledMessage;
    });
  }

  @override
  void dispose() {
    _donateAiDebounce?.cancel();
    _nutritionAiDebounce?.cancel();
    _nutrientControllers['protein']?.removeListener(_onMacroChanged);
    _nutrientControllers['carbs']?.removeListener(_onMacroChanged);
    _nutrientControllers['fat']?.removeListener(_onMacroChanged);
    _nutrientControllers['calories']
        ?.removeListener(_onDonateValidationInputChanged);
    _nameController.removeListener(_onDonateValidationInputChanged);
    _descriptionController.removeListener(_onDonateValidationInputChanged);
    _clarificationController.removeListener(_onDonateValidationInputChanged);
    _healthAdviceController.removeListener(_onDonateValidationInputChanged);
    _nameController.dispose();
    _clarificationController.dispose();
    _descriptionController.dispose();
    _healthAdviceController.dispose();
    for (var controller in _nutrientControllers.values) {
      controller.dispose();
    }
    for (final ingredientItem in _ingredientItems) {
      _detachIngredientListeners(ingredientItem);
      ingredientItem.dispose();
    }
    super.dispose();
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

    final currentNutrients = _collectCurrentNutrients();
    final hasBaseNutrients = (currentNutrients['calories'] ?? 0) > 0 ||
        (currentNutrients['protein'] ?? 0) > 0 ||
        (currentNutrients['carbs'] ?? 0) > 0 ||
        (currentNutrients['fat'] ?? 0) > 0;

    if (!hasBaseNutrients) {
      setState(() {
        _aiStatus = l10n.recipeAiCalculateRequired;
        _isAiError = true;
      });
      _scrollToNutrientsAction();
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_isPublic) {
        final sanityError = _blockedWordErrorInAllInputs();
        if (sanityError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(sanityError),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return;
        }
      }

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
        clarification: _clarificationController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isUserRecipe: true,
        isPublic: _isPublic,
        ingredients: ingredients,
        healthAdvice: _healthAdviceController.text.trim(),
        instructions: _isReadyProduct
            ? const []
            : ((widget.recipe ?? widget.initialDraft)?.instructions ?? []),
        isReadyProduct: _isReadyProduct,
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

  void _scrollToNutrientsAction() {
    if (_nutrientsActionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _nutrientsActionKey.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _deleteRecipe() async {
    if (widget.recipe == null) return;
    await _recipeService.deleteRecipe(widget.recipe!.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  bool get _hasAnyIngredient {
    return _ingredientItems
        .any((item) => item.nameController.text.trim().isNotEmpty);
  }

  void _addIngredientRow() {
    setState(() {
      final item = _IngredientFormItem();
      _attachIngredientListeners(item);
      _ingredientItems.add(item);
    });
    _resetModeration(resetCalculated: true);
  }

  void _removeIngredientRow(int index) {
    final item = _ingredientItems.removeAt(index);
    _detachIngredientListeners(item);
    item.dispose();
    setState(() {});
    _resetModeration(resetCalculated: true);
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
                    setState(() {
                      _selectedIcon = icon;
                    });
                    Navigator.pop(context);
                    _resetModeration(resetCalculated: false);
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

  bool get _isFormReadyForDonate {
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasIngredients = _ingredientItems
        .any((item) => item.nameController.text.trim().isNotEmpty);
    return hasName && hasIngredients;
  }

  void _navigateToSubscription(SubscriptionTier tier) {
    context.push('/subscription', extra: tier);
  }

  Future<void> _donateRecipe() async {
    final cloudService = CloudDataService.instance;
    await FirebaseBootstrapService.ensureInitialized();
    if (!mounted) return;
    if (FirebaseAuthService.instance.currentUser == null ||
        !cloudService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.donateRecipeSignInRequired),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isDonateAiChecking = true);
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
        clarification: _clarificationController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isPublic: _isPublic,
        isDonated: _isDonated,
        ingredients: ingredients,
        instructions:
            _isReadyProduct ? const [] : (widget.recipe?.instructions ?? []),
        isReadyProduct: _isReadyProduct,
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
      // Сразу отражаем в UI локально, а публикацию в облако отправляем параллельно.
      await _recipeService.updateRecipe(donationRecipe);
      unawaited(_publishDonationInBackground(cloudService, donationRecipe));

      if (!mounted) return;
      context.go('/recipes');
    } on StateError {
      if (!mounted) return;
      setState(() => _isDonateAiChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.donateRecipeSignInRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isDonateAiChecking = false);
      final message = e.code == 'permission-denied'
          ? l10n.donateRecipePermissionDenied
          : l10n.donateRecipeError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDonateAiChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.donateRecipeError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _publishDonationInBackground(
    CloudDataService cloudService,
    Recipe donationRecipe,
  ) async {
    try {
      await cloudService.donateRecipe(donationRecipe.toJson());
    } catch (_) {
      // Локальная пометка уже обновлена мгновенно; облако дожмется следующей синхронизацией.
    }
  }

  Widget _buildDonateCard() {
    final theme = Theme.of(context);
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.donateRecipeButton,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.donateRecipeCardDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (!_isDonated || _donateAiStatus != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _isDonateAiApproved
                      ? Colors.green.withValues(alpha: 0.1)
                      : (_isDonateAiChecking
                          ? Colors.blue.withValues(alpha: 0.05)
                          : (_isDonateAiApproved == false &&
                                  _donateAiStatus != null &&
                                  _donateAiStatus !=
                                      l10n.moderationNotChecked &&
                                  _donateAiStatus != l10n.moderationStale
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.blue.withValues(alpha: 0.05))),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isDonateAiApproved
                        ? Colors.green.withValues(alpha: 0.3)
                        : (_isDonateAiChecking
                            ? Colors.blue.withValues(alpha: 0.15)
                            : (_isDonateAiApproved == false &&
                                    _donateAiStatus != null &&
                                    _donateAiStatus !=
                                        l10n.moderationNotChecked &&
                                    _donateAiStatus != l10n.moderationStale
                                ? Colors.red.withValues(alpha: 0.25)
                                : Colors.blue.withValues(alpha: 0.15))),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isDonateAiApproved
                          ? Symbols.verified
                          : (_isDonateAiChecking ? Symbols.sync : Symbols.info),
                      size: 14,
                      color: _isDonateAiApproved
                          ? Colors.green
                          : (_isDonateAiChecking
                              ? Colors.blue
                              : (_isDonateAiApproved == false &&
                                      _donateAiStatus != null &&
                                      _donateAiStatus !=
                                          l10n.moderationNotChecked &&
                                      _donateAiStatus != l10n.moderationStale
                                  ? Colors.red
                                  : Colors.blue)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _isDonateAiChecking
                            ? l10n.moderationChecking
                            : (_donateAiStatus ?? l10n.moderationNotChecked),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: _isDonateAiApproved
                              ? Colors.green.shade800
                              : (_isDonateAiChecking
                                  ? Colors.blue.shade800
                                  : null),
                          fontWeight:
                              (_isDonateAiApproved || _isDonateAiChecking)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_donateAiFixSuggestions != null &&
                  _donateAiFixSuggestions!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.aiClarificationLabel}: $_donateAiFixSuggestions',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 10, color: Colors.orange.shade800),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (!_isDonated) ...[
              OutlinedButton.icon(
                onPressed: _isDonateAiApproved
                    ? null
                    : () {
                        final profile = context.read<ProfileProvider>().profile;
                        final isAiAvailable =
                            profile?.isAiFeatureAvailable ?? false;

                        if (!isAiAvailable) {
                          _navigateToSubscription(SubscriptionTier.standard);
                          return;
                        }
                        if (_isFormReadyForDonate && !_isDonateAiChecking) {
                          _runDonateModeration();
                        }
                      },
                icon: _isDonateAiChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _isDonateAiApproved
                            ? Symbols.verified
                            : ((context
                                        .read<ProfileProvider>()
                                        .profile
                                        ?.isAiFeatureAvailable ??
                                    false)
                                ? Symbols.verified
                                : Symbols.lock),
                        size: 18),
                label: Text(
                    _isDonateAiApproved ? l10n.ready : l10n.checkRecipeButton),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_isFormReadyForDonate && _isDonateAiApproved)
                    ? () {
                        final profile = context.read<ProfileProvider>().profile;
                        if (profile?.tier == SubscriptionTier.free) {
                          _navigateToSubscription(SubscriptionTier.standard);
                          return;
                        }
                        _donateRecipe();
                      }
                    : null,
                icon: const Icon(Symbols.volunteer_activism, size: 18),
                label: Text(l10n.donateRecipeButton),
                style: FilledButton.styleFrom(
                  backgroundColor: _isDonateAiApproved
                      ? Colors.deepOrange
                      : Colors.grey.shade400,
                ),
              ),
            ],
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
            icon: _isAiCalculating
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        Icon(Symbols.close, weight: 700, size: 18),
                      ],
                    ),
                  )
                : const Icon(Symbols.save, weight: 600),
            onPressed: _isAiCalculating
                ? _cancelAiNutritionCalculation
                : (_isDonated ? null : _saveRecipe),
            tooltip: _isAiCalculating ? l10n.cancel : l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              padding: glassBodyPadding(
                context,
                left: 16,
                top: 8,
                right: 16,
                bottom: 110,
              ),
              child: AbsorbPointer(
                absorbing: _isAiCalculating,
                child: Column(
                  children: [
                    _buildMainInfoCard(),
                    const SizedBox(height: 16),
                    const SizedBox(height: 20),
                    _buildIngredientsCard(),
                    const SizedBox(height: 20),
                    _buildNutrientsCard(),
                    const SizedBox(height: 24),
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
                            foregroundColor:
                                _isDonated ? Colors.grey : Colors.red,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_isAiCalculating)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
          ],
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
            Text(
              l10n.dishType,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(l10n.recipeLabel),
                    icon: const Icon(Symbols.menu_book),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(l10n.readyProductLabel),
                    icon: const Icon(Symbols.box),
                  ),
                ],
                selected: <bool>{_isReadyProduct},
                onSelectionChanged: (Set<bool> newSelection) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isReadyProduct = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.16),
                  selectedForegroundColor: AppColors.primary,
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _clarificationController,
              minLines: 2,
              maxLines: 5,
              decoration: AppStyles.underlineInputDecoration(
                label: l10n.aiClarificationLabel,
              ).copyWith(
                hintText: l10n.aiClarificationHint,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard() {
    final theme = Theme.of(context);
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
              ('sodium', _nutrientLabel('sodium'), _getUnitForKey('sodium')),
              ('potassium', _nutrientLabel('potassium'), _getUnitForKey('potassium'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('calcium', _nutrientLabel('calcium'), _getUnitForKey('calcium')),
              ('iron', _nutrientLabel('iron'), _getUnitForKey('iron'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('magnesium', _nutrientLabel('magnesium'), _getUnitForKey('magnesium')),
              ('phosphorus', _nutrientLabel('phosphorus'), _getUnitForKey('phosphorus'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('zinc', _nutrientLabel('zinc'), _getUnitForKey('zinc')),
              ('copper', _nutrientLabel('copper'), _getUnitForKey('copper'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('manganese', _nutrientLabel('manganese'), _getUnitForKey('manganese')),
              ('selenium', _nutrientLabel('selenium'), _getUnitForKey('selenium'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('iodine', _nutrientLabel('iodine'), _getUnitForKey('iodine')),
              ('chromium', _nutrientLabel('chromium'), _getUnitForKey('chromium'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('molybdenum', _nutrientLabel('molybdenum'), _getUnitForKey('molybdenum')),
              ('fluoride', _nutrientLabel('fluoride'), _getUnitForKey('fluoride'))
            ]),
            const SizedBox(height: 14),
            Text(l10n.vitamins,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_a', _nutrientLabel('vitamin_a'), _getUnitForKey('vitamin_a')),
              ('vitamin_c', _nutrientLabel('vitamin_c'), _getUnitForKey('vitamin_c')),
              ('vitamin_d', _nutrientLabel('vitamin_d'), _getUnitForKey('vitamin_d'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_e', _nutrientLabel('vitamin_e'), _getUnitForKey('vitamin_e')),
              ('vitamin_k', _nutrientLabel('vitamin_k'), _getUnitForKey('vitamin_k'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_b1', _nutrientLabel('vitamin_b1'), _getUnitForKey('vitamin_b1')),
              ('vitamin_b2', _nutrientLabel('vitamin_b2'), _getUnitForKey('vitamin_b2')),
              ('vitamin_b3', _nutrientLabel('vitamin_b3'), _getUnitForKey('vitamin_b3'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_b5', _nutrientLabel('vitamin_b5'), _getUnitForKey('vitamin_b5')),
              ('vitamin_b6', _nutrientLabel('vitamin_b6'), _getUnitForKey('vitamin_b6')),
              ('vitamin_b7', _nutrientLabel('vitamin_b7'), _getUnitForKey('vitamin_b7'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_b9', _nutrientLabel('vitamin_b9'), _getUnitForKey('vitamin_b9')),
              ('vitamin_b12', _nutrientLabel('vitamin_b12'), _getUnitForKey('vitamin_b12'))
            ]),
            const SizedBox(height: 14),
            Text(
              l10n.heavyMetalsAndContaminants,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _nutrientRow([
              ('lead', _nutrientLabel('lead'), _getUnitForKey('lead')),
              ('mercury', _nutrientLabel('mercury'), _getUnitForKey('mercury'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('cadmium', _nutrientLabel('cadmium'), _getUnitForKey('cadmium')),
              ('arsenic', _nutrientLabel('arsenic'), _getUnitForKey('arsenic'))
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('nitrates', _nutrientLabel('nitrates'), _getUnitForKey('nitrates')),
              ('pesticides', _nutrientLabel('pesticides'), _getUnitForKey('pesticides'))
            ]),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                key: _nutrientsActionKey,
                children: [
                  Builder(builder: (context) {
                    final profile = context.watch<ProfileProvider>().profile;
                    final isAiAvailable =
                        profile?.isAiFeatureAvailable ?? false;

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (!_hasAnyIngredient || _isAiCalculating)
                            ? null
                            : (!isAiAvailable)
                                ? () => _navigateToSubscription(
                                    SubscriptionTier.standard)
                                : _recalculateNutrientsWithAi,
                        icon: _isAiCalculating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(
                                (!isAiAvailable && _hasAnyIngredient)
                                    ? Symbols.lock
                                    : Symbols.calculate,
                                weight: 600),
                        label: Text(l10n.calculateNutrition),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!isAiAvailable && _hasAnyIngredient)
                              ? Colors.grey.withValues(alpha: 0.08)
                              : AppColors.primary.withValues(alpha: 0.08),
                          foregroundColor: (!isAiAvailable && _hasAnyIngredient)
                              ? Colors.grey.shade600
                              : AppColors.primary,
                          elevation: 0,
                          side: BorderSide(
                            color: (!isAiAvailable && _hasAnyIngredient)
                                ? Colors.grey.withValues(alpha: 0.25)
                                : AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_aiStatus != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (_isAiError ? Colors.red : AppColors.primary)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_isAiError ? Colors.red : AppColors.primary)
                              .withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAiError ? Symbols.error : Symbols.info,
                            size: 16,
                            color: _isAiError
                                ? Colors.red.shade700
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiStatus!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _isAiError
                                    ? Colors.red.shade700
                                    : theme.textTheme.bodySmall?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
