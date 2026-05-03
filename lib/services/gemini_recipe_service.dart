import 'usda_food_data_service.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  String _lang() {
    final code = ui.PlatformDispatcher.instance.locale.languageCode;
    if (code == 'ru' || code == 'uk' || code == 'en') {
      return code;
    }
    return 'en';
  }

  String _msg({
    required String ru,
    required String uk,
    required String en,
  }) {
    final lang = _lang();
    if (lang == 'ru') return ru;
    if (lang == 'uk') return uk;
    return en;
  }

  String _languageInstruction() {
    return _msg(
      ru: 'Язык ответа: русский.',
      uk: 'Мова відповіді: українська.',
      en: 'Response language: English.',
    );
  }

  Future<GeminiRecipeDraft> generateRecipeFromDescription({
    required String description,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Введите описание блюда.',
          uk: 'Введіть опис страви.',
          en: 'Please enter a dish description.',
        ),
      );
    }

    final prompt = '''
You are a culinary assistant.
${_languageInstruction()}
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
    {"name": "...", "quantity": 100, "unit": "g"}
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
- quantity as a number >= 0.
- unit as a short string like: g, ml, pcs, tbsp, tsp.
- nutrients as numbers only >= 0.
- If exact data is unavailable, provide a realistic estimate.
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload);
    final decoded = _decodeJsonObject(text);
    return _draftFromDecodedJson(decoded,
        fallbackDescription: normalizedDescription);
  }

  Future<GeminiRecipeDraft> generateRecipeFromPhoto({
    required Uint8List imageBytes,
    required String imageMimeType,
    String description = '',
  }) async {
    if (imageBytes.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Добавьте фото блюда.',
          uk: 'Додайте фото страви.',
          en: 'Please add a dish photo.',
        ),
      );
    }

    final normalizedDescription = description.trim();
    final textPrompt = '''
You are a culinary assistant and food expert.
${_languageInstruction()}
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
    {"name": "...", "quantity": 100, "unit": "g"}
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
- quantity as a number >= 0. If needed, quantity >= 0.0001 (for spices, supplements, etc.).
   If given in pieces, estimate the weight of one piece based on reference tables or common sense (e.g., average apple ~150 g, average egg ~50 g). If given in milliliters, estimate weight based on product density (e.g., 1 ml water ~ 1 g, 1 ml oil ~ 0.9 g). If weight cannot be precisely estimated, provide a realistic estimate based on similar products.
