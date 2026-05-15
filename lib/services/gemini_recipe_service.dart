import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nutri_log/l10n/app_localizations.dart';

import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'notification_settings_service.dart';
import 'ai_error_log_service.dart';
import 'recipe_loader.dart';
import 'dart:ui' as ui;

class GeminiRecipeService {
  static Future<void>? _globalRequestLock;
  static DateTime? _rateLimitResetTime;

  static const List<String> _geminiModels = [
    NotificationSettings.geminiModelDefault,
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
    final code = _languageCode(locale);
    final languageName = switch (code) {
      'ru' => 'Russian',
      'uk' => 'Ukrainian',
      _ => 'English',
    };
    return 'CRITICAL: ALL your descriptive text, reasons, advice, and any fields containing strings MUST be written EXCLUSIVELY in $languageName. Do NOT use any other language under any circumstances.';
  }

  Map<String, dynamic> _getRecipeSchema() {
    final nutrientProps = <String, dynamic>{};
    for (final key in nutrientKeys) {
      nutrientProps[key] = {'type': 'number'};
    }

    return {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'description': {'type': 'string'},
        'clarification': {'type': 'string'},
        'healthAdvice': {'type': 'string'},
        'icon': {'type': 'string'},
        'ingredients': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'quantity': {'type': 'number'},
              'unit': {'type': 'string'},
              'ambiguous': {'type': 'boolean'},
            },
            'required': ['name', 'quantity', 'unit', 'ambiguous'],
          },
        },
        'nutrients': {
          'type': 'object',
          'properties': nutrientProps,
          'required': nutrientKeys,
        },
      },
      'required': [
        'name',
        'description',
        'clarification',
        'healthAdvice',
        'icon',
        'ingredients',
        'nutrients'
      ],
    };
  }

  Map<String, dynamic> _getNutrientEstimationSchema() {
    final props = <String, dynamic>{};
    for (final key in nutrientKeys) {
      props[key] = {'type': 'number'};
    }
    props['healthAdvice'] = {'type': 'string'};

    return {
      'type': 'object',
      'properties': props,
      'required': [...nutrientKeys, 'healthAdvice'],
    };
  }

  Map<String, dynamic> _getNutrientsOnlySchema() {
    final nutrientProps = <String, dynamic>{};
    for (final key in nutrientKeys) {
      nutrientProps[key] = {'type': 'number'};
    }
    return {
      'type': 'object',
      'properties': nutrientProps,
      'required': nutrientKeys,
    };
  }

  Map<String, dynamic> _getModerationSchema() {
    return {
      'type': 'object',
      'properties': {
        'approved': {'type': 'boolean'},
        'reason': {'type': 'string'},
        'fixSuggestions': {
          'type': 'string',
          'description': 'Suggestions to fix the recipe if not approved'
        },
        'healthAdvice': {
          'type': 'string',
          'description': 'Medical warnings or advice based on user health context'
        }
      },
      'required': ['approved', 'reason', 'fixSuggestions', 'healthAdvice']
    };
  }

  Map<String, dynamic> _getDailyGoalsSchema() {
    return {
      'type': 'object',
      'properties': {
        'calorieGoal': {'type': 'integer'},
        'proteinGoal': {'type': 'integer'},
        'fatGoal': {'type': 'integer'},
        'carbsGoal': {'type': 'integer'},
        'waterGoal': {'type': 'integer'},
        'stepsGoal': {'type': 'integer'},
      },
      'required': [
        'calorieGoal',
        'proteinGoal',
        'fatGoal',
        'carbsGoal',
        'waterGoal',
        'stepsGoal'
      ],
    };
  }

  Map<String, dynamic> _getActivitySchema() {
    return {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'description': {'type': 'string'},
        'calories': {'type': 'integer'},
      },
      'required': ['name', 'description', 'calories'],
    };
  }

  Map<String, dynamic> _getStatsReportSchema() {
    return {
      'type': 'object',
      'properties': {
        'overview': {'type': 'string'},
        'recommendations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'when': {'type': 'string'},
              'action': {'type': 'string'},
              'recipeName': {'type': 'string'},
            },
            'required': ['when', 'action', 'recipeName'],
          },
        },
      },
      'required': ['overview', 'recommendations'],
    };
  }

  Map<String, dynamic> _getNutrientsRecheckSchema() {
    return {
      'type': 'object',
      'properties': {
        'approved': {'type': 'boolean'},
        'reason': {'type': 'string'},
        'nutrients': _getNutrientsOnlySchema(),
      },
      'required': ['approved', 'reason', 'nutrients'],
    };
  }

  Future<GeminiRecipeDraft> generateRecipeFromDescription({
    required String description,
    String? locale,
    String healthConditions = '',
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
Note: The description may be from voice dictation, so it might lack punctuation, contain typos, or have unusual grammar. Parse it carefully to extract the intended dish name and ingredients.

Dish description:
$normalizedDescription

${healthConditions.isNotEmpty ? 'USER HEALTH CONTEXT: $healthConditions\nNote: Do NOT modify the requested recipe. Generate it exactly as described. If any part of the recipe is unsuitable for the user\'s health conditions, provide a clear medical warning or advice in the "healthAdvice" field.' : ''}

Reply ONLY in JSON format, without explanations, markdown, or any text before or after the JSON. Ensure the output strictly follows the requested structure.

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
- If exact data is unavailable, provide a realistic estimate or leave as zero if completely unknown.
- For each ingredient, set "ambiguous": true if the preparation method or form is unclear and significantly affects nutrition (e.g., boiled vs dry pasta, cereal with milk vs dry, raw vs cooked meat). Set "ambiguous": false otherwise.
- You CAN add common ingredients like water, oil, salt, or sugar if they are logically required for cooking the described dish.
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
        'top_p': 1,
        'stream': false,
        'enable_tools': true,
        'thinking_level': 'MEDIUM',
        'response_schema': _getRecipeSchema(),
      },
      locale: locale,
      featureName: 'Recipe From Description',
    );
    final textDraft = _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
    return textDraft;
  }

  Future<GeminiRecipeDraft> generateRecipeFromPhoto({
    required Uint8List imageBytes,
    required String imageMimeType,
    String description = '',
    String? locale,
    String healthConditions = '',
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

${healthConditions.isNotEmpty ? 'USER HEALTH CONTEXT: $healthConditions\nNote: Do NOT modify the ingredients seen or requested. Generate the recipe as is. If any part contradicts the user\'s health conditions, provide a clear medical warning or advice in the "healthAdvice" field.' : ''}

Reply ONLY in JSON format, without explanations, markdown, or any text before or after the JSON. Ensure the output strictly follows the requested structure.

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
- If exact data is unavailable, provide a realistic estimate or leave as zero if completely unknown.
- If exact composition cannot be determined, estimate by analogy with typical products of this type.
- You CAN add common ingredients like water, oil, salt, or sugar if they are logically required for cooking the described dish or product type.
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
        'top_p': 1,
        'stream': false,
        'response_schema': _getRecipeSchema(),
      },
      locale: locale,
    );
    final photoDraft = _draftFromDecodedJson(
      decoded,
      fallbackDescription: normalizedDescription,
      locale: locale,
    );
    return photoDraft;
  }

  Future<GeminiRecipeDraft> generateRecipeFromBarcode({
    required Map<String, dynamic> productData,
    String? locale,
    String healthConditions = '',
  }) async {
    final productName = productData['product_name'] ?? '';
    final brands = productData['brands'] ?? '';
    final categories = productData['categories'] ?? '';
    final ingredientsText = productData['ingredients_text'] ?? '';
    final nutrients = productData['nutriments'] ?? {};

    final prompt = '''
You are a food database expert.
${_languageInstruction(locale)}
Convert the following raw product data from OpenFoodFacts into a structured recipe draft.
Product: $productName
Brands: $brands
Categories: $categories
Ingredients: $ingredientsText
Raw Nutriments: ${jsonEncode(nutrients)}

${healthConditions.isNotEmpty ? 'USER HEALTH CONTEXT: $healthConditions\nNote: Do NOT modify the product data. If this product is unsuitable for the user\'s health conditions, provide a clear medical warning or advice in the "healthAdvice" field.' : ''}

Reply ONLY in JSON format.
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
    "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "fiber": 0, "sugar": 0,
    "saturated_fat": 0, "polyunsaturated_fat": 0, "monounsaturated_fat": 0, "trans_fat": 0,
    "cholesterol": 0, "sodium": 0, "potassium": 0, "vitamin_a": 0, "vitamin_c": 0,
    "vitamin_d": 0, "calcium": 0, "iron": 0
  }
}

Rules:
- name: combine product name and brand.
- description: brief summary of what it is.
- nutrients: use data from "Raw Nutriments" if available. Note that OpenFoodFacts often provides values per 100g. If the package size is known (e.g. 500ml), calculate for the full package. If nutrients are completely unknown, leave them as zero.
- icon: pick from ${_allowedIconNames.join(', ')}.
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1,
        'enable_tools': true,
        'thinking_level': 'MEDIUM',
        'response_schema': _getRecipeSchema(),
      },
      locale: locale,
    );

    final draft = _draftFromDecodedJson(
      decoded,
      fallbackDescription: productName,
      locale: locale,
    );
    return draft;
  }


  Future<NutrientEstimationResult> estimateNutrients({
    required String recipeName,
    required String recipeDescription,
    required List<RecipeIngredient> ingredients,
    String clarification = '',
    String? locale,
    String healthConditions = '',
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

    final apiKey = _resolveGeminiApiKey();
    if (apiKey.isEmpty) {
      throw GeminiRecipeException(
        _messages(locale).aiKeyMissingError,
      );
    }

    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\\n');

    final prompt = '''
  You are a professional nutritionist specializing in precise per-serving nutritional calculations.
  ${_languageInstruction(locale)}

  TASK: Calculate the exact total nutritional value for ONE SERVING (for 1 person) of the recipe described below, AND provide medical advice based on the user's health conditions.

  CRITICAL RULES:
  ...
  7. If any part of the recipe (ingredients, preparation) contradicts the USER HEALTH CONTEXT, provide a clear medical warning or advice in the "healthAdvice" field. If everything is safe, you can leave it empty or provide a general positive tip.
  1. The ingredient list below IS the full recipe for ONE PERSON — do NOT divide quantities.
  2. The specified amounts are exactly what goes into this single serving. NEVER question or adjust the quantities — treat them as precise user input.
  4. The Ingredients List is your PRIMARY source for quantities and composition (70% weight).
  5. The recipe NAME, DESCRIPTION, and CLARIFICATION are supporting context (30% weight) for preparation method, specifics, or hidden ingredients not in the list.
     Example: if description says "energy drink", include caffeine-related vitamins even if not in ingredients.
  6. USER CLARIFICATION still provides the final word on "hidden" details (e.g. "fried in lot of oil"), but ingredient amounts must be respected.

  UNIT CONVERSION (to grams):
  - Milliliters: water/juice ≈ 1 g/ml, milk ≈ 1.03 g/ml, oil ≈ 0.9 g/ml, honey ≈ 1.4 g/ml
  - стакан/стак (Russian/Ukrainian glass): usually 200-250 ml. Estimate the volume based on the typical context of the recipe.
  - cup (US): 240 ml.
  - tbsp/столовая ложка: 15 ml. tsp/чайная ложка: 5 ml.
  - Pieces (pcs): apple ≈ 150 g, egg ≈ 55 g, banana ≈ 120 g, orange ≈ 180 g; use common sense for others
  - Pack/package: use the typical standard weight for that product category ONLY when no explicit net weight/volume is provided in name/description

  CALCULATION STEPS:
  1. Convert all ingredient quantities to grams using the rules above.
  2. For each ingredient, look up nutrients per 100 g from USDA / FatSecret / Open Food Facts or your knowledge.
  3. Scale: nutrient_for_ingredient = weight_g × (per_100g_value / 100)
  4. Sum across ALL ingredients to get the total for the serving.
  5. Cross-check: calories ≈ (protein × 4) + (carbs × 4) + (fat × 9). Adjust if off by more than 5%.

  Use your internal knowledge and search tools to determine nutritional reference data per 100 g for each ingredient.

  Recipe details:
  - User clarification (PRIMARY): ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
  ${healthConditions.isNotEmpty ? '- User health context: $healthConditions' : ''}
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
        'temperature': 0.1,
        'enable_tools': true,
        'thinking_level': 'MEDIUM',
        'response_schema': _getNutrientEstimationSchema(),
      },
      apiKeyOverride: apiKey,
      locale: locale,
      featureName: 'Generic Meal Nutrition',
    );

    final String healthAdvice = (decoded['healthAdvice'] as String? ?? '').trim();

    final finalNutrients = <String, double>{};
    for (final key in nutrientKeys) {
      finalNutrients[key] = _toNonNegativeDouble(decoded[key]);
    }

    var localIssue = _validateEstimatedNutrients(
      nutrients: finalNutrients,
      ingredients: ingredients,
      locale: locale,
    );

    if (localIssue != null) {
      final rechecked = await _recheckEstimatedNutrientsWithAi(
        recipeName: recipeName,
        recipeDescription: recipeDescription,
        clarification: clarification,
        ingredientsText: ingredientsText,
        firstPass: finalNutrients,
        locale: locale,
      );

      for (final key in nutrientKeys) {
        finalNutrients[key] = _toNonNegativeDouble(
            rechecked['nutrients']?[key] ?? finalNutrients[key]);
      }

      localIssue = _validateEstimatedNutrients(
        nutrients: finalNutrients,
        ingredients: ingredients,
        locale: locale,
      );
    }

    if (localIssue != null) {
      _applyNutrientsBestEffortFallback(finalNutrients);
      localIssue = _validateEstimatedNutrients(
        nutrients: finalNutrients,
        ingredients: ingredients,
        locale: locale,
      );
    }

    if (localIssue != null) {
      throw GeminiRecipeException(localIssue);
    }

    return NutrientEstimationResult(
      nutrients: finalNutrients,
      healthAdvice: healthAdvice,
    );
  }

  Future<String> generateMedicalAdvice({
    required String recipeName,
    required String recipeDescription,
    required List<RecipeIngredient> ingredients,
    required Map<String, double> nutrients,
    String healthConditions = '',
    String clarification = '',
    String? locale,
  }) async {
    if (healthConditions.isEmpty) return '';

    final apiKey = _resolveGeminiApiKey();
    if (apiKey.isEmpty) return '';

    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\\n');

    final prompt = '''
    Analyze the following recipe and provide professional recommendations as a team of experts.
    
    CRITICAL INSTRUCTIONS:
    1. ONLY provide advice that is RELEVANT to the actual ingredients in this recipe and the user's health conditions.
    2. DO NOT suggest excluding or adding ingredients that are NOT related to the recipe or health conditions (e.g., do not mention "excluding cottage cheese" if there is no dairy in the recipe and no dairy allergy).
    3. If an expert (Doctor, Dietitian, or Trainer) has no specific advice or warnings for this recipe, they MUST return an EMPTY STRING.
    4. Provide strictly 1-2 concise sentences per expert.

    EXPERTS:
    - MEDICAL DOCTOR: Focus on safety/risks regarding the user's conditions.
    - PROFESSIONAL DIETITIAN: Focus on nutritional balance and diet fit.
    - FITNESS TRAINER: Focus on energy, recovery, and active lifestyle suitability.

  User health conditions: ${healthConditions.isEmpty ? 'None specified' : healthConditions}.
  
  Recipe Name: $recipeName
  Description: $recipeDescription
  Preparation Details/Clarification: $clarification
  Ingredients: $ingredientsText
  Nutrients: ${nutrients.entries.map((e) => '${e.key}: ${e.value}').join(', ')}

  Rules:
  1. ${_languageInstruction(locale)}
  2. Return ONLY JSON.
  ''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1,
        'response_schema': {
          'type': 'object',
          'properties': {
            'doctor': {'type': 'string'},
            'dietitian': {'type': 'string'},
            'trainer': {'type': 'string'},
          },
          'required': ['doctor', 'dietitian', 'trainer'],
        },
      },
      apiKeyOverride: apiKey,
      locale: locale,
      featureName: 'Expert Advice',
    );

    // Convert to a single formatted string for backward compatibility or parseable format
    final doctor = _cleanupAdvice(decoded['doctor'] as String? ?? '');
    final dietitian = _cleanupAdvice(decoded['dietitian'] as String? ?? '');
    final trainer = _cleanupAdvice(decoded['trainer'] as String? ?? '');

    if (doctor.isEmpty && dietitian.isEmpty && trainer.isEmpty) return '';

    return '[[DOCTOR]] $doctor [[DIETITIAN]] $dietitian [[TRAINER]] $trainer';
  }

  String _cleanupAdvice(String advice) {
    if (advice.isEmpty || advice.toLowerCase() == 'none' || advice.toLowerCase() == 'none.') return '';
    // If AI accidentally returns JSON-like structure in a string field, try to extract text
    if (advice.contains('{"') || advice.contains('": "')) {
      try {
        final decoded = jsonDecode(advice);
        if (decoded is Map) {
          return decoded.values.join(' ').trim();
        }
      } catch (_) {
        // Not JSON, or malformed, proceed with regex cleanup
      }
      return advice.replaceAll(RegExp(r'\{"?[^"]+"?:\s*"'), '').replaceAll(RegExp(r'"\s*\}?'), '').trim();
    }
    return advice;
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

  Future<Map<String, dynamic>> _recheckEstimatedNutrientsWithAi({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required String ingredientsText,
    required Map<String, double> firstPass,
    String? locale,
  }) async {
    final prompt = '''
You are a nutrition calculation corrector and food state interpreter.
${_languageInstruction(locale)}

Your task is to IMPROVE the candidate nutrition values using your knowledge or search tools as hints.
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
- стакан/стак (Russian/Ukrainian glass): usually 200-250 ml. Estimate the volume based on the typical context of the recipe.
- cup (US): 240 ml.
- tbsp/ст.л.: 15 ml. tsp/ч.л.: 5 ml.

INPUT:
- clarification (HIGHEST PRIORITY for food state): ${clarification.trim().isEmpty ? '(not provided)' : clarification.trim()}
- recipe name: ${recipeName.trim().isEmpty ? 'Untitled' : recipeName.trim()}
- recipe description: ${recipeDescription.trim().isEmpty ? '(not provided)' : recipeDescription.trim()}
- ingredients:
$ingredientsText



Candidate nutrients JSON (your starting point):
${jsonEncode(firstPass)}

Instructions:
1. First, determine preparation state for each ingredient from clarification → description → name → default assumption (see rules above).
2. Use your knowledge (adjusted for the correct state) as reference to spot obvious errors in nutrient density (e.g. calories per 100g off by 2x or more).
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
          'response_schema': _getNutrientsRecheckSchema(),
        },
        locale: locale,
        featureName: 'Nutrition Correction',
      );
      final approved = decoded['approved'] == true;
      final reason = (decoded['reason'] as String? ?? '').trim();
      final decodedNutrients = decoded['nutrients'] as Map<String, dynamic>?;

      final correctedNutrients = <String, double>{};
      if (decodedNutrients != null) {
        for (final key in nutrientKeys) {
          correctedNutrients[key] = _toNonNegativeDouble(decodedNutrients[key]);
        }
      }

      return {
        'approved': approved,
        'reason': reason,
        'nutrients':
            correctedNutrients.isNotEmpty ? correctedNutrients : firstPass,
      };
    } catch (_) {
      return {
        'approved': true,
        'reason': '',
        'nutrients': firstPass,
      };
    }
  }

  Future<DonateRecipeModerationResult> moderateRecipeForPublic({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required List<RecipeIngredient> ingredients,
    Map<String, double>? nutrients,
    String? locale,
    String healthConditions = '',
  }) async {
    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\n');

    final prompt = '''
You are a content moderation assistant.
${_languageInstruction(locale)}

Task: quick safety check for a "Public" recipe.
Reject if:
- contains profanity, insults, or inappropriate/offensive language;
- contains illegal content or clear spam;
- the name or description is a random sequence of characters (gibberish);
- the recipe name does not represent a real dish or product;
- the name is too short and meaningless (e.g. "a", "asdf").

- minor typos or grammatical errors;
- simple but real dishes (e.g. "Boiled Egg").

CRITICAL INSTRUCTIONS FOR healthAdvice:
1. ONLY provide advice that is RELEVANT to the actual ingredients in this recipe and the user's health conditions.
2. DO NOT suggest excluding or adding ingredients that are NOT related to the recipe or health conditions (e.g., do not mention "excluding cottage cheese" if there is no dairy in the recipe and no dairy allergy).
3. If there is no specific advice or warnings for this recipe, return an EMPTY STRING for "healthAdvice".

Recipe:
- name: ${recipeName.trim()}
- description: ${recipeDescription.trim()}
- ingredients:
$ingredientsText
- USER HEALTH CONTEXT: ${healthConditions.isEmpty ? 'not specified' : healthConditions}

Return ONLY JSON:
{
  "approved": true|false,
  "reason": "short explanation",
  "fixSuggestions": "what to improve if rejected",
  "healthAdvice": "medical advice if any"
}
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0,
        'response_schema': _getModerationSchema(),
      },
      locale: locale,
      featureName: 'Public Moderation',
    );

    return DonateRecipeModerationResult(
      approved: decoded['approved'] == true,
      reason: (decoded['reason'] as String? ?? '').trim(),
      fixSuggestions: (decoded['fixSuggestions'] as String? ?? '').trim(),
      healthAdvice: (decoded['healthAdvice'] as String? ?? '').trim(),
      confidence: 1.0,
      flags: const [],
    );
  }

  Future<DonateRecipeModerationResult> validateRecipeForCommunityDonation({
    required String recipeName,
    required String recipeDescription,
    required String clarification,
    required List<RecipeIngredient> ingredients,
    Map<String, double>? nutrients,
    String? locale,
    String healthConditions = '',
  }) async {
    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\n');

    final prompt = '''
Task: evaluate if this recipe is suitable for the community database.
${_languageInstruction(locale)}
Reject if:
- name is offensive, completely nonsensical, or gibberish;
- name or description is a random sequence of characters;
- ingredients are missing, clearly fake, or contain non-food items;
- contains profanity or inappropriate content;
- the dish is not a real food item.

- cooking instructions (steps) are missing;
- it is a simple dish (e.g. "Apple").

CRITICAL INSTRUCTIONS FOR healthAdvice:
1. ONLY provide advice that is RELEVANT to the actual ingredients in this recipe and the user's health conditions.
2. DO NOT suggest excluding or adding ingredients that are NOT related to the recipe or health conditions.
3. If there is no specific advice or warnings for this recipe, return an EMPTY STRING for "healthAdvice".

Recipe:
- name: ${recipeName.trim()}
- description: ${recipeDescription.trim()}
- clarification: ${clarification.trim()}
- ingredients:
$ingredientsText
- USER HEALTH CONTEXT: ${healthConditions.isEmpty ? 'not specified' : healthConditions}

Return ONLY JSON:
{
  "approved": true|false,
  "reason": "detailed explanation of decision",
  "fixSuggestions": "specific steps to make it better (e.g. 'Add quantity for water', 'Provide a better name')",
  "healthAdvice": "medical warning if any"
}
''';

    final decoded = await _requestDecodedJsonWithAutoRetry(
      body: {
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.1,
        'response_schema': _getModerationSchema(),
      },
      locale: locale,
      featureName: 'Community Moderation',
    );

    return DonateRecipeModerationResult(
      approved: decoded['approved'] == true,
      reason: (decoded['reason'] as String? ?? '').trim(),
      fixSuggestions: (decoded['fixSuggestions'] as String? ?? '').trim(),
      healthAdvice: (decoded['healthAdvice'] as String? ?? '').trim(),
      confidence: 1.0,
      flags: const [],
    );
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
        'top_p': 1,
        'stream': false,
      },
      locale: locale,
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
    String healthConditions = '',
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
    required List<String> availableRecipeNames,
    required List<String> consumedFoodNames,
    required List<Map<String, dynamic>> previousReports,
  }) async {
    final snackLikelyNeeded = avgCalories < calorieGoal * 0.9 ||
        avgProteinGrams < proteinGoal * 0.9 ||
        avgFiberGrams < 18;

    final topFoodsContext = topFoods
        .take(5)
        .map((f) =>
            '- ${(f['name'] as String? ?? '').trim()} (${((f['count'] as num?) ?? 0).round()} times)')
        .where((line) => !line.startsWith('-  ('))
        .join('\n');

    final recipesContext =
        availableRecipeNames.take(100).map((name) => '- $name').join('\n');

    final consumedContext =
        consumedFoodNames.take(60).map((name) => '- $name').join('\n');

    final snackPriorityContext = snackPriorityRecipes
        .take(4)
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
        previousReports.take(1).toList(growable: false);

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
        previousRecipeNames.take(15).map((name) => '- $name').join('\n');

    final prompt = '''
You are a team of experts: a medical doctor, a professional dietitian, and a fitness trainer.
${_languageInstruction(locale)}
Analyze user progress for the period: $periodLabel.
User name: ${userName.trim().isEmpty ? 'friend' : userName.trim()}
Primary goal type: $goalType
User activity types: ${activityTypes.trim().isEmpty ? 'not specified' : activityTypes.trim()}

${healthConditions.isNotEmpty ? 'CRITICAL HEALTH CONSTRAINTS (MANDATORY): $healthConditions\nNote: All advice and recipe recommendations MUST strictly adhere to these health constraints. Never suggest anything prohibited by these conditions.' : ''}
User context/preferences: ${aiContext.trim().isEmpty ? 'not specified' : aiContext.trim()}
Expert Context (Health/Fitness): ${healthConditions.trim().isEmpty ? 'not specified' : healthConditions.trim()}

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

Actual food/meals consumed by user in this period:
${consumedContext.isEmpty ? '- no consumption data' : consumedContext}

Priority snack recipe candidates (prefer these for snack recommendations if suitable):
${snackPriorityContext.isEmpty ? '- none' : snackPriorityContext}

Previous AI reports memory (use for continuity, avoid repeating same generic advice):
${previousReportsContext.isEmpty ? '- no previous reports' : previousReportsContext}

Previously recommended recipes (prefer continuity when still relevant):
${previousRecommendedRecipesContext.isEmpty ? '- none' : previousRecommendedRecipesContext}

Additional Rules for Recipes:
- If you find a suitable recipe in the "Available recipes in app" list, provide its EXACT name in "recipeName".
- If no suitable recipe exists in the list, but you want to suggest a specific dish, provide its name in "recipeName" and describe it in "action". The app will handle the search.
- Do NOT make up recipe names that are similar to existing ones but not exact; if it's a new suggestion, use its common name.

Task:
1) Create a full, warm and supportive weekly/monthly/yearly analysis (NOT short): 10-16 sentences.
2) Start with personal addressing using the user's name naturally.
3) Mention key achievements and where user is behind goals.
4) Mention what foods/dishes are consumed most often.
5) Give concrete improvement tips for nutrition balance, including snack ideas (for example, vegetables if suitable). Ensure advice respects medical details/conditions.
6) Add practical meal plan recommendations for the next period (what and when to eat) focused on deficits/excesses.
7) If suitable recipes from the list exist, include exact recipe names from the provided list in "recipeName".
8) If no suitable recipe exists in the user's list, suggest ANY common healthy dish (e.g., "Pasta Bolognese", "Greek Salad", "Grilled Chicken with Vegetables") that fits their health profile and nutritional needs. Put its common name in "recipeName" and explain its benefits in "action".
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
18) HEALTH AND SAFETY FILTER (STRICT): Ensure all recommendations, meal tips, and advice strictly exclude any foods, ingredients, or activities that are harmful according to the user's specific Expert Context ($healthConditions). This applies to ALL periods (week, month, year). Never recommend anything that violates these constraints.
18) Recommendations must be coherent with user's goal type and current macro gaps (do not recommend what is already excessive).
19) Dish Composition Analysis: You MUST analyze the detailed nutritional breakdown of the actual dishes consumed (calories, macros, sugar, sodium). If a specific dish the user ate has excessive sodium, high sugar, or inadequate protein, point this out specifically in your overview and suggest adjustments.
20) Write as a personal coach-assistant: warm, motivating, and specific, without generic fluff.
21) Build overview in 3 mini-paragraphs separated by blank lines:
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
      "recipeName": "exact recipe name from provided list or a new suggested dish name"
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
          'response_schema': _getStatsReportSchema(),
        },
        locale: locale,
        featureName: 'Structured Stats Report',
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
- Medical details: ${profile.healthConditions.isEmpty ? 'not specified' : profile.healthConditions}

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
- Consider the user's goal type, activity level, sports, medical details, and additional conditions.
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
          'top_p': 1,
          'stream': false,
          'response_schema': _getDailyGoalsSchema(),
        },
        locale: locale,
        featureName: 'Daily Goals Recommendation',
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
        'top_p': 1,
        'stream': false,
        'response_schema': _getActivitySchema(),
      },
      locale: locale,
      featureName: 'Audio Transcription Activity',
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

  String _resolveGeminiApiKey() {
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    final candidates = [
      dotenv.env['GEMINI_API_KEY'],
      fromDefine,
    ];
    for (final raw in candidates) {
      final key = (raw ?? '').trim();
      if (key.isNotEmpty) return key;
    }
    return '';
  }

  String _resolveGeminiModel(String selectedModel) {
    if (_geminiModels.contains(selectedModel)) return selectedModel;
    return NotificationSettings.geminiModelDefault;
  }

  List<Map<String, dynamic>> _geminiPartsFromMessages(dynamic messages) {
    final parts = <Map<String, dynamic>>[];

    void addText(String text) {
      final normalized = text.trim();
      if (normalized.isEmpty) return;
      parts.add({'text': normalized});
    }

    void addImageUrl(String url) {
      final normalized = url.trim();
      if (normalized.isEmpty) return;
      final dataUrlMatch =
          RegExp(r'^data:([^;]+);base64,(.+)$').firstMatch(normalized);
      if (dataUrlMatch == null) return;
      final mimeType = (dataUrlMatch.group(1) ?? 'image/jpeg').trim();
      final data = (dataUrlMatch.group(2) ?? '').trim();
      if (data.isEmpty) return;
      parts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': data,
        }
      });
    }

    void visit(dynamic value) {
      if (value is String) {
        addText(value);
        return;
      }
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }
      if (value is Map) {
        final type = value['type'];
        if (type == 'text' && value['text'] is String) {
          addText(value['text'] as String);
          return;
        }
        if (type == 'image_url') {
          final imageUrl = value['image_url'];
          if (imageUrl is Map && imageUrl['url'] is String) {
            addImageUrl(imageUrl['url'] as String);
          }
          return;
        }
        if (value['content'] != null) {
          visit(value['content']);
        }
      }
    }

    visit(messages);
    return parts;
  }

  String _extractTextFromGeminiPayload(Map<String, dynamic> payload,
      [String? locale]) {
    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw GeminiRecipeException(_messages(locale).aiEmptyResponseError);
    }
    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw GeminiRecipeException(
          _messages(locale).aiUnexpectedResponseFormatError);
    }
    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw GeminiRecipeException(
          _messages(locale).aiFailedToReadResponseError);
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw GeminiRecipeException(_messages(locale).aiEmptyTextError);
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        final text = (part['text'] as String).trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text);
        }
      }
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) {
      throw GeminiRecipeException(_messages(locale).aiEmptyTextError);
    }
    return result;
  }

  Future<http.Response> _requestWithGemini({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
    String? locale,
    required List<String> models,
    required NotificationSettings settings,
    String featureName = 'AI Request',
  }) async {
    // Wait for active request to finish (Simple Queue)
    while (_globalRequestLock != null) {
      await _globalRequestLock;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (_rateLimitResetTime != null) {
      final wait = _rateLimitResetTime!.difference(DateTime.now());
      if (!wait.isNegative) {
        await Future<void>.delayed(wait);
      }
      _rateLimitResetTime = null;
    }

    final completer = Completer<void>();
    _globalRequestLock = completer.future;

    try {
      final apiKey = apiKeyOverride ?? _resolveGeminiApiKey();
      if (apiKey.isEmpty) {
        throw GeminiRecipeException(_messages(locale).aiKeyMissingError);
      }

      final parts = _geminiPartsFromMessages(body['messages']);
      if (parts.isEmpty) {
        throw GeminiRecipeException(_messages(locale).aiNoResponseError);
      }

      final usesImageInput = _requestUsesImageInput(body);
      http.Response? lastErrorResponse;

      AiErrorLogService.instance.logRequest(
        feature: featureName,
        details:
            usesImageInput ? 'Request contains image' : 'Text only request',
      );

      final systemInstruction = body['system_instruction'] as String?;
      final enableTools = body['enable_tools'] == true;
      final thinkingLevel = body['thinking_level'] as String?;
      final isThinkingModel = models.first.contains('thinking');

      for (final modelName in models) {
        final model = _resolveGeminiModel(modelName);
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final payload = <String, dynamic>{
          'contents': [
            {
              'role': 'user',
              'parts': parts,
            }
          ],
          if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': systemInstruction.trim()}
              ]
            },
          'tools': [
            {'googleSearch': {}},
            if (enableTools) {'codeExecution': <String, dynamic>{}},
          ],
          'generationConfig': {
            'temperature': body['temperature'] ?? 0.2,
            'topP': body['top_p'] ?? 1,
            'maxOutputTokens': settings.aiMaxTokens,
            'responseMimeType': 'application/json',
            if (body['response_schema'] != null)
              'responseSchema': body['response_schema'],
            if (isThinkingModel &&
                thinkingLevel != null &&
                thinkingLevel.trim().isNotEmpty)
              'thinkingConfig': {'thinkingLevel': thinkingLevel.trim()},
          },
        };

        try {
          var request = http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          );

          if (settings.aiTimeoutSeconds > 0) {
            request =
                request.timeout(Duration(seconds: settings.aiTimeoutSeconds));
          }

          final response = await request;

          if (response.statusCode >= 200 && response.statusCode < 300) {
            AiErrorLogService.instance.logSuccess(feature: featureName);

            final decoded = jsonDecode(response.body) as Map<String, dynamic>;
            final text = _extractTextFromGeminiPayload(decoded, locale);
            final syntheticOpenAiPayload = jsonEncode({
              'choices': [
                {
                  'message': {'content': text}
                }
              ]
            });
            return http.Response(
              syntheticOpenAiPayload,
              200,
              headers: const {'content-type': 'application/json'},
            );
          }

          lastErrorResponse = response;

          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'HTTP Error ${response.statusCode}',
            details: response.body,
            statusCode: response.statusCode,
          );

          if (response.statusCode == 429) {
            _rateLimitResetTime =
                DateTime.now().add(const Duration(seconds: 10));
          }
          final isRetryableStatus = response.statusCode == 400 ||
              response.statusCode == 403 ||
              response.statusCode == 404 ||
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500;
          if (isRetryableStatus && modelName != models.last) {
            continue;
          }
          throw GeminiRecipeException(
            _buildHttpErrorMessage(response, locale),
            statusCode: response.statusCode,
          );
        } on TimeoutException catch (e) {
          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'Timeout Error',
            details: e.toString(),
          );
          if (modelName != models.last) continue;
          throw GeminiRecipeException(_messages(locale).aiNoResponseError);
        } on http.ClientException catch (e) {
          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'Network Error',
            details: e.toString(),
          );
          if (modelName != models.last) continue;
          throw GeminiRecipeException(_messages(locale).aiNoResponseError);
        } catch (e) {
          if (e is GeminiRecipeException) rethrow;
          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'Unexpected Error',
            details: e.toString(),
          );
          if (modelName != models.last) continue;
          throw GeminiRecipeException(e.toString());
        }
      }

      if (lastErrorResponse != null) {
        throw GeminiRecipeException(
            _buildHttpErrorMessage(lastErrorResponse, locale),
            statusCode: lastErrorResponse.statusCode);
      }
      throw GeminiRecipeException(_messages(locale).aiNoResponseError);
    } finally {
      _globalRequestLock = null;
      completer.complete();
    }
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

  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  Future<String> _requestStringWithAutoRetry({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
    String? locale,
    String featureName = 'AI Request',
  }) async {
    final settings = await _settingsService.load();
    final maxAttempts = settings.aiRetryAttempts;
    final retryDelay = Duration(seconds: settings.aiRetryDelaySeconds);

    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _requestWithGemini(
          body: body,
          apiKeyOverride: apiKeyOverride,
          locale: locale,
          models: [settings.geminiModel],
          settings: settings,
          featureName: featureName,
        );

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(payload, locale).trim();
        if (text.isEmpty) {
          throw GeminiRecipeException(_messages(locale).aiEmptyTextError);
        }

        return text;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          var currentDelay = retryDelay;
          if (e is GeminiRecipeException && e.statusCode == 429) {
            currentDelay = Duration(seconds: 12 + (attempt * 10));
          }
          await Future<void>.delayed(currentDelay);
        }
      }
    }

    if (lastError is GeminiRecipeException) {
      throw lastError;
    }
    throw GeminiRecipeException(
        '${_messages(locale).aiGeneralError}: ${lastError.toString()}');
  }

  Future<Map<String, dynamic>> _requestDecodedJsonWithAutoRetry({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
    String? locale,
    String featureName = 'AI Request',
  }) async {
    final settings = await _settingsService.load();
    final maxAttempts = settings.aiRetryAttempts;
    final retryDelay = Duration(seconds: settings.aiRetryDelaySeconds);

    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _requestWithGemini(
          body: body,
          locale: locale,
          models: [settings.geminiModel],
          settings: settings,
          featureName: featureName,
        );

        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(payload, locale).trim();
        if (text.isEmpty) {
          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'Empty response text',
            details: response.body,
          );
          throw GeminiRecipeException(_messages(locale).aiEmptyTextError);
        }

        final decoded = _decodeJsonObject(text, locale);
        if (decoded.isEmpty) {
          AiErrorLogService.instance.logError(
            feature: featureName,
            message: 'Empty JSON object received',
            details: text,
          );
          throw GeminiRecipeException(_messages(locale).aiNoResponseError);
        }
        return decoded;
      } catch (e) {
        lastError = e;
        if (attempt < maxAttempts) {
          var currentDelay = retryDelay;
          if (e is GeminiRecipeException && e.statusCode == 429) {
            // Respect 429 rate limits with significantly longer wait
            currentDelay = Duration(seconds: 12 + (attempt * 10));
          }
          await Future<void>.delayed(currentDelay);
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

  GeminiRecipeDraft _draftFromDecodedJson(
    Map<String, dynamic> decoded, {
    required String fallbackDescription,
    String? locale,
  }) {
    final rawName = (decoded['name'] as String? ?? '').trim();
    final rawDescription = (decoded['description'] as String? ?? '').trim();
    final rawClarification = (decoded['clarification'] as String? ?? '').trim();
    final rawHealthAdvice = (decoded['healthAdvice'] as String? ?? '').trim();
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
              locale: locale,
            )
          : rawClarification,
      icon:
          _resolveDraftIcon(rawIconName, rawName, rawDescription, ingredients),
      ingredients: ingredients,
      nutrients: nutrients,
      healthAdvice: rawHealthAdvice,
    );
  }

  String _buildDenseClarificationFallback({
    required String description,
    required List<RecipeIngredient> ingredients,
    String? locale,
  }) {
    final msgs = _messages(locale);
    final normalizedDescription = description.trim();
    final lowerDescription = normalizedDescription.toLowerCase();

    String? inferType() {
      if (_containsAny(lowerDescription, const ['энергет', 'energy drink'])) {
        return msgs.recipeClarificationTypeEnergyDrink;
      }
      if (_containsAny(lowerDescription, const ['газиров', 'soda'])) {
        return msgs.recipeClarificationTypeSoda;
      }
      if (_containsAny(lowerDescription, const ['суп', 'soup', 'broth'])) {
        return msgs.recipeClarificationTypeSoup;
      }
      if (_containsAny(lowerDescription, const ['салат', 'salad'])) {
        return msgs.recipeClarificationTypeSalad;
      }
      return null;
    }

    String inferThermalProcessing() {
      if (_containsAny(lowerDescription,
          const ['запеч', 'baked', 'печ', 'гриль', 'grill'])) {
        return msgs.recipeClarificationMethodBaked;
      }
      if (_containsAny(lowerDescription, const ['жар', 'fried', 'fry'])) {
        return msgs.recipeClarificationMethodFried;
      }
      if (_containsAny(lowerDescription, const ['вар', 'boiled', 'steam'])) {
        return msgs.recipeClarificationMethodBoiled;
      }
      return msgs.recipeClarificationMethodDefault;
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
      lines.add(msgs.recipeClarificationClarify(ambiguous));
    }
    if (keyIngredients.isNotEmpty) {
      lines.add(msgs.recipeClarificationComposition(keyIngredients));
    }
    lines.add(msgs.recipeClarificationBrandUnknown);
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

    if (code == 404) {
      return _messages(locale).aiHttpNotFoundError;
    }
    if (code == 403) {
      return _messages(locale).aiHttpForbiddenError;
    }
    if (code == 401) {
      return _messages(locale).aiHttpUnauthorizedError;
    }
    if (code == 429) {
      return _messages(locale).aiHttpRateLimitError;
    }
    if (code == 400 || code == 422) {
      return _messages(locale).aiUnexpectedResponseFormatError;
    }
    if (code == 408 || code == 504) {
      return _messages(locale).aiNoResponseError;
    }
    if (code >= 500) {
      return _messages(locale).aiNoResponseError;
    }

    return _messages(locale).aiHttpGenericError(code);
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
    debugPrint('[Gemini raw response]:\n$trimmed');

    String cleanJson(String raw) {
      return raw
          .replaceAll(RegExp(r',\s*}'), '}')
          .replaceAll(RegExp(r',\s*]'), ']');
    }

    try {
      final direct = jsonDecode(cleanJson(trimmed));
      if (direct is Map<String, dynamic>) {
        return direct;
      }
    } catch (_) {}

    // Robust search for JSON object using first { and last }
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final possibleJson = trimmed.substring(firstBrace, lastBrace + 1);
      try {
        final extracted = jsonDecode(cleanJson(possibleJson));
        if (extracted is Map<String, dynamic>) return extracted;
      } catch (_) {}
    }

    final fenceMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(trimmed);
    if (fenceMatch != null) {
      try {
        final fenced = jsonDecode(cleanJson(fenceMatch.group(1)!.trim()));
        if (fenced is Map<String, dynamic>) return fenced;
      } catch (_) {}
    }

    AiErrorLogService.instance.logError(
      feature: 'JSON Decoder',
      message: 'Failed to parse JSON',
      details: trimmed,
    );

    throw GeminiRecipeException(
      _messages(locale).aiFailedToParseJsonError,
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
  final String clarification;
  final String healthAdvice;
  final IconData icon;
  final List<RecipeIngredient> ingredients;
  final Map<String, double> nutrients;

  const GeminiRecipeDraft({
    required this.name,
    required this.description,
    required this.clarification,
    required this.healthAdvice,
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
  final String fixSuggestions;
  final double confidence;
  final List<String> flags;

  final String healthAdvice;

  const DonateRecipeModerationResult({
    required this.approved,
    required this.reason,
    required this.fixSuggestions,
    required this.confidence,
    required this.flags,
    this.healthAdvice = '',
  });
}

class GeminiRecipeException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiRecipeException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NutrientEstimationResult {
  final Map<String, double> nutrients;
  final String healthAdvice;

  NutrientEstimationResult({
    required this.nutrients,
    this.healthAdvice = '',
  });
}
