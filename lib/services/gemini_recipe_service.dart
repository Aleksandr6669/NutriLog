import 'usda_food_data_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'recipe_loader.dart';
import 'dart:ui' as ui;

class GeminiRecipeService {
  static const int _usdaFactsCacheMaxEntries = 300;
  static final Map<String, Map<String, double>> _usdaFactsCache = {};
  static final Map<String, Future<Map<String, double>?>> _usdaFactsInFlight =
      {};

  /// Get a nutrient value by key from nutrMap (with synonym support)
  double _usdaNutrientValue(String key, Map<String, double> nutrMap) {
    // Synonym map for nutrient keys
    const synonyms = {
      'calories': [
        'energy',
        'energy, kcal',
        'energy, kilocalories',
      ],
      'protein': ['protein', 'proteins'],
      'carbs': [
        'carbohydrate, by difference',
        'carbohydrates',
        'carb',
        'carbohydrate'
      ],
      'fat': ['total lipid (fat)', 'fat', 'total fat'],
      'fiber': ['fiber, total dietary', 'fiber', 'dietary fiber'],
      'sugar': ['sugars, total including nlea', 'sugar', 'sugars'],
      'saturated_fat': [
        'fatty acids, total saturated',
        'saturated fat',
      ],
      'polyunsaturated_fat': [
        'fatty acids, total polyunsaturated',
        'polyunsaturated fat',
      ],
      'monounsaturated_fat': [
        'fatty acids, total monounsaturated',
        'monounsaturated fat',
      ],
      'trans_fat': ['fatty acids, total trans', 'trans fat'],
      'cholesterol': ['cholesterol'],
      'sodium': ['sodium, na', 'sodium'],
      'potassium': ['potassium, k', 'potassium'],
      'vitamin_a': ['vitamin a, iu', 'vitamin a', 'retinol'],
      'vitamin_c': [
        'vitamin c, total ascorbic acid',
        'vitamin c',
        'ascorbic acid',
      ],
      'vitamin_d': [
        'vitamin d (d2 + d3)',
        'vitamin d',
        'calciferol',
      ],
      'calcium': ['calcium, ca', 'calcium'],
      'iron': ['iron, fe', 'iron'],
    };
    final candidates = [key, ...?synonyms[key]];
    for (final k in candidates) {
      if (nutrMap.containsKey(k)) {
        final v = nutrMap[k];
        if (v != null && v.isFinite && v >= 0) return v;
      }
    }
    // Try partial match
    for (final entry in nutrMap.entries) {
      for (final k in candidates) {
        if (entry.key.toLowerCase().contains(k.toLowerCase()) &&
            entry.value.isFinite &&
            entry.value >= 0) {
          return entry.value;
        }
      }
    }
    return 0.0;
  }

  /// Стабильная JSON-модель для большинства операций.
  static const String _stableJsonModel = 'llama-3.3-70b-versatile';

  /// Стабильная vision-модель для задач с фото.
  static const String _stablePhotoJsonModel =
      'meta-llama/llama-4-scout-17b-16e-instruct';

  /// Базовый набор по умолчанию (одна модель = один запрос без лишнего фолбэка).
  static const List<String> _models = [_stableJsonModel];

  /// Операционные наборы моделей.
  static const List<String> _draftModels = [_stableJsonModel];
  static const List<String> _nutritionModels = [_stableJsonModel];
  static const List<String> _statsModels = [_stableJsonModel];
  static const List<String> _dailyGoalsModels = [_stableJsonModel];
  static const List<String> _activityModels = [_stableJsonModel];
  static const List<String> _translationModels = ['llama-3.1-8b-instant'];

  /// Модели с поддержкой изображений.
  /// Фото никогда не должно уходить в текстовую модель.
  static const List<String> _photoModels = [_stablePhotoJsonModel];

  /// Быстрые модели — для recheck (самопроверки результата).
  static const List<String> _recheckModels = ['llama-3.1-8b-instant'];

  /// Специализированные модели для модерации рецептов.
  static const List<String> _moderationModels = ['llama-3.1-8b-instant'];

  /// Router models are used only to choose model order (speed vs accuracy).
  /// If router fails, the regular deterministic fallback chain is used.
  static const List<String> _routerModels = [
    'llama-3.1-8b-instant',
    'llama-3.3-70b-versatile',
    'meta-llama/llama-4-scout-17b-16e-instruct',
  ];

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _routerRequestTimeout = Duration(seconds: 4);
  static const int _jsonRetryMaxAttempts = 2;
  static const int _recheckRetryMaxAttempts = 1;
  static const int _moderationRetryMaxAttempts = 1;
  static const Duration _jsonRetryDelay = Duration(seconds: 2);
  static const Duration _routerHistoryRetention = Duration(days: 30);
  static const Duration _routerErrorBypassWindow = Duration(hours: 6);
  static const int _routerErrorBypassThreshold = 5;
  static const int _routerHistoryMaxEntries = 240;
  static const String _routerHistoryPrefsKey = 'ai.router.history.v1';
  static const String _routerFailCountPrefsKey = 'ai.router.fail.count.v1';
  static const String _routerLastFailAtPrefsKey = 'ai.router.fail.last_at.v1';
  static const String _routerLastCleanupAtPrefsKey =
      'ai.router.history.last_cleanup_at.v1';
  static const String _groqTokenIndexPrefsKey = 'ai.groq.token.index.v1';
  static const List<String> _groqTokens = [
    String.fromEnvironment('GROQ_API_KEY_1'),
    String.fromEnvironment('GROQ_API_KEY_2'),
    String.fromEnvironment('GROQ_API_KEY_3'),
    String.fromEnvironment('GROQ_API_KEY_4'),
    String.fromEnvironment('GROQ_API_KEY_5'),
  ];

  static const List<String> nutrientKeys = [
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
    'iron',
  ];

  static const List<String> _allowedIconNames = [
    'restaurant',
    'lunch_dining',
    'local_bar',
    'cake',
    'fastfood',
    'breakfast_dining',
    'ramen_dining',
    'icecream',
    'local_pizza',
    'set_meal',
    'dinner_dining',
    'blender',
    'soup_kitchen',
    'coffee',
    'wine_bar',
    'liquor',
    'bakery_dining',
    'egg',
    'egg_alt',
    'cooking',
    'kebab_dining',
    'takeout_dining',
    'rice_bowl',
    'cookie',
    'donut_large',
    'local_cafe',
    'local_drink',
    'tapas',
    'flatware',
    'outdoor_grill',
    'kitchen',
    'microwave',
    'skillet',
    'nutrition',
    'eco',
    'restaurant_menu',
  ];

  String _languageCode([String? locale]) {
    final raw = locale?.toLowerCase() ??
        ui.PlatformDispatcher.instance.locale.toString().toLowerCase();
    final code = raw.split(RegExp(r'[-_]')).first;
    if (code == 'ru' || code == 'uk') return code;
    return 'en';
  }