- unit as a short string like: g, mg, kg, pcs, pack, package, l, ml, tsp, tbsp, cup.
- nutrients as numbers only >= 0. If needed, values >= 0.0001 (for micronutrients, vitamins, supplements, etc.) are allowed.
- If exact data is unavailable, provide a realistic estimate.
- If exact composition cannot be determined, estimate by analogy with typical products of this type.
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload);
    final decoded = _decodeJsonObject(text);
    return _draftFromDecodedJson(decoded,
        fallbackDescription: normalizedDescription);
  }

  Future<Map<String, double>> estimateNutrients({
    required String recipeName,
    required String recipeDescription,
    required List<RecipeIngredient> ingredients,
  }) async {
    if (ingredients.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Добавьте хотя бы один ингредиент.',
          uk: 'Додайте хоча б один інгредієнт.',
          en: 'Please add at least one ingredient.',
        ),
      );
    }

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Не найден ключ Groq. Добавьте GROQ_API_KEY в .env или передайте --dart-define=GROQ_API_KEY=... при запуске.',
          uk: 'Ключ Groq не знайдено. Додайте GROQ_API_KEY у .env або передайте --dart-define=GROQ_API_KEY=... під час запуску.',
          en: 'Groq key not found. Add GROQ_API_KEY to .env or pass --dart-define=GROQ_API_KEY=... at launch.',
        ),
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
      final searchResults = await usdaService.searchProducts(ingredient.name);
      if (searchResults.isNotEmpty) {
        final product =
            await usdaService.getProductInfo(searchResults.first['fdcId']);
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
    }

    final prompt = '''
  You are a nutrition assistant.
  ${_languageInstruction()}
  Estimate the nutritional value of the recipe based on the ingredient list and their quantities. You may also use your understanding of the dish description and ingredients to infer nutrients not listed explicitly, estimating by analogy with typical dishes of this type.
  For each ingredient, use nutritional data from open databases (e.g., USDA, FatSecret, Open Food Facts, etc.) rather than making up values.

  Important rule: USDA data is given per 100 g of each ingredient. To calculate per serving, scale proportionally by the ingredient weight in the recipe.
  IMPORTANT: Final nutrient values must be calculated for the entire serving (summing all ingredients scaled by their weight), NOT per 100 g!

  Example: if the recipe has 150 g of chicken, and factsSection shows 20 g protein per 100 g, then for 150 g of chicken — 30 g protein (20 * 1.5).

  Here is the nutritional table (per 100 g) for each ingredient in JSON format:
  ${factsJson.isNotEmpty ? jsonEncode(factsJson) : '{}'}
  Recipe:
  - Name: ${recipeName.trim().isEmpty ? 'Untitled' : recipeName.trim()}
  - Description: ${recipeDescription.trim().isEmpty ? '—' : recipeDescription.trim()}
  - Ingredients:
  $ingredientsText
  
  Ingredients may be in various units (grams, milliliters, pieces, etc.). Convert them to grams for nutrient calculation. If given in pieces, estimate the weight of one piece using reference tables or common sense (e.g., average apple ~150 g, average egg ~50 g). If given in milliliters, estimate weight based on product density (e.g., 1 ml water ~ 1 g, 1 ml oil ~ 0.9 g). If weight cannot be precisely estimated, provide a realistic estimate based on similar products.
  Use the formula for calculating nutrients per serving: weight × (nutrient per 100 g) / 100. For example, if the recipe has 150 g chicken and the table shows 20 g protein per 100 g, then 150 g chicken has 30 g protein (20 * 1.5).
  Calorie formula: calories = (protein * 4) + (carbs * 4) + (fat * 9). If calorie data is missing from the tables, estimate calories from macros and sum across all ingredients.
  Reply with ONLY a JSON object with keys: ${nutrientKeys.join(', ')} (numbers only, double, no units). If unable — return empty object {}. Do not add any explanations, lists, markdown, or text before or after the JSON.

  Units:
  - calories: kcal
  - protein, carbs, fat, fiber, sugar, saturated_fat, polyunsaturated_fat, monounsaturated_fat, trans_fat: grams
  - cholesterol, sodium, potassium, calcium, iron, vitamin_c: milligrams
  - vitamin_a, vitamin_d: micrograms

  If exact data is unavailable, provide a realistic estimate based on similar products. Negative values are not allowed.
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload);
    final decoded = _decodeJsonObject(text);

    final normalized = <String, double>{};
    for (final key in nutrientKeys) {
      normalized[key] = _toNonNegativeDouble(decoded[key]);
    }
    return normalized;
  }

  Future<String> generateStatsReport({
    required String periodLabel,
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
${_languageInstruction()}
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
    final text = _extractText(payload).trim();
    if (text.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Нейросеть вернула пустой отчет.',
          uk: 'Нейромережа повернула порожній звіт.',
          en: 'The AI returned an empty report.',
        ),
      );
    }
    return text;
  }

  Future<DailyGoalsDraft> generateDailyGoals({
    required UserProfile profile,
  }) async {
    final prompt = '''
