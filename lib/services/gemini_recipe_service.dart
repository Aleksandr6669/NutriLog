import 'usda_food_data_service.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nutri_log/l10n/app_localizations.dart';

import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'recipe_loader.dart';
import 'dart:ui' as ui;

class GeminiRecipeService {
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

  static const List<String> _models = [
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
    'llama-3.3-70b-versatile',
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
- ingredient quantities must be realistic for ONE serving (1 person).
- If user does not explicitly specify total amount/yield/number of servings, assume exactly 1 serving for 1 person.
- quantity as a number >= 0.
- unit as a short string like: g, ml, pcs, tbsp, tsp.
- nutrients as numbers only >= 0.
- If exact data is unavailable, provide a realistic estimate.
- For each ingredient, set "ambiguous": true if the preparation method or form is unclear and significantly affects nutrition (e.g., boiled vs dry pasta, cereal with milk vs dry, raw vs cooked meat). Set "ambiguous": false otherwise.
- Do NOT add generic fillers like water/broth/oil/salt/sugar unless they are explicitly mentioned by the user or clearly required by the dish/product type.
''';

    final response = await _requestWithFallback(
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);
    return _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
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

    final response = await _requestWithFallback(
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);
    return _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
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
      final queries = await _buildIngredientSearchQueries(
        ingredient.name,
        locale,
      );

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

      if (product != null && product['foodNutrients'] != null) {
        final nutr = product['foodNutrients'] as List<dynamic>;
        final nutrMap = <String, double>{};
        for (final n in nutr) {
          final name = (n['nutrientName'] as String? ?? '').toLowerCase();
          final amount = (n['value'] as num?)?.toDouble() ?? 0.0;
          nutrMap[name] = amount;
        }
        // Keep only keys from nutrientKeys
        final filtered = <String, double>{};
        for (final k in nutrientKeys) {
          filtered[k] = _usdaNutrientValue(k, nutrMap);
        }
        factsJson[ingredient.name] = filtered;
      }
    }

    final prompt = '''
  You are a professional nutritionist specializing in precise per-serving nutritional calculations.
  ${_languageInstruction(locale)}

  TASK: Calculate the exact total nutritional value for ONE SERVING (for 1 person) of the recipe described below.

  CRITICAL RULES:
  1. The ingredient list below IS the full recipe for ONE PERSON — do NOT divide quantities.
  2. The specified amounts are exactly what goes into this single serving.
  3. For packaged products (bottle, can, pack, bar, etc.): treat the quantity as the actual content.
     Examples: "1 bottle of energy drink (500 ml)" = 500 ml, "1 pack of butter (200 g)" = 200 g, "1 protein bar (60 g)" = 60 g.
    3.1. If the ingredient name/description contains explicit net amount (for example: 500 ml, 330ml, 0.5 l, 200 g, 90g), ALWAYS use that explicit value.
       Never replace an explicit label value with a "typical" package size.
  4. Use the recipe NAME and DESCRIPTION as additional context to identify the product type and infer missing nutrient data.
     Example: if description says "energy drink", include caffeine-related vitamins and typical energy drink composition.

  UNIT CONVERSION (to grams):
  - Milliliters: water/juice ≈ 1 g/ml, milk ≈ 1.03 g/ml, oil ≈ 0.9 g/ml, honey ≈ 1.4 g/ml
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
  - Name: ${recipeName.trim().isEmpty ? 'Untitled' : recipeName.trim()}
  - Description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
  - User clarification: ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
  - Serving size: all ingredients below = 1 serving for 1 person
  - Ingredients:
  $ingredientsText

  Ingredient names may be in any language (English, Russian, Ukrainian, mixed spellings). Correctly interpret them as food products before calculation.

  Reply with ONLY a JSON object. Keys: ${nutrientKeys.join(', ')} (all numeric doubles, no units, no negatives, no nulls). Return {} only if completely unable to estimate. No markdown, no text, no explanations outside JSON.

  JSON value units:
  - calories: kcal
  - protein, carbs, fat, fiber, sugar, saturated_fat, polyunsaturated_fat, monounsaturated_fat, trans_fat: grams
  - cholesterol, sodium, potassium, calcium, iron, vitamin_c: milligrams
  - vitamin_a, vitamin_d: micrograms
  ''';

    final response = await _requestWithFallback(
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);

    final normalized = <String, double>{};
    for (final key in nutrientKeys) {
      normalized[key] = _toNonNegativeDouble(decoded[key]);
    }
    return normalized;
  }

  Future<DonateRecipeModerationResult> validateRecipeForCommunityDonation({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required List<RecipeIngredient> ingredients,
    required Map<String, double> nutrients,
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

    final nutrientsText = nutrientKeys
        .map((k) => '$k=${(nutrients[k] ?? 0).toStringAsFixed(2)}')
        .join(', ');

    final prompt = '''
You are a strict content moderation and culinary validation assistant.
${_languageInstruction(locale)}

Task: decide whether this recipe can be permanently published to a public community feed.

Reject the recipe if ANY of these is true:
- contains profanity, insults, obscene/sexual terms, hateful content, harassment;
- contains obvious nonsense, trolling, spam, gibberish, or fake recipe text;
- is clearly not a food recipe (or not meaningful enough for users);
- ingredient list is implausible for cooking/eating.

Allow only if recipe looks legitimate, understandable, and safe for a public food community.

Recipe data:
- name: ${recipeName.trim()}
- description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
- clarification: ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
- ingredients:
$ingredientsText
- nutrients: $nutrientsText

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
- Treat examples like "какашка", "рецепт мусора", random symbols or obvious trolling as nonsense and reject.
- If uncertain, set approved=false.
''';

    final response = await _requestWithFallback(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0,
        'max_completion_tokens': 300,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);

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
              ? 'Рецепт прошел AI-проверку и может быть опубликован.'
              : 'AI-проверка не пройдена: рецепт выглядит невалидным для сообщества.')
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
      final response = await _requestWithFallback(
        body: {
          'messages': [
            {
              'role': 'user',
              'content': '''
Translate the food ingredient name to concise English for USDA food search.
Return ONLY one short English ingredient phrase (1-4 words), no punctuation, no quotes, no explanation.

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
      );

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = _extractText(payload, locale).trim();
      final cleaned = raw
          .replaceAll(RegExp(r'^[\x22\x27\s]+|[\x22\x27\s]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isEmpty) return null;
      return cleaned;
    } catch (_) {
      return null;
    }
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

Response format:
1) A very brief summary: 2-4 sentences maximum
2) Consider not only calories but also macro/micronutrients and activity
3) Provide 2-3 practical steps for the next period
4) Tone: supportive, no fear-mongering
5) No markdown, plain text only.
''';

    final response = await _requestWithFallback(
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale).trim();
    if (text.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyReportError,
      );
    }
    return text;
  }

  Future<Map<String, dynamic>> generateStructuredStatsReport({
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

    final previousReportsContext = previousReports
        .take(12)
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

    final previousRecipeNames = previousReports
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
1) Create a full, warm and supportive weekly/monthly/yearly analysis (NOT short): 6-10 sentences.
2) Start with personal addressing using the user's name naturally.
3) Mention key achievements and where user is behind goals.
4) Mention what foods/dishes are consumed most often and what to improve.
5) Give concrete improvement tips for nutrition balance, including snack ideas (for example, vegetables if suitable).
6) Add practical meal plan recommendations for the next period (what and when to eat) focused on deficits/excesses.
7) If suitable recipes from the list exist, include exact recipe names from the provided list.
8) If there is no suitable recipe, leave recipeName as an empty string and still provide meal advice.
9) Add snack recommendations only if they are actually needed for this user.
10) If snack is needed, prefer adding snack with recipeName from priority snack candidates.
11) If protein or fiber is below goals, prioritize snack ideas with higher protein/fiber and lower sugar.
12) Use previous reports memory to keep recommendations consistent and progressive.
13) Reuse previously recommended recipes when still relevant, otherwise suggest better alternatives from current list.

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
- recommendations: 3 to 6 items
- no markdown, no extra keys, no text outside JSON
- do not output labels like "Part 1" or "Part 2"
- do not add snack recommendation if snack is not needed
''';

    final response = await _requestWithFallback(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.4,
        'max_completion_tokens': 520,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale).trim();
    if (text.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyReportError,
      );
    }

    final decoded = _decodeJsonObject(text, locale);
    final overview = (decoded['overview'] as String? ?? '').trim();
    final recommendations =
        (decoded['recommendations'] as List<dynamic>? ?? const [])
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

    if (overview.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiEmptyReportError,
      );
    }

    return {
      'overview': overview,
      'recommendations': recommendations,
    };
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
- Do not add any explanations outside the JSON.
''';

    final response = await _requestWithFallback(
      body: {
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
        'max_completion_tokens': 400,
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);

    int normalizeInt(dynamic value, int fallback) {
      final parsed = _toNonNegativeDouble(value).round();
      return parsed <= 0 ? fallback : parsed;
    }

    return DailyGoalsDraft(
      calorieGoal: normalizeInt(decoded['calorieGoal'], profile.calorieGoal),
      proteinGoal: normalizeInt(decoded['proteinGoal'], profile.proteinGoal),
      fatGoal: normalizeInt(decoded['fatGoal'], profile.fatGoal),
      carbsGoal: normalizeInt(decoded['carbsGoal'], profile.carbsGoal),
      waterGoal: normalizeInt(decoded['waterGoal'], profile.waterGoal),
      stepsGoal: normalizeInt(decoded['stepsGoal'], profile.stepsGoal),
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

    final response = await _requestWithFallback(
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload, locale);
    final decoded = _decodeJsonObject(text, locale);

    final parsedName = (decoded['name'] as String? ?? '').trim();
    final parsedDescription = (decoded['description'] as String? ?? '').trim();
    final calories = _toNonNegativeDouble(decoded['calories']).round();
    if (calories <= 0) {
      throw GeminiRecipeException(_messages(locale).activityAiEstimateFailed);
    }

    return ActivityAiDraft(
      name: parsedName.isEmpty ? normalized : parsedName,
      description: parsedDescription.isEmpty ? normalized : parsedDescription,
      // Guardrails for unrealistic outputs from model.
      calories: calories.clamp(30, 2500),
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
  }) async {
    final apiKey = (apiKeyOverride ?? _resolveApiKey()).trim();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiKeyMissingError,
      );
    }

    http.Response? lastErrorResponse;
    for (final model in _models) {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          ...body,
          'model': model,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      lastErrorResponse = response;
      if ((response.statusCode == 403 || response.statusCode == 404) &&
          model != _models.last) {
        continue;
      }
      throw GeminiRecipeException(_buildHttpErrorMessage(response, locale));
    }

    if (lastErrorResponse != null) {
      throw GeminiRecipeException(
          _buildHttpErrorMessage(lastErrorResponse, locale));
    }
    throw GeminiRecipeException(
      _messages(locale).aiNoResponseError,
    );
  }

  String _resolveApiKey() {
    const groqFromDefine = String.fromEnvironment('GROQ_API_KEY');
    const legacyFromDefine = String.fromEnvironment('GEMINI_API_KEY');

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

  GeminiRecipeDraft _draftFromDecodedJson(
    Map<String, dynamic> decoded, {
    required String fallbackDescription,
    String? locale,
  }) {
    final rawName = (decoded['name'] as String? ?? '').trim();
    final rawDescription = (decoded['description'] as String? ?? '').trim();
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
      icon:
          _resolveDraftIcon(rawIconName, rawName, rawDescription, ingredients),
      ingredients: ingredients,
      nutrients: nutrients,
    );
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

  bool _hasExplicitYieldOrVolumeInfo(String sourceText) {
    final text = sourceText.toLowerCase();

    final explicitAmount = RegExp(
      r'\b\d+(?:[\.,]\d+)?\s*(?:порц|порци|serv|serving|г|гр|kg|кг|ml|мл|l|л|литр|літр)\b',
      caseSensitive: false,
    );
    if (explicitAmount.hasMatch(text)) return true;

    final phrases = [
      'на двоих',
      'на троих',
      'for two',
      'for three',
      'для компании',
      'на семью',
      'для сім',
    ];
    return _containsAny(text, phrases);
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
  final IconData icon;
  final List<RecipeIngredient> ingredients;
  final Map<String, double> nutrients;

  const GeminiRecipeDraft({
    required this.name,
    required this.description,
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