  AppLocalizations _messages(String? locale) {
    final code = _languageCode(locale);
    try {
      return lookupAppLocalizations(Locale(code));
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  String _languageInstruction([String? locale]) {
    switch (_languageCode(locale)) {
      case 'ru':
        return 'Response language: Russian.';
      case 'uk':
        return 'Response language: Ukrainian.';
      default:
        return 'Response language: English.';
    }
  }

  Future<GeminiRecipeDraft> generateRecipeFromDescription({
    required String description,
    String? locale,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).recipeCreateFromDescriptionEmptyError,
      );
    }

    final prompt = '''
You are a culinary assistant.
${_languageInstruction(locale)}
Generate a recipe draft based on the user's description.

Dish description:
$normalizedDescription

Reply ONLY in JSON format, without explanations, markdown, or any text before or after the JSON. If unable — return empty JSON: {}.

Format:
{
  "name": "...",
  "description": "...",
  "clarification": "...",
  "icon": "restaurant",
  "ingredients": [
    {"name": "...", "quantity": 100, "unit": "g", "ambiguous": false}
  ],
  "nutrients": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "saturated_fat": 0,
    "polyunsaturated_fat": 0,
    "monounsaturated_fat": 0,
    "trans_fat": 0,
    "cholesterol": 0,
    "sodium": 0,
    "potassium": 0,
    "vitamin_a": 0,
    "vitamin_c": 0,
    "vitamin_d": 0,
    "calcium": 0,
    "iron": 0
  }
}

Rules:
- icon must be chosen only from this list: ${_allowedIconNames.join(', ')}.
- ingredients must contain at least 1 item.
- clarification: short direct description for "Important details" field (2-4 lines). Write directly: what it is, possible brand or name, brief composition or cooking method in 2-3 words, key characteristics. Style: direct, no third-person, no filler phrases. Example: "Энергетик. Возможный бренд: Monster. Состав: кофеин, таурин, сахар, витамины группы B."
- ingredient quantities must be realistic for ONE serving (1 person).
- If user does not explicitly specify total amount/yield/number of servings, assume exactly 1 serving for 1 person.
- quantity as a number >= 0.
- unit as a short string like: g, ml, pcs, tbsp, tsp.
- nutrients as numbers only >= 0.
- If exact data is unavailable, provide a realistic estimate.
- For each ingredient, set "ambiguous": true if the preparation method or form is unclear and significantly affects nutrition (e.g., boiled vs dry pasta, cereal with milk vs dry, raw vs cooked meat). Set "ambiguous": false otherwise.
- Do NOT add generic fillers like water/broth/oil/salt/sugar unless they are explicitly mentioned by the user or clearly required by the dish/product type.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
        'max_completion_tokens': 1024,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
      modelsOverride: _draftModels,
    );
    final textDraft = _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
    await _fixDraftNutrientsIfNeeded(textDraft, locale: locale);
    return textDraft;
  }

  Future<GeminiRecipeDraft> generateRecipeFromPhoto({
    required Uint8List imageBytes,
    required String imageMimeType,
    String description = '',
    String? locale,
  }) async {
    if (imageBytes.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).recipeAddPhotoFirstError,
      );
    }

    final normalizedDescription = description.trim();
    final textPrompt = '''
You are a culinary assistant and food expert.
${_languageInstruction(locale)}
Your task is to identify the product or dish in the photo as accurately as possible (and from the description if provided), identify all main and hidden ingredients, and determine the product type (e.g., energy drink, soda, protein bar, soup, salad, pastry, etc.).

If the photo shows a packaged product (e.g., energy drink, soda, chocolate, snacks, yogurt, protein supplement, bar, ready meal, etc.), be sure to indicate its type in the description field and identify the composition (ingredients) as thoroughly as possible, even if some are not visible but can be inferred from packaging, color, shape, brand, or product type.

If the product is an energy drink (e.g., Non Stop, Adrenaline, Red Bull, Monster, etc.), mention this in the description and list all typical components in ingredients (e.g., water, sugar, caffeine, taurine, B-vitamins, flavorings, colorants, preservatives, etc.), even if not visible in the photo but typical for such drinks.

If the product is a soda, juice, dairy product, protein bar, chocolate, snacks, pastry, fast food, etc., also identify the type and composition by analogy.

If the photo shows a home-cooked dish, identify it as precisely as possible, identify the main ingredients and estimate their quantities.

${normalizedDescription.isEmpty ? '' : 'Additional user description: $normalizedDescription'}

Reply ONLY in JSON format, without explanations, markdown, or any text before or after the JSON. If unable — return empty JSON: {}.

Format:
{
  "name": "...", // product or dish name
  "description": "...", // brief description, be sure to indicate type (e.g., energy drink, soda, protein bar, soup, etc.)
  "clarification": "...", // detailed "Important details" text for nutrition accuracy
  "icon": "restaurant",
  "ingredients": [
    {"name": "...", "quantity": 100, "unit": "g", "ambiguous": false}
  ],
  "nutrients": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "saturated_fat": 0,
    "polyunsaturated_fat": 0,
    "monounsaturated_fat": 0,
    "trans_fat": 0,
    "cholesterol": 0,
    "sodium": 0,
    "potassium": 0,
    "vitamin_a": 0,
    "vitamin_c": 0,
    "vitamin_d": 0,
    "calcium": 0,
    "iron": 0
  }
}

Rules:
- icon must be chosen only from this list: ${_allowedIconNames.join(', ')}.
- ingredients must contain at least 1 item.
- clarification: short direct description for "Important details" field (2-5 lines). Write directly: what it is, visible brand if any, brief composition or cooking method, key details. Style: direct, no third-person, no filler phrases. Example: "Суп. Томатный, домашний. Ингредиенты: помидоры, лук, морковь, масло. Без сметаны."
- ingredient quantities must be realistic for ONE serving (1 person).
- If user does not explicitly specify total amount/yield/number of servings, assume exactly 1 serving for 1 person.
- quantity as a number >= 0. If needed, quantity >= 0.0001 (for spices, supplements, etc.).
- For each ingredient, set "ambiguous": true if the preparation method or form is unclear and significantly affects nutrition (e.g., boiled vs dry pasta, cereal with milk vs dry, raw vs cooked meat, fresh vs canned). Set "ambiguous": false otherwise.
   If given in pieces, estimate the weight of one piece based on reference tables or common sense (e.g., average apple ~150 g, average egg ~50 g). If given in milliliters, estimate weight based on product density (e.g., 1 ml water ~ 1 g, 1 ml oil ~ 0.9 g). If weight cannot be precisely estimated, provide a realistic estimate based on similar products.
- unit as a short string like: g, mg, kg, pcs, pack, package, l, ml, tsp, tbsp, cup.
- nutrients as numbers only >= 0. If needed, values >= 0.0001 (for micronutrients, vitamins, supplements, etc.) are allowed.
- If exact data is unavailable, provide a realistic estimate.
- If exact composition cannot be determined, estimate by analogy with typical products of this type.
- Do NOT add generic fillers like water/broth/oil/salt/sugar unless they are explicitly visible/mentioned or clearly required by the dish/product type.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': textPrompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
                }
              }
            ]
          }
        ],
        'temperature': 0.3,
        'max_completion_tokens': 1024,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
      modelsOverride: _photoModels,
    );
    final photoDraft = _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
    await _fixDraftNutrientsIfNeeded(photoDraft, locale: locale);
    return photoDraft;
  }

  Future<Map<String, double>> estimateNutrients({
    required String recipeName,
    required String recipeDescription,
    required List<RecipeIngredient> ingredients,
    String clarification = '',
    String? locale,
  }) async {
    if (ingredients.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiFailedToExtractIngredientsError,
      );
    }

    final ingredientIssue = _validateIngredientPlausibility(
      ingredients: ingredients,
      locale: locale,
    );
    if (ingredientIssue != null) {
      throw GeminiRecipeException(ingredientIssue);
    }

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiKeyMissingError,
      );
    }

    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\\n');

    // Fetch real ingredient data from USDA FoodData Central
    final usdaService = UsdaFoodDataService.fromEnv();
    // Build a JSON nutrient table for each ingredient
    final Map<String, Map<String, double>> factsJson = {};
    for (final ingredient in ingredients) {
      final facts = await _getUsdaFactsForIngredient(
        ingredientName: ingredient.name,
        locale: locale,
        usdaService: usdaService,
      );
      if (facts != null && facts.isNotEmpty) {
        factsJson[ingredient.name] = facts;
      }
    }

    final prompt = '''
  You are a professional nutritionist specializing in precise per-serving nutritional calculations.
  ${_languageInstruction(locale)}

  TASK: Calculate the exact total nutritional value for ONE SERVING (for 1 person) of the recipe described below.

  CRITICAL RULES:
  1. The ingredient list below IS the full recipe for ONE PERSON — do NOT divide quantities.
  2. The specified amounts are exactly what goes into this single serving. NEVER question or adjust the quantities — treat them as precise user input.
    2.1. USER CLARIFICATION is the PRIMARY source of truth for product type, preparation method, fat level, sauces, and hidden ingredients.
      If clarification conflicts with recipe name/description assumptions, follow clarification first.
      Use ingredients list as SECONDARY quantitative constraints (amounts/units) and for consistency checks.
  3. For packaged products (bottle, can, pack, bar, etc.): treat the quantity as the actual content.
     Examples: "1 bottle of energy drink (500 ml)" = 500 ml, "1 pack of butter (200 g)" = 200 g, "1 protein bar (60 g)" = 60 g.
    3.1. If the ingredient name/description contains explicit net amount (for example: 500 ml, 330ml, 0.5 l, 200 g, 90g), ALWAYS use that explicit value.
       Never replace an explicit label value with a "typical" package size.
  4. Use the recipe NAME and DESCRIPTION as supporting context only.
     Example: if description says "energy drink", include caffeine-related vitamins and typical energy drink composition.

  UNIT CONVERSION (to grams):
  - Milliliters: water/juice ≈ 1 g/ml, milk ≈ 1.03 g/ml, oil ≈ 0.9 g/ml, honey ≈ 1.4 g/ml
  - стакан/стак (Russian/Ukrainian glass): EXACTLY 200 ml. Do NOT use 240 ml (US cup). 1 стакан = 200 ml always.
  - cup (US): 240 ml. Use only if the unit is explicitly "cup", not "стакан".
  - tbsp/столовая ложка: 15 ml. tsp/чайная ложка: 5 ml.
  - Pieces (pcs): apple ≈ 150 g, egg ≈ 55 g, banana ≈ 120 g, orange ≈ 180 g; use common sense for others
  - Pack/package: use the typical standard weight for that product category ONLY when no explicit net weight/volume is provided in name/description

  CALCULATION STEPS:
  1. Convert all ingredient quantities to grams using the rules above.
  2. For each ingredient, look up nutrients per 100 g from USDA / FatSecret / Open Food Facts or your knowledge.
  3. Scale: nutrient_for_ingredient = weight_g × (per_100g_value / 100)
  4. Sum across ALL ingredients to get the total for the serving.
  5. Cross-check: calories ≈ (protein × 4) + (carbs × 4) + (fat × 9). Adjust if off by more than 5%.

  USDA nutritional reference data (per 100 g) for each ingredient:
  ${factsJson.isNotEmpty ? jsonEncode(factsJson) : '(not available — use your knowledge of food databases)'}

  Recipe details:
  - User clarification (PRIMARY): ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
  - Name: ${recipeName.trim().isEmpty ? 'Untitled' : recipeName.trim()}
  - Description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
  - Serving size: all ingredients below = 1 serving for 1 person
  - Ingredients (SECONDARY: quantities and consistency constraints):
  $ingredientsText

  Ingredient names may be in any language (English, Russian, Ukrainian, mixed spellings). Correctly interpret them as food products before calculation.

  Reply with ONLY a JSON object. Keys: ${nutrientKeys.join(', ')} (all numeric doubles, no units, no negatives, no nulls). Return {} only if completely unable to estimate. No markdown, no text, no explanations outside JSON.

  JSON value units:
  - calories: kcal
  - protein, carbs, fat, fiber, sugar, saturated_fat, polyunsaturated_fat, monounsaturated_fat, trans_fat: grams
  - cholesterol, sodium, potassium, calcium, iron, vitamin_c: milligrams
  - vitamin_a, vitamin_d: micrograms
  ''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.2,
        'max_completion_tokens': 1024,
        'top_p': 1,
        'stream': false,
      },
      apiKeyOverride: apiKey,
      locale: locale,
      modelsOverride: _nutritionModels,
    );

    final firstPass = <String, double>{};
    for (final key in nutrientKeys) {
      firstPass[key] = _toNonNegativeDouble(decoded[key]);
    }

    var rechecked = await _recheckEstimatedNutrientsWithAi(
      recipeName: recipeName,
      recipeDescription: recipeDescription,
      clarification: clarification,
      ingredientsText: ingredientsText,
      factsJson: factsJson,
      firstPass: firstPass,
      locale: locale,
    );

    final afterFirstRecheck = <String, double>{};
    for (final key in nutrientKeys) {
      afterFirstRecheck[key] =
          _toNonNegativeDouble(rechecked['nutrients']?[key] ?? firstPass[key]);
    }

    final finalNutrients = <String, double>{};
    for (final key in nutrientKeys) {
      finalNutrients[key] = _toNonNegativeDouble(afterFirstRecheck[key]);
    }

    var localIssueAfterRecheck = _validateEstimatedNutrients(
      nutrients: finalNutrients,
      ingredients: ingredients,
      locale: locale,
    );

    if (localIssueAfterRecheck != null) {
      // Emergency third pass if result is still invalid (all zeros / no calories)
      rechecked = await _recheckEstimatedNutrientsWithAi(
        recipeName: recipeName,
        recipeDescription: recipeDescription,
        clarification: clarification,
        ingredientsText: ingredientsText,
        factsJson: factsJson,
        firstPass: finalNutrients,
        locale: locale,
      );

      for (final key in nutrientKeys) {
        finalNutrients[key] = _toNonNegativeDouble(
          rechecked['nutrients']?[key] ?? finalNutrients[key],
        );
      }

      localIssueAfterRecheck = _validateEstimatedNutrients(
        nutrients: finalNutrients,
        ingredients: ingredients,
        locale: locale,
      );
    }

    if (localIssueAfterRecheck != null) {
      _applyNutrientsBestEffortFallback(finalNutrients);
      localIssueAfterRecheck = _validateEstimatedNutrients(
        nutrients: finalNutrients,
        ingredients: ingredients,
        locale: locale,
      );
    }

    // Only block if local structural validation failed (all zeros / calories=0)
    // aiApproved is ignored — recheck is used only to improve accuracy, not to reject
    if (localIssueAfterRecheck != null) {
      throw GeminiRecipeException(localIssueAfterRecheck);
    }

    return finalNutrients;
  }

  String? _validateEstimatedNutrients({
    required Map<String, double> nutrients,
    required List<RecipeIngredient> ingredients,
    String? locale,
  }) {
    if (ingredients.isEmpty) {
      return _messages(locale).validationNoIngredients;
    }

    final calories = nutrients['calories'] ?? 0;
    final protein = nutrients['protein'] ?? 0;
    final fat = nutrients['fat'] ?? 0;
    final carbs = nutrients['carbs'] ?? 0;

    final allZeros = nutrientKeys.every((key) => (nutrients[key] ?? 0) <= 0);
    if (allZeros) {
      return _messages(locale).validationAllZeroNutrients;
    }

    if (calories <= 0) {
      return _messages(locale).validationZeroCalories;
    }

    // Calories present but all main macros are zero — structurally invalid
    if (protein <= 0 && fat <= 0 && carbs <= 0) {
      return _messages(locale).validationAllZeroNutrients;
    }

    return null;
  }

  /// Всегда проверяет точность нутриентов в черновике через AI и корректирует,
  /// если значения явно неверны (состояние, приготовление, плотность калорий).
  Future<void> _fixDraftNutrientsIfNeeded(
    GeminiRecipeDraft draft, {
    String? locale,
  }) async {
    if (draft.ingredients.isEmpty) return;
    final n = draft.nutrients;

    try {
      final ingredientsText = draft.ingredients
          .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
          .join('\n');

      final result = await _recheckEstimatedNutrientsWithAi(
        recipeName: draft.name,
        recipeDescription: draft.description,
        clarification: draft.clarification,
        ingredientsText: ingredientsText,
        factsJson: const {},
        firstPass: Map<String, double>.from(n),
        locale: locale,
      );

      final fixed = result['nutrients'];
      if (fixed is Map<String, dynamic>) {
        for (final key in nutrientKeys) {
          final value = _toNonNegativeDouble(fixed[key]);
          if (value > 0) {
            draft.nutrients[key] = value;
          }
        }
      }
    } catch (_) {
      // Silent: draft nutrients stay as-is
    }
  }

  Future<Map<String, dynamic>> _recheckEstimatedNutrientsWithAi({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required String ingredientsText,
    required Map<String, Map<String, double>> factsJson,
    required Map<String, double> firstPass,
    String? locale,
  }) async {
    final prompt = '''
You are a nutrition calculation corrector and food state interpreter.
${_languageInstruction(locale)}

Your task is to IMPROVE the candidate nutrition values using USDA reference data as hints.
Do NOT reject or block the calculation — always return approved: true with your best corrected values.

CRITICAL: FOOD PREPARATION STATE
Before calculating, carefully determine the ACTUAL state of each ingredient using all available context:
- User clarification (HIGHEST priority): if it says "варёные макароны", "готовая каша", "сухие хлопья" — use that exact state.
- Description and name: "овсяная каша на воде" → oats are cooked, "мюсли с молоком" → dry flakes + milk.
- Default assumption when state is ambiguous: prefer COOKED/PREPARED state for pasta, rice, grains, oats, buckwheat, lentils, beans; use RAW weight for meat, fish, vegetables.
- Cooked pasta/rice/grains have ~3x LOWER calories per gram than dry (e.g. cooked pasta: ~130 kcal/100g, dry pasta: ~350 kcal/100g).
- Dry oats/flakes: ~370 kcal/100g. Cooked oatmeal: ~70 kcal/100g.
- If ingredient name contains "сухой/dry/сырой/raw" → use dry/raw values. If "варёный/cooked/готовый/prepared" → use cooked values.

UNIT CONVERSION (mandatory):
- стакан/стак (Russian/Ukrainian glass): EXACTLY 200 ml. Do NOT use 240 ml. 1 стакан = 200 ml always.
- cup (US): 240 ml. Use only if unit is explicitly "cup", not "стакан".
- tbsp/ст.л.: 15 ml. tsp/ч.л.: 5 ml.

INPUT:
- clarification (HIGHEST PRIORITY for food state): ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
- recipe name: ${recipeName.trim().isEmpty ? 'Untitled' : recipeName.trim()}
- recipe description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
- ingredients:
$ingredientsText

USDA nutritional reference data (per 100 g) — use as HINTS only, not as hard constraints:
${factsJson.isNotEmpty ? jsonEncode(factsJson) : '(not available — use your food knowledge)'}

Candidate nutrients JSON (your starting point):
${jsonEncode(firstPass)}

Instructions:
1. First, determine preparation state for each ingredient from clarification → description → name → default assumption (see rules above).
2. Use USDA data (adjusted for the correct state) as reference to spot obvious errors in nutrient density (e.g. calories per 100g off by 2x or more).
3. IMPORTANT: NEVER change or question the ingredient quantities/amounts specified by the user. Treat them as exact and correct.
4. Only adjust nutrient values if the preparation state is clearly wrong (e.g. dry vs cooked). Do NOT adjust because the quantity "seems too much or too little".
5. If candidate looks reasonable and state matches, keep candidate values unchanged.
6. Always return approved: true with your best nutrient values.
7. Cross-check: calories ≈ protein×4 + carbs×4 + fat×9. Adjust if off by more than 10%.

Return ONLY JSON:
{
  "approved": true,
  "reason": "",
  "nutrients": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "saturated_fat": 0,
    "polyunsaturated_fat": 0,
    "monounsaturated_fat": 0,
    "trans_fat": 0,
    "cholesterol": 0,
    "sodium": 0,
    "potassium": 0,
    "vitamin_a": 0,
    "vitamin_c": 0,
    "vitamin_d": 0,
    "calcium": 0,
    "iron": 0
  }
}