You are a nutritionist and fitness consultant.
${_languageInstruction()}
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
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload);
    final decoded = _decodeJsonObject(text);

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

  Future<http.Response> _requestWithFallback({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
  }) async {
    final apiKey = (apiKeyOverride ?? _resolveApiKey()).trim();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Не найден ключ Groq. Добавьте GROQ_API_KEY в .env или передайте --dart-define=GROQ_API_KEY=... при запуске.',
          uk: 'Ключ Groq не знайдено. Додайте GROQ_API_KEY у .env або передайте --dart-define=GROQ_API_KEY=... під час запуску.',
          en: 'Groq key not found. Add GROQ_API_KEY to .env or pass --dart-define=GROQ_API_KEY=... at launch.',
        ),
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
      throw GeminiRecipeException(_buildHttpErrorMessage(response));
    }

    if (lastErrorResponse != null) {
      throw GeminiRecipeException(_buildHttpErrorMessage(lastErrorResponse));
    }
    throw GeminiRecipeException(
      _msg(
        ru: 'Не удалось получить ответ от Groq.',
        uk: 'Не вдалося отримати відповідь від Groq.',
        en: 'Failed to get a response from Groq.',
      ),
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
        ingredients.add(
          RecipeIngredient(
            name: name,
            quantity: quantity,
            unit: unit,
          ),
        );
      }
    }

    if (ingredients.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Не удалось получить ингредиенты из ответа Groq. Уточните описание и попробуйте снова.',
          uk: 'Не вдалося отримати інгредієнти з відповіді Groq. Уточніть опис і спробуйте ще раз.',
          en: 'Could not extract ingredients from the Groq response. Clarify the description and try again.',
        ),
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
      name: rawName.isEmpty
          ? _msg(ru: 'Новое блюдо', uk: 'Нова страва', en: 'New dish')
          : rawName,
      description:
          rawDescription.isEmpty ? fallbackDescription : rawDescription,
      icon:
          _resolveDraftIcon(rawIconName, rawName, rawDescription, ingredients),
      ingredients: ingredients,
      nutrients: nutrients,
    );
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

    if (haystack.contains('коф') ||
        haystack.contains('латте') ||
        haystack.contains('капуч')) {
      return RecipeLoader.getIcon('coffee');
    }
    if (haystack.contains('суп') || haystack.contains('бульон')) {
      return RecipeLoader.getIcon('soup_kitchen');
    }
    if (haystack.contains('пиц')) {
      return RecipeLoader.getIcon('local_pizza');
    }
    if (haystack.contains('морож') || haystack.contains('ice')) {
      return RecipeLoader.getIcon('icecream');
    }
    if (haystack.contains('торт') ||
        haystack.contains('пирож') ||
        haystack.contains('cake')) {
      return RecipeLoader.getIcon('cake');
    }
    if (haystack.contains('печень') || haystack.contains('cookie')) {
      return RecipeLoader.getIcon('cookie');
    }
    if (haystack.contains('донат') || haystack.contains('пончик')) {
      return RecipeLoader.getIcon('donut_large');
    }
    if (haystack.contains('рис') ||
        haystack.contains('плов') ||
        haystack.contains('боул')) {
      return RecipeLoader.getIcon('rice_bowl');
    }
    if (haystack.contains('яйц') || haystack.contains('омлет')) {
      return RecipeLoader.getIcon('egg');
    }
    if (haystack.contains('кебаб') || haystack.contains('шаур')) {
      return RecipeLoader.getIcon('kebab_dining');
    }
    if (haystack.contains('смузи') || haystack.contains('коктейл')) {
      return RecipeLoader.getIcon('blender');
    }

    return RecipeLoader.getIcon('restaurant');
  }

  String _buildHttpErrorMessage(http.Response response) {
    final code = response.statusCode;
    final apiMessage = _extractApiErrorMessage(response.body);

    if (code == 403) {
      return _msg(
        ru: 'Groq вернул 403 (доступ запрещен). Проверьте GROQ_API_KEY и ограничения доступа.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}',
        uk: 'Groq повернув 403 (доступ заборонено). Перевірте GROQ_API_KEY та обмеження доступу.${apiMessage.isEmpty ? '' : ' Деталі: $apiMessage'}',
        en: 'Groq returned 403 (forbidden). Check GROQ_API_KEY and access restrictions.${apiMessage.isEmpty ? '' : ' Details: $apiMessage'}',
      );
    }
    if (code == 401) {
      return _msg(
        ru: 'Groq вернул 401 (неавторизован). Проверьте корректность GROQ_API_KEY.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}',
        uk: 'Groq повернув 401 (неавторизовано). Перевірте коректність GROQ_API_KEY.${apiMessage.isEmpty ? '' : ' Деталі: $apiMessage'}',
        en: 'Groq returned 401 (unauthorized). Check GROQ_API_KEY.${apiMessage.isEmpty ? '' : ' Details: $apiMessage'}',
      );
    }
    if (code == 429) {
      return _msg(
        ru: 'Groq вернул 429 (лимит запросов). Попробуйте чуть позже.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}',
        uk: 'Groq повернув 429 (ліміт запитів). Спробуйте трохи пізніше.${apiMessage.isEmpty ? '' : ' Деталі: $apiMessage'}',
        en: 'Groq returned 429 (rate limit). Please try again later.${apiMessage.isEmpty ? '' : ' Details: $apiMessage'}',
      );
    }

    return _msg(
      ru: 'Groq вернул ошибку ($code).${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}',
      uk: 'Groq повернув помилку ($code).${apiMessage.isEmpty ? '' : ' Деталі: $apiMessage'}',
      en: 'Groq returned an error ($code).${apiMessage.isEmpty ? '' : ' Details: $apiMessage'}',
    );
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

  String _extractText(Map<String, dynamic> payload) {
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Пустой ответ от Groq.',
          uk: 'Порожня відповідь від Groq.',
          en: 'Empty response from Groq.',
        ),
      );
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Неожиданный формат ответа Groq.',
          uk: 'Неочікуваний формат відповіді Groq.',
          en: 'Unexpected Groq response format.',
        ),
      );
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Не удалось прочитать ответ Groq.',
          uk: 'Не вдалося прочитати відповідь Groq.',
          en: 'Failed to read Groq response.',
        ),
      );
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw GeminiRecipeException(
        _msg(
          ru: 'Groq вернул пустой текст.',
          uk: 'Groq повернув порожній текст.',
          en: 'Groq returned empty text.',
        ),
      );
    }
    return content;
  }

  Map<String, dynamic> _decodeJsonObject(String text) {
    final trimmed = text.trim();
    debugPrint('[Groq raw response]:\n$trimmed');
    // 1. Прямая попытка
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) {
        return direct;
      }
    } catch (_) {}

    // 2. Search for the first {...} block (even if there is markdown)
    final regExp = RegExp(r'\{[\s\S]*?\}', multiLine: true);
    final matches = regExp.allMatches(trimmed);
    for (final match in matches) {
      final candidate = match.group(0);
      if (candidate != null) {
        try {
          final parsed = jsonDecode(candidate);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        } catch (_) {}
      }
    }

    // 3. User-facing error message
    throw GeminiRecipeException(
      _msg(
        ru: 'Не удалось разобрать JSON из ответа нейросети.\n\nПроверьте список ингредиентов или попробуйте еще раз. Если ошибка повторяется, попробуйте переформулировать ингредиенты (например, заменить экзотические продукты на более распространённые) или изменить их написание.',
        uk: 'Не вдалося розібрати JSON з відповіді нейромережі.\n\nПеревірте список інгредієнтів або спробуйте ще раз. Якщо помилка повторюється, переформулюйте інгредієнти (наприклад, замініть екзотичні продукти на більш поширені) або змініть їх написання.',
        en: 'Could not parse JSON from the AI response.\n\nCheck the ingredient list and try again. If the error repeats, rephrase ingredients (for example, replace exotic products with more common ones) or change spelling.',
      ),
    );
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

class GeminiRecipeException implements Exception {
  final String message;

  const GeminiRecipeException(this.message);

  @override
  String toString() => message;
}