Rules:
- no markdown, no extra text.
- all nutrient values must be numeric and >= 0.
- keep values realistic for one serving.
''';

    try {
      final decoded = await _requestDecodedJsonWithAutoRetry(
        body: {
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.1,
          'max_completion_tokens': 600,
          'top_p': 1,
          'stream': false,
        },
        locale: locale,
        modelsOverride: _recheckModels,
        maxAttempts: _recheckRetryMaxAttempts,
      );
      final approved = decoded['approved'] == true;
      final reason = (decoded['reason'] as String? ?? '').trim();
      final decodedNutrients = decoded['nutrients'] as Map<String, dynamic>?;

      final normalized = <String, double>{};
      for (final key in nutrientKeys) {
        normalized[key] =
            _toNonNegativeDouble(decodedNutrients?[key] ?? firstPass[key]);
      }

      return {
        'approved': approved,
        'reason': reason,
        'nutrients': normalized,
      };
    } catch (_) {
      return {
        'approved': true,
        'reason': '',
        'nutrients': firstPass,
      };
    }
  }

  Future<DonateRecipeModerationResult> validateRecipeForCommunityDonation({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required List<RecipeIngredient> ingredients,
    Map<String, double>? nutrients,
    String? locale,
  }) async {
    if (recipeName.trim().isEmpty || ingredients.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiFailedToExtractIngredientsError,
      );
    }

    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\n');

    final hasNutrients = nutrients != null && nutrients.isNotEmpty;
    final nutrientsText = hasNutrients
        ? nutrientKeys
            .map((k) => '$k=${(nutrients[k] ?? 0).toStringAsFixed(2)}')
            .join(', ')
        : '(not provided)';

    final prompt = '''
You are a strict content moderation and culinary validation assistant.
${_languageInstruction(locale)}

Task: decide whether this recipe can be permanently published to a public community feed.

Reject the recipe if ANY of these is true:
- contains profanity, insults, obscene/sexual terms, hateful content, harassment;
- contains obvious nonsense, trolling, spam, gibberish, or fake recipe text;
- contains meaningless letter sequences, keyboard mashing, random characters, or unreadable fragments in the name, description, clarification, or ingredient names;
- is clearly not a food recipe.

Do NOT reject only because a product is branded/packaged/store-bought (energy drink, soda, protein bar, yogurt, etc.) if it is a plausible food item.
Do NOT reject because units, quantities, or weight values may be imprecise, unusual, missing, or inconsistent.

Allow only if recipe looks legitimate, understandable, and safe for a public food community.

Recipe data:
- name: ${recipeName.trim()}
- description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
- clarification: ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
- ingredients:
$ingredientsText
- nutrients (optional context): $nutrientsText

Return ONLY JSON:
{
  "decision": "allow|reject",
  "approved": true or false,
  "reason": "short user-facing explanation in response language",
  "confidence": 0.0,
  "flags": ["profanity|nonsense|not_recipe|unsafe|other"]
}

Rules:
- No markdown, no extra text.
- reason must be concise and understandable.
- Treat examples like "какашка", "рецепт мусора", random symbols, obvious trolling, or meaningless text like "asdasd", "qwerty", "zxcv", "ыфвфыв", "фывфыв", repeated random letters/syllables as nonsense and reject.
- If any important user-facing field looks like gibberish or has no clear semantic meaning, reject with flag "nonsense".
- If uncertain, set approved=false.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0,
        'max_completion_tokens': 160,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
      modelsOverride: _moderationModels,
      maxAttempts: _moderationRetryMaxAttempts,
    );

    final decision =
        (decoded['decision'] as String? ?? '').trim().toLowerCase();
    final approvedByDecision =
        decision == 'allow' ? true : (decision == 'reject' ? false : null);
    final approvedByBool = decoded['approved'] == true;
    final approved = approvedByDecision ?? approvedByBool;
    final reason = (decoded['reason'] as String? ?? '').trim();
    final confidence = _toNonNegativeDouble(decoded['confidence']);
    final flags = ((decoded['flags'] as List<dynamic>?) ?? const [])
        .map((f) => f.toString().trim())
        .where((f) => f.isNotEmpty)
        .toList(growable: false);

    return DonateRecipeModerationResult(
      approved: approved,
      reason: reason.isEmpty
          ? (approved
              ? _messages(locale).moderationApproved
              : _messages(locale).moderationRejected)
          : reason,
      confidence: confidence,
      flags: flags,
    );
  }

  Future<List<String>> _buildIngredientSearchQueries(
    String ingredientName,
    String? locale,
  ) async {
    final base = ingredientName.trim();
    if (base.isEmpty) return const [];

    final candidates = <String>{base};

    final simplified = base
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (simplified.isNotEmpty) {
      candidates.add(simplified);
    }

    final translated = await _translateIngredientToEnglish(base, locale);
    if (translated != null && translated.isNotEmpty) {
      candidates.add(translated);
    }

    return candidates.toList(growable: false);
  }

  Future<String?> _translateIngredientToEnglish(
    String ingredientName,
    String? locale,
  ) async {
    final source = ingredientName.trim();
    if (source.isEmpty) return null;

    try {
      final decoded = await _requestDecodedJsonWithAutoRetry(
        body: {
          'messages': [
            {
              'role': 'user',
              'content': '''
Translate the food ingredient name to concise English for USDA food search.
Return ONLY JSON:
{
  "query": "short English ingredient phrase"
}

Rules:
- query must be 1-4 words.
- no punctuation, no quotes inside value.
- no extra keys, no extra text.

Ingredient: $source
''',
            }
          ],
          'temperature': 0,
          'max_completion_tokens': 40,
          'top_p': 1,
          'stream': false,
        },
        locale: 'en',
        modelsOverride: _translationModels,
      );

      final value = (decoded['query'] as String? ?? '').trim();
      final cleaned = value
          .replaceAll(RegExp(r'^[\x22\x27\s]+|[\x22\x27\s]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isEmpty) return null;
      return cleaned;
    } catch (_) {
      return null;
    }
  }

  String _usdaCacheKey(String ingredientName, String? locale) {
    final normalized = ingredientName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${_languageCode(locale)}::$normalized';
  }

  void _putUsdaFactsCache(String key, Map<String, double> value) {
    if (_usdaFactsCache.length >= _usdaFactsCacheMaxEntries) {
      _usdaFactsCache.remove(_usdaFactsCache.keys.first);
    }
    _usdaFactsCache[key] = value;
  }

  Future<Map<String, double>?> _getUsdaFactsForIngredient({
    required String ingredientName,
    required String? locale,
    required UsdaFoodDataService usdaService,
  }) async {
    final key = _usdaCacheKey(ingredientName, locale);
    final cached = _usdaFactsCache[key];
    if (cached != null) {
      return Map<String, double>.from(cached);
    }

    final inFlight = _usdaFactsInFlight[key];
    if (inFlight != null) {
      final shared = await inFlight;
      return shared == null ? null : Map<String, double>.from(shared);
    }

    final future = _loadUsdaFactsForIngredient(
      ingredientName: ingredientName,
      locale: locale,
      usdaService: usdaService,
    );
    _usdaFactsInFlight[key] = future;

    try {
      final result = await future;
      if (result != null && result.isNotEmpty) {
        _putUsdaFactsCache(key, result);
      }
      return result == null ? null : Map<String, double>.from(result);
    } finally {
      _usdaFactsInFlight.remove(key);
    }
  }

  Future<Map<String, double>?> _loadUsdaFactsForIngredient({
    required String ingredientName,
    required String? locale,
    required UsdaFoodDataService usdaService,
  }) async {
    final queries = await _buildIngredientSearchQueries(ingredientName, locale);

    Map<String, dynamic>? product;
    for (final query in queries) {
      final searchResults = await usdaService.searchProducts(query);
      if (searchResults.isEmpty) continue;

      final candidate =
          await usdaService.getProductInfo(searchResults.first['fdcId']);
      if (candidate != null && candidate['foodNutrients'] != null) {
        product = candidate;
        break;
      }
    }

    if (product == null || product['foodNutrients'] == null) {
      return null;
    }

    final nutr = product['foodNutrients'] as List<dynamic>;
    final nutrMap = <String, double>{};
    for (final n in nutr) {
      if (n is! Map<String, dynamic>) continue;

      final nestedNutrient = n['nutrient'];
      final nestedName = nestedNutrient is Map<String, dynamic>
          ? nestedNutrient['name'] as String?
          : null;

      final rawName = (n['nutrientName'] as String? ?? nestedName ?? '').trim();
      if (rawName.isEmpty) continue;

      final amount = (n['value'] as num?)?.toDouble() ??
          (n['amount'] as num?)?.toDouble() ??
          0.0;

      nutrMap[rawName.toLowerCase()] = amount;
    }

    final filtered = <String, double>{};
    for (final k in nutrientKeys) {
      filtered[k] = _usdaNutrientValue(k, nutrMap);
    }
    return filtered;
  }

  Future<String> generateStatsReport({
    required String periodLabel,
    String? locale,
    required int calorieGoal,
    required int proteinGoal,
    required int fatGoal,
    required int carbsGoal,
    required double avgCalories,
    required double avgProteinGrams,
    required double avgFatGrams,
    required double avgCarbsGrams,
    required double avgFiberGrams,
    required double avgSugarGrams,
    required double avgSaturatedFatGrams,
    required double avgPolyunsaturatedFatGrams,
    required double avgMonounsaturatedFatGrams,
    required double avgTransFatGrams,
    required double avgCholesterolMg,
    required double avgSodiumMg,
    required double avgPotassiumMg,
    required double avgVitaminAMcg,
    required double avgVitaminCMg,
    required double avgVitaminDMcg,
    required double avgCalciumMg,
    required double avgIronMg,
    required double totalCalories,
    required double totalProteinGrams,
    required double totalFatGrams,
    required double totalCarbsGrams,
    required double totalFiberGrams,
    required double totalSugarGrams,
    required double totalSaturatedFatGrams,
    required double totalPolyunsaturatedFatGrams,
    required double totalMonounsaturatedFatGrams,
    required double totalTransFatGrams,
    required double totalCholesterolMg,
    required double totalSodiumMg,
    required double totalPotassiumMg,
    required double totalVitaminAMcg,
    required double totalVitaminCMg,
    required double totalVitaminDMcg,
    required double totalCalciumMg,
    required double totalIronMg,
    required int stepsGoal,
    required int avgSteps,
    required double weightGoal,
    required double latestWeight,
    required double avgWaterLiters,
    required double waterGoalLiters,
    required int workouts,
    required int avgActivityCalories,
  }) async {
    final prompt = '''
You are a fitness assistant and nutritionist.
${_languageInstruction(locale)}
Write a short report based on the user's data for the period: $periodLabel.

Data:
- Calorie goal: $calorieGoal kcal
- Protein goal: $proteinGoal g
- Fat goal: $fatGoal g
- Carbs goal: $carbsGoal g
- Average calories: ${avgCalories.toStringAsFixed(0)} kcal
- Average protein: ${avgProteinGrams.toStringAsFixed(1)} g
- Average fat: ${avgFatGrams.toStringAsFixed(1)} g
- Average carbs: ${avgCarbsGrams.toStringAsFixed(1)} g
- Average fiber: ${avgFiberGrams.toStringAsFixed(1)} g
- Average sugar: ${avgSugarGrams.toStringAsFixed(1)} g
- Average saturated fat: ${avgSaturatedFatGrams.toStringAsFixed(1)} g
- Average polyunsaturated fat: ${avgPolyunsaturatedFatGrams.toStringAsFixed(1)} g
- Average monounsaturated fat: ${avgMonounsaturatedFatGrams.toStringAsFixed(1)} g
- Average trans fat: ${avgTransFatGrams.toStringAsFixed(2)} g
- Average cholesterol: ${avgCholesterolMg.toStringAsFixed(1)} mg
- Average sodium: ${avgSodiumMg.toStringAsFixed(1)} mg
- Average potassium: ${avgPotassiumMg.toStringAsFixed(1)} mg
- Average vitamin A: ${avgVitaminAMcg.toStringAsFixed(1)} mcg
- Average vitamin C: ${avgVitaminCMg.toStringAsFixed(1)} mg
- Average vitamin D: ${avgVitaminDMcg.toStringAsFixed(1)} mcg
- Average calcium: ${avgCalciumMg.toStringAsFixed(1)} mg
- Average iron: ${avgIronMg.toStringAsFixed(1)} mg
- Total for period: ${totalCalories.toStringAsFixed(0)} kcal, protein ${totalProteinGrams.toStringAsFixed(1)} g, fat ${totalFatGrams.toStringAsFixed(1)} g, carbs ${totalCarbsGrams.toStringAsFixed(1)} g
- Total for period (detailed): fiber ${totalFiberGrams.toStringAsFixed(1)} g, sugar ${totalSugarGrams.toStringAsFixed(1)} g, saturated ${totalSaturatedFatGrams.toStringAsFixed(1)} g, polyunsaturated ${totalPolyunsaturatedFatGrams.toStringAsFixed(1)} g, monounsaturated ${totalMonounsaturatedFatGrams.toStringAsFixed(1)} g, trans fat ${totalTransFatGrams.toStringAsFixed(2)} g
- Total minerals/vitamins: cholesterol ${totalCholesterolMg.toStringAsFixed(1)} mg, sodium ${totalSodiumMg.toStringAsFixed(1)} mg, potassium ${totalPotassiumMg.toStringAsFixed(1)} mg, vitamin A ${totalVitaminAMcg.toStringAsFixed(1)} mcg, vitamin C ${totalVitaminCMg.toStringAsFixed(1)} mg, vitamin D ${totalVitaminDMcg.toStringAsFixed(1)} mcg, calcium ${totalCalciumMg.toStringAsFixed(1)} mg, iron ${totalIronMg.toStringAsFixed(1)} mg
- Steps goal: $stepsGoal
- Average steps: $avgSteps
- Weight goal: ${weightGoal.toStringAsFixed(1)} kg
- Latest weight: ${latestWeight.toStringAsFixed(1)} kg
- Water goal: ${waterGoalLiters.toStringAsFixed(1)} L
- Average water: ${avgWaterLiters.toStringAsFixed(1)} L
- Workouts: $workouts
- Average activity calories per workout: $avgActivityCalories

Return ONLY JSON:
{
  "report": "A very brief summary in 2-4 sentences with 2-3 practical steps"
}

Rules:
- report must mention calories, macro/micronutrients, and activity.
- Tone: supportive, no fear-mongering.
- No markdown, no extra keys, no extra text.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.5,
        'max_completion_tokens': 420,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
      modelsOverride: _statsModels,
    );
    final report = (decoded['report'] as String? ?? '').trim();
    if (report.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyReportError,
      );
    }
    return report;
  }

  Future<Map<String, dynamic>> generateStructuredStatsReport({
    required String periodLabel,
    String? locale,
    required String goalType,
    required String activityTypes,
    required String aiContext,
    required int calorieGoal,
    required int proteinGoal,
    required int fatGoal,
    required int carbsGoal,
    required double avgCalories,
    required double avgProteinGrams,
    required double avgFatGrams,
    required double avgCarbsGrams,
    required double avgFiberGrams,
    required double avgSugarGrams,
    required double avgSaturatedFatGrams,
    required double avgPolyunsaturatedFatGrams,
    required double avgMonounsaturatedFatGrams,
    required double avgTransFatGrams,
    required double avgCholesterolMg,
    required double avgSodiumMg,
    required double avgPotassiumMg,
    required double avgVitaminAMcg,
    required double avgVitaminCMg,
    required double avgVitaminDMcg,
    required double avgCalciumMg,
    required double avgIronMg,
    required double totalCalories,
    required double totalProteinGrams,
    required double totalFatGrams,
    required double totalCarbsGrams,
    required double totalFiberGrams,
    required double totalSugarGrams,
    required double totalSaturatedFatGrams,
    required double totalPolyunsaturatedFatGrams,
    required double totalMonounsaturatedFatGrams,
    required double totalTransFatGrams,
    required double totalCholesterolMg,
    required double totalSodiumMg,
    required double totalPotassiumMg,
    required double totalVitaminAMcg,
    required double totalVitaminCMg,
    required double totalVitaminDMcg,
    required double totalCalciumMg,
    required double totalIronMg,
    required int stepsGoal,
    required int avgSteps,
    required double weightGoal,
    required double latestWeight,
    required double avgWaterLiters,
    required double waterGoalLiters,
    required int workouts,
    required int avgActivityCalories,
    required String userName,
    required List<Map<String, dynamic>> topFoods,
    required List<Map<String, dynamic>> snackPriorityRecipes,
    required List<Map<String, dynamic>> availableRecipes,
    required List<Map<String, dynamic>> previousReports,
  }) async {
    final snackLikelyNeeded = avgCalories < calorieGoal * 0.9 ||
        avgProteinGrams < proteinGoal * 0.9 ||
        avgFiberGrams < 18;

    final topFoodsContext = topFoods
        .take(8)
        .map((f) =>
            '- ${(f['name'] as String? ?? '').trim()} (${((f['count'] as num?) ?? 0).round()} times)')
        .where((line) => !line.startsWith('-  ('))
        .join('\n');

    final recipesContext = availableRecipes
        .take(60)
        .map((r) =>
            '- ${(r['name'] as String? ?? '').trim()} (${((r['calories'] as num?) ?? 0).round()} kcal)')
        .where((line) => !line.startsWith('-  ('))
        .join('\n');

    final snackPriorityContext = snackPriorityRecipes
        .take(12)
        .map((r) {
          final name = (r['name'] as String? ?? '').trim();
          final calories = ((r['calories'] as num?) ?? 0).round();
          final protein = (r['protein'] as String? ?? '').trim();
          final fiber = (r['fiber'] as String? ?? '').trim();
          final sugar = (r['sugar'] as String? ?? '').trim();
          return '- $name ($calories kcal, protein $protein g, fiber $fiber g, sugar $sugar g)';
        })
        .where((line) => !line.startsWith('-  ('))
        .join('\n');

    final recentPreviousReports =
        previousReports.take(2).toList(growable: false);

    final previousReportsContext = recentPreviousReports
        .map((report) {
          final period = (report['period'] as String? ?? '').trim();
          final overview = (report['overview'] as String? ?? '').trim();
          final recs = (report['recommendations'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((item) {
                final when = (item['when'] as String? ?? '').trim();
                final action = (item['action'] as String? ?? '').trim();
                final recipeName = (item['recipeName'] as String? ?? '').trim();
                final recipeSuffix =
                    recipeName.isEmpty ? '' : ' [recipe: $recipeName]';
                return '$when: $action$recipeSuffix';
              })
              .where((line) => line.trim().isNotEmpty)
              .join('; ');
          return '- period: $period; overview: $overview; recommendations: $recs';
        })
        .where((line) => !line.startsWith('- period: ;'))
        .join('\n');

    final previousRecipeNames = recentPreviousReports
        .expand((report) =>
            (report['recommendations'] as List<dynamic>? ?? const []))
        .whereType<Map>()
        .map((item) => (item['recipeName'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final previousRecommendedRecipesContext =
        previousRecipeNames.take(40).map((name) => '- $name').join('\n');

    final prompt = '''
You are a supportive fitness assistant and nutritionist.
${_languageInstruction(locale)}
Analyze user progress for the period: $periodLabel.
User name: ${userName.trim().isEmpty ? 'friend' : userName.trim()}
Primary goal type: $goalType
User activity types: ${activityTypes.trim().isEmpty ? 'not specified' : activityTypes.trim()}
User context/preferences: ${aiContext.trim().isEmpty ? 'not specified' : aiContext.trim()}

Goals and progress:
- Calorie goal: $calorieGoal kcal
- Protein goal: $proteinGoal g
- Fat goal: $fatGoal g
- Carbs goal: $carbsGoal g
- Average calories: ${avgCalories.toStringAsFixed(0)} kcal
- Average protein: ${avgProteinGrams.toStringAsFixed(1)} g
- Average fat: ${avgFatGrams.toStringAsFixed(1)} g
- Average carbs: ${avgCarbsGrams.toStringAsFixed(1)} g
- Average fiber: ${avgFiberGrams.toStringAsFixed(1)} g
- Average sugar: ${avgSugarGrams.toStringAsFixed(1)} g
- Average saturated fat: ${avgSaturatedFatGrams.toStringAsFixed(1)} g
- Average polyunsaturated fat: ${avgPolyunsaturatedFatGrams.toStringAsFixed(1)} g
- Average monounsaturated fat: ${avgMonounsaturatedFatGrams.toStringAsFixed(1)} g
- Average trans fat: ${avgTransFatGrams.toStringAsFixed(2)} g
- Average cholesterol: ${avgCholesterolMg.toStringAsFixed(1)} mg
- Average sodium: ${avgSodiumMg.toStringAsFixed(1)} mg
- Average potassium: ${avgPotassiumMg.toStringAsFixed(1)} mg
- Average vitamin A: ${avgVitaminAMcg.toStringAsFixed(1)} mcg
- Average vitamin C: ${avgVitaminCMg.toStringAsFixed(1)} mg
- Average vitamin D: ${avgVitaminDMcg.toStringAsFixed(1)} mcg
- Average calcium: ${avgCalciumMg.toStringAsFixed(1)} mg
- Average iron: ${avgIronMg.toStringAsFixed(1)} mg
- Total calories: ${totalCalories.toStringAsFixed(0)} kcal
- Total protein: ${totalProteinGrams.toStringAsFixed(1)} g
- Total fat: ${totalFatGrams.toStringAsFixed(1)} g
- Total carbs: ${totalCarbsGrams.toStringAsFixed(1)} g
- Total fiber: ${totalFiberGrams.toStringAsFixed(1)} g
- Total sugar: ${totalSugarGrams.toStringAsFixed(1)} g
- Total saturated fat: ${totalSaturatedFatGrams.toStringAsFixed(1)} g
- Total polyunsaturated fat: ${totalPolyunsaturatedFatGrams.toStringAsFixed(1)} g
- Total monounsaturated fat: ${totalMonounsaturatedFatGrams.toStringAsFixed(1)} g
- Total trans fat: ${totalTransFatGrams.toStringAsFixed(2)} g
- Total cholesterol: ${totalCholesterolMg.toStringAsFixed(1)} mg
- Total sodium: ${totalSodiumMg.toStringAsFixed(1)} mg
- Total potassium: ${totalPotassiumMg.toStringAsFixed(1)} mg
- Total vitamin A: ${totalVitaminAMcg.toStringAsFixed(1)} mcg
- Total vitamin C: ${totalVitaminCMg.toStringAsFixed(1)} mg
- Total vitamin D: ${totalVitaminDMcg.toStringAsFixed(1)} mcg
- Total calcium: ${totalCalciumMg.toStringAsFixed(1)} mg
- Total iron: ${totalIronMg.toStringAsFixed(1)} mg
- Steps goal: $stepsGoal
- Average steps: $avgSteps
- Weight goal: ${weightGoal.toStringAsFixed(1)} kg
- Latest weight: ${latestWeight.toStringAsFixed(1)} kg
- Water goal: ${waterGoalLiters.toStringAsFixed(1)} L
- Average water: ${avgWaterLiters.toStringAsFixed(1)} L
- Workouts: $workouts
- Average activity calories per workout: $avgActivityCalories

Most frequently consumed dishes/products:
${topFoodsContext.isEmpty ? '- no clear pattern' : topFoodsContext}

Available recipes in app:
${recipesContext.isEmpty ? '- none' : recipesContext}

Priority snack recipe candidates (prefer these for snack recommendations if suitable):
${snackPriorityContext.isEmpty ? '- none' : snackPriorityContext}

Previous AI reports memory (use for continuity, avoid repeating same generic advice):
${previousReportsContext.isEmpty ? '- no previous reports' : previousReportsContext}

Previously recommended recipes (prefer continuity when still relevant):
${previousRecommendedRecipesContext.isEmpty ? '- none' : previousRecommendedRecipesContext}

Task:
1) Create a full, warm and supportive weekly/monthly/yearly analysis (NOT short): 10-16 sentences.
2) Start with personal addressing using the user's name naturally.
3) Mention key achievements and where user is behind goals.
4) Mention what foods/dishes are consumed most often.
5) Give concrete improvement tips for nutrition balance, including snack ideas (for example, vegetables if suitable).
6) Add practical meal plan recommendations for the next period (what and when to eat) focused on deficits/excesses.
7) If suitable recipes from the list exist, include exact recipe names from the provided list.
8) If there is no suitable recipe, leave recipeName as an empty string and still provide meal advice.
9) Add snack recommendations only if they are actually needed for this user.
10) If snack is needed, prefer adding snack with recipeName from priority snack candidates.
11) If protein or fiber is below goals, prioritize snack ideas with higher protein/fiber and lower sugar.
12) Use previous reports memory to keep recommendations consistent and progressive.
13) Reuse previously recommended recipes when still relevant, otherwise suggest better alternatives from current list.
14) Personalization priority: use foods the user actually eats often first, then gently correct preparation/portion/frequency instead of replacing everything.
15) If a frequently consumed product is not ideal, suggest a nearby alternative from available recipes or a modification of the same product.
16) Protein-aware rule: if avgProteinGrams is already >= proteinGoal, avoid recommending extra high-protein foods (like chicken/protein snacks),
    UNLESS goal type is muscle gain or weight gain.
17) If goal type is muscle gain, higher-protein recommendations are acceptable and should be explained as intentional.
18) Recommendations must be coherent with user's goal type and current macro gaps (do not recommend what is already excessive).
19) Write as a personal coach-assistant: warm, motivating, and specific, without generic fluff.
20) Build overview in 3 mini-paragraphs separated by blank lines:
  A) progress snapshot and positive reinforcement,
  B) diagnosis of nutrition/activity bottlenecks,
  C) specific plan for the next period.
21) Include at least 5 numeric anchors in overview when possible (kcal, grams, steps, liters, workouts).
22) For each recommendation action, write exactly 1 short sentence (preferably up to 120 characters) with concrete execution details.

Snack likely needed by metrics right now: ${snackLikelyNeeded ? 'yes' : 'no'}

Return ONLY JSON object in this format:
{
  "overview": "single continuous analysis text",
  "recommendations": [
    {
      "when": "breakfast|lunch|dinner|snack|any",
      "action": "specific actionable advice",
      "recipeName": "exact recipe name from provided list or empty string"
    }
  ]
}

Rules:
- recommendations: 4 to 8 items
- no markdown, no extra keys, no text outside JSON
- do not output labels like "Part 1" or "Part 2"
- do not add snack recommendation if snack is not needed
''';

    Map<String, dynamic>? decoded;
    try {
      decoded = await _requestDecodedJsonWithAutoRetry(
        body: {
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.4,
          'max_completion_tokens': 1500,
          'top_p': 1,
          'stream': false,
        },
        locale: locale,
        modelsOverride: _statsModels,
      );
    } catch (_) {
      decoded = null;
    }

    var overview = (decoded?['overview'] as String? ?? '').trim();
    List<Map<String, dynamic>> recommendations =
        (decoded?['recommendations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => {
                'when': (item['when'] as String? ?? '').trim(),
                'action': (item['action'] as String? ?? '').trim(),
                'recipeName': (item['recipeName'] as String? ?? '').trim(),
              },
            )
            .where((item) => (item['action'] ?? '').isNotEmpty)
            .toList(growable: true);

    final fallbackSnackRecipeName = snackPriorityRecipes
        .map((r) => (r['name'] as String? ?? '').trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');
    if (fallbackSnackRecipeName.isNotEmpty) {
      for (var i = 0; i < recommendations.length; i++) {
        final when = (recommendations[i]['when'] ?? '').trim().toLowerCase();
        final recipeName = (recommendations[i]['recipeName'] ?? '').trim();
        if ((when == 'snack' || when == 'snacks') && recipeName.isEmpty) {
          recommendations[i] = {
            ...recommendations[i],
            'recipeName': fallbackSnackRecipeName,
          };
        }
      }
    }

    final reviewed = {
      'overview': overview,
      'recommendations': recommendations,
    };

    final reviewedOverview = (reviewed['overview'] as String? ?? '').trim();
    final reviewedRecommendations =
        (reviewed['recommendations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => {
                'when': (item['when'] as String? ?? '').trim(),
                'action': (item['action'] as String? ?? '').trim(),
                'recipeName': (item['recipeName'] as String? ?? '').trim(),
              },
            )
            .where((item) => (item['action'] ?? '').isNotEmpty)
            .toList(growable: true);

    if (reviewedOverview.isNotEmpty) {
      overview = reviewedOverview;
    }
    if (reviewedRecommendations.isNotEmpty) {
      recommendations = reviewedRecommendations;
    }

    recommendations = _ensureApproximateRecommendations(
      recommendations: recommendations,
      topFoods: topFoods,
      locale: locale,
      snackLikelyNeeded: snackLikelyNeeded,
    );

    if (overview.isEmpty) {
      overview = _buildStructuredStatsOverviewFallback(
        locale: locale,
        periodLabel: periodLabel,
        avgCalories: avgCalories,
        calorieGoal: calorieGoal,
        avgProteinGrams: avgProteinGrams,
        proteinGoal: proteinGoal,
        avgSteps: avgSteps,
        stepsGoal: stepsGoal,
      );
    }
    if (recommendations.isEmpty) {
      recommendations = _buildStructuredRecommendationsFallback(
        locale: locale,
        topFoods: topFoods,
        snackLikelyNeeded: snackLikelyNeeded,
      );
    }

    return {
      'overview': overview,
      'recommendations': recommendations.take(8).toList(growable: false),
    };
  }

  List<Map<String, dynamic>> _ensureApproximateRecommendations({
    required List<Map<String, dynamic>> recommendations,
    required List<Map<String, dynamic>> topFoods,
    required bool snackLikelyNeeded,
    String? locale,
  }) {
    final topFoodName = topFoods
        .map((f) => (f['name'] as String? ?? '').trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    final normalized = recommendations
        .map(
          (item) => {
            'when': (item['when'] as String? ?? 'any').trim().isEmpty
                ? 'any'
                : (item['when'] as String? ?? 'any').trim(),
            'action': (item['action'] as String? ?? '').trim(),
            'recipeName': (item['recipeName'] as String? ?? '').trim(),
          },
        )
        .toList(growable: true);

    for (var i = 0; i < normalized.length; i++) {
      final action = (normalized[i]['action'] ?? '').toString().trim();
      final recipeName = (normalized[i]['recipeName'] ?? '').toString().trim();
      if (recipeName.isEmpty && action.length < 18 && topFoodName.isNotEmpty) {
        normalized[i] = {
          ...normalized[i],
          'action': topFoodName,
        };
      }
    }

    if (!snackLikelyNeeded) {
      normalized.removeWhere(
        (item) =>
            (item['when'] ?? '').toString().trim().toLowerCase() == 'snack',
      );
    }

    return normalized;
  }

  String _buildStructuredStatsOverviewFallback({
    required String periodLabel,
    required double avgCalories,
    required int calorieGoal,
    required double avgProteinGrams,
    required int proteinGoal,
    required int avgSteps,
    required int stepsGoal,
    String? locale,
  }) {
    return _messages(locale).statsStructuredFallbackOverview(
      periodLabel,
      avgCalories.toStringAsFixed(0),
      calorieGoal.toString(),
      avgProteinGrams.toStringAsFixed(1),
      proteinGoal.toString(),
      avgSteps.toString(),
      stepsGoal.toString(),
    );
  }

  List<Map<String, dynamic>> _buildStructuredRecommendationsFallback({
    required List<Map<String, dynamic>> topFoods,
    required bool snackLikelyNeeded,
    String? locale,
  }) {
    final topFoodName = topFoods
        .map((f) => (f['name'] as String? ?? '').trim())
        .firstWhere((name) => name.isNotEmpty, orElse: () => '');

    final base = <Map<String, dynamic>>[
      {
        'when': 'breakfast',
        'action': _fallbackRecommendationAction(
          when: 'breakfast',
          locale: locale,
          topFoodName: topFoodName,
        ),
        'recipeName': '',
      },
      {
        'when': 'lunch',
        'action': _fallbackRecommendationAction(
          when: 'lunch',
          locale: locale,
          topFoodName: topFoodName,
        ),
        'recipeName': '',
      },
      {
        'when': 'dinner',
        'action': _fallbackRecommendationAction(
          when: 'dinner',
          locale: locale,
          topFoodName: topFoodName,
        ),
        'recipeName': '',
      },
      if (snackLikelyNeeded)
        {
          'when': 'snack',
          'action': _fallbackRecommendationAction(
            when: 'snack',
            locale: locale,
            topFoodName: topFoodName,
          ),
          'recipeName': '',
        },
    ];

    final normalized = _ensureApproximateRecommendations(
      recommendations: base,
      topFoods: topFoods,
      snackLikelyNeeded: snackLikelyNeeded,
      locale: locale,
    );

    return normalized
        .where((item) => (item['action'] as String? ?? '').trim().isNotEmpty)
        .toList(growable: false);
  }

  String _fallbackRecommendationAction({
    required String when,
    required String? locale,
    required String topFoodName,
  }) {
    final hasTopFood = topFoodName.trim().isNotEmpty;
    final code = _languageCode(locale);

    if (code == 'uk') {
      switch (when) {
        case 'breakfast':
          return hasTopFood
              ? 'Залиш сніданок простим: додай білок і клітковину, а ранкове солодке зменш.'
              : 'Залиш сніданок регулярним: білок, складні вуглеводи та вода.';
        case 'lunch':
          return hasTopFood
              ? 'В обід залиш звичні страви, але додай овочі й контролюй порцію $topFoodName.'
              : 'На обід збирай тарілку: білок, гарнір і овочі.';
        case 'dinner':
          return 'Роби вечерю легшою: менше швидких вуглеводів, більше овочів і стабільний час.';
        case 'snack':
          return 'Для перекусу обирай варіанти з білком або клітковиною та меншим вмістом цукру.';
      }
    }

    if (code == 'en') {
      switch (when) {
        case 'breakfast':
          return hasTopFood
              ? 'Keep breakfast simple: add protein and fiber, and limit sweet items in the morning.'
              : 'Keep breakfast consistent with protein, complex carbs, and water.';
        case 'lunch':
          return hasTopFood
              ? 'For lunch, keep familiar foods but add vegetables and portion control around $topFoodName.'
              : 'Build lunch around a balanced plate: protein, carbs, and vegetables.';
        case 'dinner':
          return 'Make dinner lighter: fewer fast carbs, more vegetables, and stable meal timing.';
        case 'snack':
          return 'Choose snacks with more protein or fiber and less sugar.';
      }
    }

    switch (when) {
      case 'breakfast':
        return hasTopFood
            ? 'Оставь завтрак простым: добавь белок и клетчатку, а сладкое утром сократи.'
            : 'Сделай завтрак стабильным: белок, сложные углеводы и вода.';
      case 'lunch':
        return hasTopFood
            ? 'В обед сохрани привычные блюда, но добавь овощи и контроль порции для $topFoodName.'
            : 'В обед собирай сбалансированную тарелку: белок, гарнир и овощи.';
      case 'dinner':
        return 'Ужин делай легче: меньше быстрых углеводов, больше овощей и стабильное время.';
      case 'snack':
        return 'Для перекуса выбирай варианты с белком или клетчаткой и меньшим количеством сахара.';
      default:
        return hasTopFood
            ? 'Сохрани хорошие привычки и постепенно улучшай рацион вокруг $topFoodName.'
            : 'Сохрани хорошие привычки и постепенно улучшай баланс рациона.';
    }
  }

  Future<DailyGoalsDraft> generateDailyGoals({
    required UserProfile profile,
    String? locale,
  }) async {
    final prompt = '''
You are a nutritionist and fitness consultant.
${_languageInstruction(locale)}
Based on the user's data, suggest daily goals.

User:
- Gender: ${profile.gender.enLabel}
- Age: ${profile.age}
- Height: ${profile.height} cm
- Current weight: ${profile.weight.toStringAsFixed(1)} kg
- Target weight: ${profile.weightGoal.toStringAsFixed(1)} kg
- Goal type: ${profile.goalType.enLabel}
- Goal description: ${profile.goalType.enHint}
- Physical activity frequency: ${profile.activityFrequency.enLabel}
- Activity note: ${profile.activityFrequency.enHint}
- Activity types / sports: ${profile.activityTypes.isEmpty ? 'not specified' : profile.activityTypes}
- Additional context: ${profile.aiContext.isEmpty ? 'not specified' : profile.aiContext}

Return ONLY a JSON object in the format:
{
  "calorieGoal": 0,
  "proteinGoal": 0,
  "fatGoal": 0,
  "carbsGoal": 0,
  "waterGoal": 0,
  "stepsGoal": 0
}

Rules:
- All values must be positive integers.
- waterGoal in milliliters.
- stepsGoal in steps.
- Goals must be realistic for daily achievement.
- Consider the user's goal type, activity level, sports, and additional conditions.
- Keep goals internally consistent: calories should roughly match macros using kcal formula.
- Macro energy equation: calories ≈ protein*4 + carbs*4 + fat*9.
- Align macro split with goal type:
  loseWeight: keep protein relatively high, control carbs/fat.
  gainMuscle: allow higher protein and adequate carbs for training.
  gainWeight: mild surplus, balanced but calorie-dense enough.
  healthyEating/energetic: balanced distribution and sustainability.
- Do not add any explanations outside the JSON.
''';

    DailyGoalsDraft aiDraft;
    try {
      final decoded = await _requestDecodedJsonWithAutoRetry(
        body: {
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.2,
          'max_completion_tokens': 260,
          'top_p': 1,
          'stream': false,
        },
        locale: locale,
        modelsOverride: _dailyGoalsModels,
        maxAttempts: 1,
      );

      int normalizeInt(dynamic value, int fallback) {
        final parsed = _toNonNegativeDouble(value).round();
        return parsed <= 0 ? fallback : parsed;
      }

      aiDraft = DailyGoalsDraft(
        calorieGoal: normalizeInt(decoded['calorieGoal'], profile.calorieGoal),
        proteinGoal: normalizeInt(decoded['proteinGoal'], profile.proteinGoal),
        fatGoal: normalizeInt(decoded['fatGoal'], profile.fatGoal),
        carbsGoal: normalizeInt(decoded['carbsGoal'], profile.carbsGoal),
        waterGoal: normalizeInt(decoded['waterGoal'], profile.waterGoal),
        stepsGoal: normalizeInt(decoded['stepsGoal'], profile.stepsGoal),
      );
    } catch (_) {
      aiDraft = DailyGoalsDraft(
        calorieGoal: profile.calorieGoal,
        proteinGoal: profile.proteinGoal,
        fatGoal: profile.fatGoal,
        carbsGoal: profile.carbsGoal,
        waterGoal: profile.waterGoal,
        stepsGoal: profile.stepsGoal,
      );
    }

    return _normalizeDailyGoalsWithProfile(profile, aiDraft);
  }

  DailyGoalsDraft _normalizeDailyGoalsWithProfile(
    UserProfile profile,
    DailyGoalsDraft aiDraft,
  ) {
    double activityFactor() {
      switch (profile.activityFrequency) {
        case ActivityFrequency.sedentary:
          return 1.2;
        case ActivityFrequency.light:
          return 1.35;
        case ActivityFrequency.moderate:
          return 1.5;
        case ActivityFrequency.active:
          return 1.7;
        case ActivityFrequency.veryActive:
          return 1.9;
      }
    }

    final weight = profile.weight.clamp(35.0, 250.0);
    final height = profile.height.clamp(130, 230).toDouble();
    final age = profile.age.clamp(14, 90);
    final base = profile.gender == Gender.male
        ? 10 * weight + 6.25 * height - 5 * age + 5
        : 10 * weight + 6.25 * height - 5 * age - 161;
    final tdee = (base * activityFactor()).clamp(1200.0, 5000.0);

    double targetCalories = aiDraft.calorieGoal.toDouble();
    switch (profile.goalType) {
      case GoalType.loseWeight:
        targetCalories = targetCalories.clamp(tdee * 0.75, tdee * 0.92);
        break;
      case GoalType.gainMuscle:
        targetCalories = targetCalories.clamp(tdee * 1.03, tdee * 1.18);
        break;
      case GoalType.gainWeight:
        targetCalories = targetCalories.clamp(tdee * 1.05, tdee * 1.2);
        break;
      case GoalType.healthyEating:
        targetCalories = targetCalories.clamp(tdee * 0.9, tdee * 1.08);
        break;
      case GoalType.energetic:
        targetCalories = targetCalories.clamp(tdee * 0.95, tdee * 1.12);
        break;
    }

    final hardMinCalories = profile.gender == Gender.male ? 1400 : 1200;
    final calorieGoal = targetCalories.round().clamp(hardMinCalories, 5000);

    (double, double) proteinRangePerKg() {
      switch (profile.goalType) {
        case GoalType.loseWeight:
          return (1.6, 2.2);
        case GoalType.gainMuscle:
          return (1.8, 2.4);
        case GoalType.gainWeight:
          return (1.4, 2.0);
        case GoalType.healthyEating:
          return (1.2, 1.8);
        case GoalType.energetic:
          return (1.4, 2.0);
      }
    }

    (double, double) fatRangePerKg() {
      switch (profile.goalType) {
        case GoalType.loseWeight:
          return (0.7, 1.1);
        case GoalType.gainMuscle:
          return (0.8, 1.2);
        case GoalType.gainWeight:
          return (0.8, 1.3);
        case GoalType.healthyEating:
          return (0.8, 1.1);
        case GoalType.energetic:
          return (0.8, 1.2);
      }
    }

    final proteinMin = proteinRangePerKg().$1 * weight;
    final proteinMax = proteinRangePerKg().$2 * weight;
    final fatMin = fatRangePerKg().$1 * weight;
    final fatMax = fatRangePerKg().$2 * weight;

    var proteinGoal =
        aiDraft.proteinGoal.toDouble().clamp(proteinMin, proteinMax);
    var fatGoal = aiDraft.fatGoal.toDouble().clamp(fatMin, fatMax);

    final minCarbs = profile.goalType == GoalType.gainMuscle ? 130.0 : 90.0;
    final caloriesLeft = calorieGoal - (proteinGoal * 4 + fatGoal * 9);
    var carbsGoal = (caloriesLeft / 4).clamp(minCarbs, 650.0);

    // Re-balance fats if carbs had to be clamped due to very low/high calorie targets.
    final adjustedFatCalories = calorieGoal - (proteinGoal * 4 + carbsGoal * 4);
    if (adjustedFatCalories > 0) {
      fatGoal = (adjustedFatCalories / 9).clamp(fatMin, fatMax);
    }

    final waterGoal = aiDraft.waterGoal.clamp(1200, 6000);
    final stepsGoal = aiDraft.stepsGoal.clamp(3000, 25000);

    return DailyGoalsDraft(
      calorieGoal: calorieGoal,
      proteinGoal: proteinGoal.round().clamp(60, 320),
      fatGoal: fatGoal.round().clamp(35, 220),
      carbsGoal: carbsGoal.round().clamp(70, 700),
      waterGoal: waterGoal,
      stepsGoal: stepsGoal,
    );
  }

  Future<ActivityAiDraft> estimateActivityDraftFromDescription({
    required String description,
    String? locale,
  }) async {
    final normalized = description.trim();
    if (normalized.isEmpty) {
      throw GeminiRecipeException(_messages(locale).activityAiNeedContext);
    }

    final prompt = '''
You are a sports and fitness assistant.
${_languageInstruction(locale)}
Analyze activity description and produce structured result for a single session.

Activity description:
$normalized

Return ONLY JSON, no markdown:
{
  "name": "",
  "description": "",
  "calories": 0
}

Rules:
- name: short and clear (2-5 words), suitable as activity title in app.
- description: concise, user-friendly summary of activity details.
- calories must be a positive integer.
- be realistic for one activity session.
- if duration/intensity are missing, use a moderate default estimate.
- output only JSON.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.2,
        'max_completion_tokens': 220,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
      modelsOverride: _activityModels,
    );

    final parsedName = (decoded['name'] as String? ?? '').trim();
    final parsedDescription = (decoded['description'] as String? ?? '').trim();
    final calories = _toNonNegativeDouble(decoded['calories']).round();
    if (calories <= 0) {
      throw GeminiRecipeException(_messages(locale).activityAiEstimateFailed);
    }

    final firstPassCalories = calories.clamp(30, 2500);
    final correctedCalories = firstPassCalories;

    return ActivityAiDraft(
      name: parsedName.isEmpty ? normalized : parsedName,
      description: parsedDescription.isEmpty ? normalized : parsedDescription,
      calories: correctedCalories,
    );
  }

  Future<int> estimateActivityCaloriesFromDescription({
    required String description,
    String? locale,
  }) async {
    final draft = await estimateActivityDraftFromDescription(
      description: description,
      locale: locale,
    );
    return draft.calories;
  }

  Future<http.Response> _requestWithFallback({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
    String? locale,
    List<String>? modelsOverride,
  }) async {
    var apiKey = (apiKeyOverride ?? _resolveApiKey()).trim();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiKeyMissingError,
      );
    }

    final usesImageInput = _requestUsesImageInput(body);
    final baseModels = (modelsOverride ?? _models)
        .where((model) => !usesImageInput || _supportsImageInput(model))
        .toList(growable: false);
    if (baseModels.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiNoResponseError,
      );
    }
    final models = await _selectAdaptiveModelOrder(
      candidates: baseModels,
      body: body,
      apiKey: apiKey,
      locale: locale,
    );
    http.Response? lastErrorResponse;
    var tokenSwitchAttempted = false;

    for (final model in models) {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      try {
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                ...body,
                'model': model,
                if (!usesImageInput)
                  'response_format': {'type': 'json_object'},
              }),
            )
            .timeout(_requestTimeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final validForSystem = _isResponseValidForSystem(response.body);
          if (!validForSystem) {
            if (model != models.last) continue;
            throw GeminiRecipeException(
              _messages(locale).aiUnexpectedResponseFormatError,
            );
          }
          return response;
        }

        lastErrorResponse = response;
        
        // Проверка на ошибку rate limit - автопереключение на другой токен
        if (_isRateLimitError(response) && !tokenSwitchAttempted) {
          await _switchToNextGroqToken();
          tokenSwitchAttempted = true;
          // Перезагружаем API ключ и пересчитываем модели
          apiKey = _resolveApiKey().trim();
          if (apiKey.isEmpty) {
            throw GeminiRecipeException(
              _messages(locale).aiKeyMissingError,
            );
          }
          // Продолжаем цикл со следующей моделью, используя новый токен
          continue;
        }

        final isRetryableStatus = response.statusCode == 400 ||
            response.statusCode == 403 ||
            response.statusCode == 404 ||
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        if (isRetryableStatus && model != models.last) {
          continue;
        }
        throw GeminiRecipeException(_buildHttpErrorMessage(response, locale));
      } on TimeoutException {
        if (model != models.last) continue;
        throw GeminiRecipeException(_messages(locale).aiNoResponseError);
      } on http.ClientException {
        if (model != models.last) continue;
        throw GeminiRecipeException(_messages(locale).aiNoResponseError);
      }
    }

    if (lastErrorResponse != null) {
      throw GeminiRecipeException(
          _buildHttpErrorMessage(lastErrorResponse, locale));
    }
    throw GeminiRecipeException(
      _messages(locale).aiNoResponseError,
    );
  }

  Future<List<String>> _selectAdaptiveModelOrder({
    required List<String> candidates,
    required Map<String, dynamic> body,
    required String apiKey,
    String? locale,
  }) async {
    final uniqueCandidates = <String>[];
    for (final model in candidates) {
      if (!uniqueCandidates.contains(model)) {
        uniqueCandidates.add(model);
      }
    }

    if (uniqueCandidates.length <= 1) {
      return uniqueCandidates;
    }

    if (await _shouldBypassRouter()) {
      unawaited(
        _appendRouterHistory(
          taskType: _detectRequestTaskType(body),
          candidates: uniqueCandidates,
          ordered: uniqueCandidates,
          status: 'bypass',
          reason: 'too_many_recent_router_errors',
        ),
      );
      return uniqueCandidates;
    }

    try {
      final taskType = _detectRequestTaskType(body);
      final routedOrder = await _requestAdaptiveModelOrderFromRouter(
        candidates: uniqueCandidates,
        taskType: taskType,
        apiKey: apiKey,
        locale: locale,
      );
      if (routedOrder.isEmpty) {
        await _registerRouterFailure();
        unawaited(
          _appendRouterHistory(
            taskType: taskType,
            candidates: uniqueCandidates,
            ordered: uniqueCandidates,
            status: 'fallback',
            reason: 'empty_router_response',
          ),
        );
        return uniqueCandidates;
      }

      final ordered = <String>[];
      for (final model in routedOrder) {
        if (uniqueCandidates.contains(model) && !ordered.contains(model)) {
          ordered.add(model);
        }
      }
      for (final model in uniqueCandidates) {
        if (!ordered.contains(model)) {
          ordered.add(model);
        }
      }
      await _resetRouterFailureState();
      unawaited(
        _appendRouterHistory(
          taskType: taskType,
          candidates: uniqueCandidates,
          ordered: ordered,
          status: 'ok',
          reason: '',
        ),
      );
      return ordered;
    } catch (_) {
      await _registerRouterFailure();
      unawaited(
        _appendRouterHistory(
          taskType: _detectRequestTaskType(body),
          candidates: uniqueCandidates,
          ordered: uniqueCandidates,
          status: 'fallback',
          reason: 'router_exception',
        ),
      );
      return uniqueCandidates;
    }
  }

  Future<List<String>> _requestAdaptiveModelOrderFromRouter({
    required List<String> candidates,
    required String taskType,
    required String apiKey,
    String? locale,
  }) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final routerPrompt = '''
You are a model-routing planner.
${_languageInstruction(locale)}

Task type: $taskType
Candidate models:
${candidates.map((m) => '- $m').join('\n')}

Goal:
- Choose the best execution order for these models.
- Balance speed and accuracy according to task type.
- For moderation/translation: prefer speed first.
- For nutrition/daily_goals/activity/stats/draft: prefer accuracy first, then speed.
- Return all candidate models exactly once in priority order.

Return ONLY JSON:
{
  "ordered_models": ["modelA", "modelB"],
  "profile": "speed|balanced|accuracy"
}

Rules:
- ordered_models must include only models from candidate list.
- no duplicates.
- no markdown, no extra text.
''';

    for (final routerModel in _routerModels) {
      try {
        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': routerModel,
                'messages': [
                  {
                    'role': 'user',
                    'content': routerPrompt,
                  }
                ],
                'temperature': 0,
                'max_completion_tokens': 160,
                'top_p': 1,
                'stream': false,
                'response_format': {'type': 'json_object'},
              }),
            )
            .timeout(_routerRequestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final content = _extractText(payload, locale).trim();
        if (content.isEmpty) continue;

        final decoded = _decodeJsonObject(content, locale);
        final orderedModels =
            (decoded['ordered_models'] as List<dynamic>? ?? const <dynamic>[])
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);

        if (orderedModels.isNotEmpty) {
          return orderedModels;
        }
      } catch (_) {
        continue;
      }
    }

    return const [];
  }

  String _detectRequestTaskType(Map<String, dynamic> body) {
    final textParts = <String>[];

    void addText(dynamic value) {
      if (value is String) {
        textParts.add(value);
        return;
      }
      if (value is List) {
        for (final item in value) {
          addText(item);
        }
        return;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          if (entry.key == 'content' || entry.key == 'text') {
            addText(entry.value);
          }
        }
      }
    }

    addText(body['messages']);
    final text = textParts.join(' ').toLowerCase();

    if (text.contains('moderation') ||
        text.contains('public community feed') ||
        text.contains('allow|reject')) {
      return 'moderation';
    }
    if (text.contains('daily goals') || text.contains('caloriegoal')) {
      return 'daily_goals';
    }
    if (text.contains('activity') && text.contains('calories')) {
      return 'activity';
    }
    if (text.contains('structured stats') || text.contains('recommendations')) {
      return 'stats';
    }
    if (text.contains('recipe draft') || text.contains('ingredients')) {
      return 'draft';
    }
    if (text.contains('translate the food ingredient')) {
      return 'translation';
    }
    if (text.contains('nutrition') ||
        text.contains('nutrients') ||
        text.contains('calories')) {
      return 'nutrition';
    }

    return 'generic';
  }

  bool _requestUsesImageInput(Map<String, dynamic> body) {
    bool hasImage = false;

    void visit(dynamic value) {
      if (hasImage) return;
      if (value is List) {
        for (final item in value) {
          visit(item);
          if (hasImage) return;
        }
        return;
      }
      if (value is Map) {
        final type = value['type'];
        if (type == 'image_url' && value['image_url'] is Map) {
          hasImage = true;
          return;
        }
        for (final nested in value.values) {
          visit(nested);
          if (hasImage) return;
        }
      }
    }

    visit(body['messages']);
    return hasImage;
  }

  bool _supportsImageInput(String model) {
    return _photoModels.contains(model);
  }

  Future<bool> _shouldBypassRouter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failCount = prefs.getInt(_routerFailCountPrefsKey) ?? 0;
      if (failCount < _routerErrorBypassThreshold) return false;

      final lastFailRaw = prefs.getString(_routerLastFailAtPrefsKey) ?? '';
      final lastFailAt = DateTime.tryParse(lastFailRaw);
      if (lastFailAt == null) return false;

      final withinWindow =
          DateTime.now().difference(lastFailAt) < _routerErrorBypassWindow;
      return withinWindow;
    } catch (_) {
      return false;
    }
  }

  Future<void> _registerRouterFailure() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final current = prefs.getInt(_routerFailCountPrefsKey) ?? 0;
      await prefs.setInt(_routerFailCountPrefsKey, current + 1);
      await prefs.setString(_routerLastFailAtPrefsKey, nowIso);
    } catch (_) {
      // Router diagnostics must never break business flow.
    }
  }

  Future<void> _resetRouterFailureState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_routerFailCountPrefsKey, 0);
      await prefs.remove(_routerLastFailAtPrefsKey);
    } catch (_) {
      // Ignore diagnostics storage errors.
    }
  }

  Future<void> _appendRouterHistory({
    required String taskType,
    required List<String> candidates,
    required List<String> ordered,
    required String status,
    required String reason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _cleanupRouterHistoryIfNeeded(prefs);

      final now = DateTime.now().toUtc();
      final raw = prefs.getString(_routerHistoryPrefsKey) ?? '[]';
      final decoded = jsonDecode(raw);
      final items = decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];

      items.add({
        'ts': now.toIso8601String(),
        'task': taskType,
        'status': status,
        'reason': reason,
        'candidates': candidates,
        'ordered': ordered,
      });

      if (items.length > _routerHistoryMaxEntries) {
        final overflow = items.length - _routerHistoryMaxEntries;
        items.removeRange(0, overflow);
      }

      await prefs.setString(_routerHistoryPrefsKey, jsonEncode(items));
    } catch (_) {
      // Ignore diagnostics storage errors.
    }
  }

  Future<void> _cleanupRouterHistoryIfNeeded(SharedPreferences prefs) async {
    final now = DateTime.now().toUtc();
    final lastCleanupRaw = prefs.getString(_routerLastCleanupAtPrefsKey) ?? '';
    final lastCleanupAt = DateTime.tryParse(lastCleanupRaw);

    final shouldRunCleanup = lastCleanupAt == null ||
        now.difference(lastCleanupAt) >= _routerHistoryRetention;
    if (!shouldRunCleanup) return;

    try {
      final raw = prefs.getString(_routerHistoryPrefsKey) ?? '[]';
      final decoded = jsonDecode(raw);
      final items = decoded is List ? decoded : const [];
      final cutoff = now.subtract(_routerHistoryRetention);

      final filtered = items.whereType<Map>().where((entry) {
        final tsRaw = (entry['ts'] ?? '').toString();
        final ts = DateTime.tryParse(tsRaw);
        if (ts == null) return false;
        return ts.isAfter(cutoff);
      }).toList(growable: false);

      await prefs.setString(_routerHistoryPrefsKey, jsonEncode(filtered));
      await prefs.setString(
        _routerLastCleanupAtPrefsKey,
        now.toIso8601String(),
      );
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  Future<Map<String, dynamic>> _requestDecodedJsonWithAutoRetry({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
    String? locale,
    int maxAttempts = _jsonRetryMaxAttempts,
    List<String>? modelsOverride,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _requestWithFallback(
          body: body,
          apiKeyOverride: apiKeyOverride,
          locale: locale,
          modelsOverride: modelsOverride,
        );

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(payload, locale).trim();
        if (text.isEmpty) {
          throw GeminiRecipeException(_messages(locale).aiEmptyTextError);
        }

        return _decodeJsonObject(text, locale);
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(_jsonRetryDelay);
        }
      }
    }

    if (lastError is GeminiRecipeException) {
      throw lastError;
    }
    throw GeminiRecipeException(
      _messages(locale).aiNoResponseError,
    );
  }

  bool _isResponseValidForSystem(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is! Map<String, dynamic>) return false;

      final choices = payload['choices'];
      if (choices is! List || choices.isEmpty) return false;

      final first = choices.first;
      if (first is! Map<String, dynamic>) return false;

      final message = first['message'];
      if (message is! Map<String, dynamic>) return false;

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) return false;

      final decodedContent = jsonDecode(content.trim());
      return decodedContent is Map<String, dynamic>;
    } catch (_) {
      return false;
    }
  }

  String _resolveApiKey() {
    const groqFromDefine = String.fromEnvironment('GROQ_API_KEY');
    const legacyFromDefine = String.fromEnvironment('GEMINI_API_KEY');

    // Сначала проверяем текущий токен из списка (автопереключение)
    final currentToken = _getCurrentGroqToken();
    if (currentToken.isNotEmpty) return currentToken;

    final candidates = [
      dotenv.env['GROQ_API_KEY'],
      groqFromDefine,
      dotenv.env['GEMINI_API_KEY'],
      legacyFromDefine,
    ];

    for (final candidate in candidates) {
      final normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) return normalized;
    }

    return '';
  }

  String _getCurrentGroqToken() {
    for (final token in _groqTokens) {
      final normalized = token.trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  Future<int> _getCurrentTokenIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_groqTokenIndexPrefsKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _switchToNextGroqToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentIndex = prefs.getInt(_groqTokenIndexPrefsKey) ?? 0;
      final nextIndex = (currentIndex + 1) % _groqTokens.length;
      await prefs.setInt(_groqTokenIndexPrefsKey, nextIndex);
      debugPrint('[Groq Token Switch] Switched from index $currentIndex to $nextIndex');
    } catch (_) {
      // Ignore token switching errors.
    }
  }

  bool _isRateLimitError(http.Response response) {
    if (response.statusCode == 429) return true;
    try {
      final body = response.body.toLowerCase();
      return body.contains('rate limit') ||
          body.contains('quota') ||
          body.contains('limit exceeded') ||
          body.contains('too many requests') ||
          body.contains('exceeded') ||
          body.contains('rate_limit_exceeded');
    } catch (_) {
      return false;
    }
  }

  GeminiRecipeDraft _draftFromDecodedJson(
    Map<String, dynamic> decoded, {
    required String fallbackDescription,
    String? locale,
  }) {
    final rawName = (decoded['name'] as String? ?? '').trim();
    final rawDescription = (decoded['description'] as String? ?? '').trim();
    final rawClarification = (decoded['clarification'] as String? ?? '').trim();
    final rawIconName = (decoded['icon'] as String? ?? '').trim();

    final ingredients = <RecipeIngredient>[];
    final rawIngredients = decoded['ingredients'];
    if (rawIngredients is List) {
      for (final rawIngredient in rawIngredients) {
        if (rawIngredient is! Map<String, dynamic>) continue;
        final name = (rawIngredient['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final quantity = _toNonNegativeDouble(rawIngredient['quantity']);
        final unit = (rawIngredient['unit'] as String? ?? '').trim();
        final isAmbiguous = rawIngredient['ambiguous'] == true;
        ingredients.add(
          RecipeIngredient(
            name: name,
            quantity: quantity,
            unit: unit,
            isAmbiguous: isAmbiguous,
          ),
        );
      }
    }

    final sanitizedIngredients = _sanitizeDraftIngredients(
      ingredients,
      sourceText: '$fallbackDescription ${rawName.trim()}'.trim(),
    );
    if (sanitizedIngredients.isNotEmpty) {
      ingredients
        ..clear()
        ..addAll(sanitizedIngredients);
    }

    if (ingredients.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiFailedToExtractIngredientsError,
      );
    }

    final nutrients = <String, double>{};
    final rawNutrients = decoded['nutrients'];
    final nutrientsMap = rawNutrients is Map<String, dynamic>
        ? rawNutrients
        : <String, dynamic>{};
    for (final key in nutrientKeys) {
      nutrients[key] = _toNonNegativeDouble(nutrientsMap[key]);
    }

    return GeminiRecipeDraft(
      name: rawName.isEmpty ? _messages(locale).newRecipeTitle : rawName,
      description:
          rawDescription.isEmpty ? fallbackDescription : rawDescription,
      clarification: rawClarification.isEmpty
          ? _buildDenseClarificationFallback(
              description:
                  rawDescription.isEmpty ? fallbackDescription : rawDescription,
              ingredients: ingredients,
            )
          : rawClarification,
      icon:
          _resolveDraftIcon(rawIconName, rawName, rawDescription, ingredients),
      ingredients: ingredients,
      nutrients: nutrients,
    );
  }

  String _buildDenseClarificationFallback({
    required String description,
    required List<RecipeIngredient> ingredients,
  }) {
    final normalizedDescription = description.trim();
    final lowerDescription = normalizedDescription.toLowerCase();

    String? inferType() {
      if (_containsAny(lowerDescription, const ['энергет', 'energy drink'])) {
        return 'Энергетик.';
      }
      if (_containsAny(lowerDescription, const ['газиров', 'soda'])) {
        return 'Газированный напиток.';
      }
      if (_containsAny(lowerDescription, const ['суп', 'soup', 'broth'])) {
        return 'Суп.';
      }
      if (_containsAny(lowerDescription, const ['салат', 'salad'])) {
        return 'Салат.';
      }
      return null;
    }

    String inferThermalProcessing() {
      if (_containsAny(lowerDescription,
          const ['запеч', 'baked', 'печ', 'гриль', 'grill'])) {
        return 'Запекание/гриль.';
      }
      if (_containsAny(lowerDescription, const ['жар', 'fried', 'fry'])) {
        return 'Жарка.';
      }
      if (_containsAny(lowerDescription, const ['вар', 'boiled', 'steam'])) {
        return 'Варка/пар.';
      }
      return 'Способ приготовления: базовый домашний (уточнить по контексту).';
    }

    final ambiguous = ingredients
        .where((i) => i.isAmbiguous)
        .map((i) => i.name)
        .where((name) => name.trim().isNotEmpty)
        .take(4)
        .join(', ');

    final keyIngredients = ingredients.take(8).map((i) {
      final amount = i.quantity > 0
          ? ' ${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity.toStringAsFixed(1)} ${i.unit}'
              .trim()
          : '';
      return '- ${i.name}$amount';
    }).join('\n');

    final lines = <String>[];
    final typeLine = inferType();
    if (typeLine != null) lines.add(typeLine);
    if (normalizedDescription.isNotEmpty) {
      lines.add(normalizedDescription);
    }
    lines.add(inferThermalProcessing());
    if (ambiguous.isNotEmpty) {
      lines.add('Уточнить: $ambiguous.');
    }
    if (keyIngredients.isNotEmpty) {
      lines.add('Состав:\n$keyIngredients');
    }
    lines.add(
      'Если бренд неизвестен — использовать типичный состав для этого типа.',
    );
    return lines.join('\n');
  }

  List<RecipeIngredient> _sanitizeDraftIngredients(
    List<RecipeIngredient> ingredients, {
    required String sourceText,
  }) {
    if (ingredients.isEmpty) return ingredients;

    final normalizedSource = sourceText.toLowerCase();
    final dishSuggestsLiquidBase = _containsAny(
      normalizedSource,
      const [
        'суп',
        'бульон',
        'борщ',
        'уха',
        'чай',
        'кофе',
        'напит',
        'смузи',
        'компот',
        'лимонад',
        'drink',
        'beverage',
        'soup',
        'broth',
        'tea',
        'coffee',
        'smoothie',
        'juice',
        'soda',
        'sup',
        'бульй',
        'напій',
        'чай',
        'кава',
        'сік',
      ],
    );

    bool isExplicitlyMentioned(RecipeIngredient ingredient) {
      final name = ingredient.name.toLowerCase();
      if (_containsAny(name, const ['water', 'вода', 'воду', 'вода'])) {
        return _containsAny(
            normalizedSource, const ['water', 'вода', 'вод', 'воду']);
      }
      if (_containsAny(
          name, const ['broth', 'bouillon', 'бульон', 'бульйон'])) {
        return _containsAny(
          normalizedSource,
          const ['broth', 'bouillon', 'бульон', 'бульйон', 'бульй'],
        );
      }
      return true;
    }

    bool shouldDrop(RecipeIngredient ingredient) {
      final name = ingredient.name.toLowerCase();
      final isWater =
          _containsAny(name, const ['water', 'вода', 'воду', 'вода']);
      final isBroth = _containsAny(
        name,
        const ['broth', 'bouillon', 'бульон', 'бульйон'],
      );
      if (!isWater && !isBroth) return false;
      if (isExplicitlyMentioned(ingredient)) return false;
      if (dishSuggestsLiquidBase) return false;
      return true;
    }

    final filtered =
        ingredients.where((i) => !shouldDrop(i)).toList(growable: false);
    final base = filtered.isEmpty ? ingredients : filtered;
    final withLiquidNormalization = _normalizeLiquidBaseForServing(
      base,
      dishSuggestsLiquidBase: dishSuggestsLiquidBase,
    );
    final hasExplicitYieldInfo =
        _hasExplicitYieldOrVolumeInfo(normalizedSource);
    if (hasExplicitYieldInfo) {
      return withLiquidNormalization;
    }
    return _normalizeSingleServingIngredients(
      withLiquidNormalization,
      dishSuggestsLiquidBase: dishSuggestsLiquidBase,
    );
  }

  List<RecipeIngredient> _normalizeSingleServingIngredients(
    List<RecipeIngredient> ingredients, {
    required bool dishSuggestsLiquidBase,
  }) {
    if (ingredients.isEmpty) return ingredients;

    final totalMaxGrams = dishSuggestsLiquidBase ? 900.0 : 650.0;
    final perItemMaxGrams = dishSuggestsLiquidBase ? 500.0 : 350.0;

    final normalized = <RecipeIngredient>[];
    final scalableIndexes = <int>[];
    var totalGrams = 0.0;

    for (final ingredient in ingredients) {
      final unit = ingredient.unit.trim().toLowerCase();
      var quantity = ingredient.quantity;

      // Piece-like units are often overestimated by AI; keep realistic per serving defaults.
      if (unit == 'pcs' && quantity > 4) {
        quantity = 4;
      } else if ((unit == 'pack' || unit == 'pkg' || unit == 'package') &&
          quantity > 2) {
        quantity = 2;
      }

      final normalizedIngredient = RecipeIngredient(
        name: ingredient.name,
        quantity: quantity,
        unit: ingredient.unit,
        isAmbiguous: ingredient.isAmbiguous,
      );
      normalized.add(normalizedIngredient);

      final grams = _toGramsEquivalent(quantity, unit);
      if (grams == null) continue;

      final cappedGrams = grams > perItemMaxGrams ? perItemMaxGrams : grams;
      final scaledBack = _fromGramsEquivalent(cappedGrams, unit);
      normalized[normalized.length - 1] = RecipeIngredient(
        name: ingredient.name,
        quantity: double.parse(scaledBack.toStringAsFixed(1)),
        unit: ingredient.unit,
        isAmbiguous: ingredient.isAmbiguous,
      );

      scalableIndexes.add(normalized.length - 1);
      totalGrams += cappedGrams;
    }

    if (scalableIndexes.isEmpty || totalGrams <= totalMaxGrams) {
      return normalized;
    }

    final scale = totalMaxGrams / totalGrams;
    for (final idx in scalableIndexes) {
      final item = normalized[idx];
      final unit = item.unit.trim().toLowerCase();
      final grams = _toGramsEquivalent(item.quantity, unit);
      if (grams == null) continue;
      final scaledGrams = (grams * scale).clamp(5.0, perItemMaxGrams);
      final scaledQuantity = _fromGramsEquivalent(scaledGrams, unit);
      normalized[idx] = RecipeIngredient(
        name: item.name,
        quantity: double.parse(scaledQuantity.toStringAsFixed(1)),
        unit: item.unit,
        isAmbiguous: item.isAmbiguous,
      );
    }

    return normalized;
  }

  List<RecipeIngredient> _normalizeLiquidBaseForServing(
    List<RecipeIngredient> ingredients, {
    required bool dishSuggestsLiquidBase,
  }) {
    if (ingredients.isEmpty) return ingredients;

    final perItemMaxMl = dishSuggestsLiquidBase ? 500.0 : 300.0;
    final totalMaxMl = dishSuggestsLiquidBase ? 700.0 : 400.0;

    final normalized = <RecipeIngredient>[];
    final liquidIndexes = <int>[];
    var totalLiquidMl = 0.0;

    for (final ingredient in ingredients) {
      final lowerName = ingredient.name.toLowerCase();
      final isWater = _containsAny(lowerName, const ['water', 'вода', 'воду']);
      final isBroth = _containsAny(
        lowerName,
        const ['broth', 'bouillon', 'бульон', 'бульйон'],
      );

      if (!isWater && !isBroth) {
        normalized.add(ingredient);
        continue;
      }

      final ml = _toMilliliters(ingredient.quantity, ingredient.unit);
      if (ml == null) {
        normalized.add(ingredient);
        continue;
      }

      final cappedMl = ml > perItemMaxMl ? perItemMaxMl : ml;
      totalLiquidMl += cappedMl;
      liquidIndexes.add(normalized.length);
      normalized.add(
        RecipeIngredient(
          name: ingredient.name,
          quantity: double.parse(cappedMl.toStringAsFixed(1)),
          unit: 'ml',
          isAmbiguous: ingredient.isAmbiguous,
        ),
      );
    }

    if (liquidIndexes.isEmpty || totalLiquidMl <= totalMaxMl) {
      return normalized;
    }

    final scale = totalMaxMl / totalLiquidMl;
    for (final idx in liquidIndexes) {
      final item = normalized[idx];
      final scaledMl = (item.quantity * scale).clamp(10.0, perItemMaxMl);
      normalized[idx] = RecipeIngredient(
        name: item.name,
        quantity: double.parse(scaledMl.toStringAsFixed(1)),
        unit: 'ml',
        isAmbiguous: item.isAmbiguous,
      );
    }

    return normalized;
  }

  double? _toMilliliters(double quantity, String unit) {
    if (quantity <= 0) return null;
    switch (unit.trim().toLowerCase()) {
      case 'ml':
        return quantity;
      case 'l':
      case 'liter':
      case 'litre':
      case 'литр':
      case 'літр':
        return quantity * 1000;
      case 'g':
        return quantity;
      case 'kg':
        return quantity * 1000;
      default:
        return null;
    }
  }

  String? _validateIngredientPlausibility({
    required List<RecipeIngredient> ingredients,
    String? locale,
  }) {
    for (final ingredient in ingredients) {
      final name = ingredient.name.trim().toLowerCase();
      if (name.isEmpty) continue;

      final nonFoodWords = [
        'какаш',
        'говн',
        'дерьм',
        'shit',
        'poop',
        'feces',
        'фекал',
      ];
      if (_containsAny(name, nonFoodWords)) {
        return _messages(locale).validationNonFoodIngredient;
      }

      final grams = _toGramsEquivalent(
        ingredient.quantity,
        ingredient.unit.trim().toLowerCase(),
      );
      if (grams == null) continue;

      final isSalt = _containsAny(name, ['salt', 'соль', 'солі', 'сiль']);
      if (isSalt && grams > 120) {
        return _messages(locale).validationSaltExcess;
      }
    }

    return null;
  }

  void _applyNutrientsBestEffortFallback(Map<String, double> nutrients) {
    final protein = nutrients['protein'] ?? 0;
    final carbs = nutrients['carbs'] ?? 0;
    final fat = nutrients['fat'] ?? 0;
    final allZeros = nutrientKeys.every((key) => (nutrients[key] ?? 0) <= 0);
    if (allZeros) {
      nutrients['calories'] = nutrients['calories'] ?? 1;
      nutrients['protein'] = nutrients['protein'] ?? 0.1;
      nutrients['carbs'] = nutrients['carbs'] ?? 0.1;
      nutrients['fat'] = nutrients['fat'] ?? 0.1;
      return;
    }

    if ((nutrients['calories'] ?? 0) <= 0) {
      final estimatedCalories = protein * 4 + carbs * 4 + fat * 9;
      nutrients['calories'] = estimatedCalories > 0 ? estimatedCalories : 1;
    }
  }

  bool _hasExplicitYieldOrVolumeInfo(String sourceText) {
    final text = sourceText.toLowerCase();
    return RegExp(
      r'\b\d+(?:[\.,]\d+)?\s*(?:порц|порци|serv|serving)\b',
      caseSensitive: false,
    ).hasMatch(text);
  }

  double? _toGramsEquivalent(double quantity, String unit) {
    if (quantity <= 0) return null;
    switch (unit) {
      case 'g':
      case 'ml':
        return quantity;
      case 'kg':
      case 'l':
        return quantity * 1000;
      case 'tbsp':
        return quantity * 15;
      case 'tsp':
        return quantity * 5;
      case 'стакан':
      case 'стак':
        return quantity * 200;
      case 'cup':
        return quantity * 240;
      default:
        return null;
    }
  }

  double _fromGramsEquivalent(double grams, String unit) {
    switch (unit) {
      case 'g':
      case 'ml':
        return grams;
      case 'kg':
      case 'l':
        return grams / 1000;
      case 'tbsp':
        return grams / 15;
      case 'tsp':
        return grams / 5;
      case 'стакан':
      case 'стак':
        return grams / 200;
      case 'cup':
        return grams / 240;
      default:
        return grams;
    }
  }

  bool _containsAny(String source, List<String> needles) {
    for (final needle in needles) {
      if (needle.isNotEmpty && source.contains(needle)) return true;
    }
    return false;
  }

  IconData _resolveDraftIcon(
    String rawIconName,
    String rawName,
    String rawDescription,
    List<RecipeIngredient> ingredients,
  ) {
    final normalized = rawIconName.startsWith('Symbols.')
        ? rawIconName.substring('Symbols.'.length)
        : rawIconName;
    if (_allowedIconNames.contains(normalized)) {
      return RecipeLoader.getIcon(normalized);
    }

    final haystack = [
      rawName,
      rawDescription,
      ...ingredients.map((item) => item.name),
    ].join(' ').toLowerCase();

    if (haystack.contains('coffee') ||
        haystack.contains('latte') ||
        haystack.contains('cappu')) {
      return RecipeLoader.getIcon('coffee');
    }
    if (haystack.contains('soup') || haystack.contains('broth')) {
      return RecipeLoader.getIcon('soup_kitchen');
    }
    if (haystack.contains('pizza') || haystack.contains('pizz')) {
      return RecipeLoader.getIcon('local_pizza');
    }
    if (haystack.contains('ice') ||
        haystack.contains('cream') ||
        haystack.contains('gelato')) {
      return RecipeLoader.getIcon('icecream');
    }
    if (haystack.contains('cake') ||
        haystack.contains('pie') ||
        haystack.contains('tort')) {
      return RecipeLoader.getIcon('cake');
    }
    if (haystack.contains('cookie') || haystack.contains('biscuit')) {
      return RecipeLoader.getIcon('cookie');
    }
    if (haystack.contains('donut') || haystack.contains('doughnut')) {
      return RecipeLoader.getIcon('donut_large');
    }
    if (haystack.contains('rice') ||
        haystack.contains('pilaf') ||
        haystack.contains('bowl')) {
      return RecipeLoader.getIcon('rice_bowl');
    }
    if (haystack.contains('egg') ||
        haystack.contains('omelet') ||
        haystack.contains('omelette')) {
      return RecipeLoader.getIcon('egg');
    }
    if (haystack.contains('kebab') || haystack.contains('shawarma')) {
      return RecipeLoader.getIcon('kebab_dining');
    }
    if (haystack.contains('smoothie') ||
        haystack.contains('cocktail') ||
        haystack.contains('shake')) {
      return RecipeLoader.getIcon('blender');
    }

    return RecipeLoader.getIcon('restaurant');
  }

  String _buildHttpErrorMessage(http.Response response, [String? locale]) {
    final code = response.statusCode;
    final apiMessage = _extractApiErrorMessage(response.body);

    if (code == 404) {
      return _messages(locale).aiHttpNotFoundError;
    }
    if (code == 403) {
      return '${_messages(locale).aiHttpForbiddenError}${apiMessage.isEmpty ? '' : ' ${_messages(locale).detailsLabel}: $apiMessage'}';
    }
    if (code == 401) {
      return '${_messages(locale).aiHttpUnauthorizedError}${apiMessage.isEmpty ? '' : ' ${_messages(locale).detailsLabel}: $apiMessage'}';
    }
    if (code == 429) {
      return '${_messages(locale).aiHttpRateLimitError}${apiMessage.isEmpty ? '' : ' ${_messages(locale).detailsLabel}: $apiMessage'}';
    }

    return '${_messages(locale).aiHttpGenericError(code)}${apiMessage.isEmpty ? '' : ' ${_messages(locale).detailsLabel}: $apiMessage'}';
  }

  String _extractApiErrorMessage(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final error = payload['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String) return message.trim();
        }
      }
    } catch (_) {
      // Ignore non-JSON error body.
    }

    return '';
  }

  String _extractText(Map<String, dynamic> payload, [String? locale]) {
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyResponseError,
      );
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw GeminiRecipeException(
        _messages(locale).aiUnexpectedResponseFormatError,
      );
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw GeminiRecipeException(
        _messages(locale).aiFailedToReadResponseError,
      );
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyTextError,
      );
    }
    return content;
  }

  Map<String, dynamic> _decodeJsonObject(String text, [String? locale]) {
    final trimmed = text.trim();
    debugPrint('[Groq raw response]:\n$trimmed');

    // 1. Direct decode.
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) {
        return direct;
      }
    } catch (_) {}

    // 2. Try parsing code-fenced content first.
    final fencedMatches =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').allMatches(trimmed);
    for (final match in fencedMatches) {
      final fencedBody = (match.group(1) ?? '').trim();
      if (fencedBody.isEmpty) continue;

      try {
        final parsed = jsonDecode(fencedBody);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (_) {}

      final extractedFromFence = _extractFirstBalancedJsonObject(fencedBody);
      if (extractedFromFence != null) {
        try {
          final parsed = jsonDecode(extractedFromFence);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (_) {}
      }
    }

    // 3. Extract first balanced JSON object from free-form text.
    final extracted = _extractFirstBalancedJsonObject(trimmed);
    if (extracted != null) {
      try {
        final parsed = jsonDecode(extracted);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (_) {}
    }

    // 4. User-facing error message.
    throw GeminiRecipeException(
      _messages(locale).aiFailedToParseJsonError,
    );
  }

  String? _extractFirstBalancedJsonObject(String text) {
    var start = -1;
    var depth = 0;
    var inString = false;
    var isEscaped = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];

      if (inString) {
        if (isEscaped) {
          isEscaped = false;
          continue;
        }
        if (ch == '\\') {
          isEscaped = true;
          continue;
        }
        if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }

      if (ch == '{') {
        if (depth == 0) {
          start = i;
        }
        depth++;
        continue;
      }

      if (ch == '}') {
        if (depth == 0) continue;
        depth--;
        if (depth == 0 && start >= 0) {
          return text.substring(start, i + 1).trim();
        }
      }
    }

    return null;
  }

  double _toNonNegativeDouble(dynamic value) {
    final parsed = (value as num?)?.toDouble() ??
        double.tryParse((value ?? '').toString().replaceAll(',', '.')) ??
        0.0;
    if (!parsed.isFinite || parsed.isNaN) return 0.0;
    return parsed < 0 ? 0.0 : parsed;
  }
}

class GeminiRecipeDraft {
  final String name;
  final String description;
  final String clarification;
  final IconData icon;
  final List<RecipeIngredient> ingredients;
  final Map<String, double> nutrients;

  const GeminiRecipeDraft({
    required this.name,
    required this.description,
    required this.clarification,
    required this.icon,
    required this.ingredients,
    required this.nutrients,
  });
}

class DailyGoalsDraft {
  final int calorieGoal;
  final int proteinGoal;
  final int fatGoal;
  final int carbsGoal;
  final int waterGoal;
  final int stepsGoal;

  const DailyGoalsDraft({
    required this.calorieGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.waterGoal,
    required this.stepsGoal,
  });
}

class ActivityAiDraft {
  final String name;
  final String description;
  final int calories;

  const ActivityAiDraft({
    required this.name,
    required this.description,
    required this.calories,
  });
}

class DonateRecipeModerationResult {
  final bool approved;
  final String reason;
  final double confidence;
  final List<String> flags;

  const DonateRecipeModerationResult({
    required this.approved,
    required this.reason,
    required this.confidence,
    required this.flags,
  });
}

class GeminiRecipeException implements Exception {
  final String message;

  const GeminiRecipeException(this.message);

  @override
  String toString() => message;
}
