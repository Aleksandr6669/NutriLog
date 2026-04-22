import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import '../models/user_profile.dart';
import 'recipe_loader.dart';

class GeminiRecipeService {
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

  Future<GeminiRecipeDraft> generateRecipeFromDescription({
    required String description,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw const GeminiRecipeException('Введите описание блюда.');
    }

    final prompt = '''
Ты кулинарный ассистент.
Сгенерируй черновик рецепта на основе пользовательского описания.

Описание блюда:
$normalizedDescription

Верни ТОЛЬКО JSON-объект в формате:
{
  "name": "...",
  "description": "...",
  "icon": "restaurant",
  "ingredients": [
    {"name": "...", "quantity": 100, "unit": "г"}
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

Правила:
- icon выбери только из списка: ${_allowedIconNames.join(', ')}.
- ingredients должен содержать минимум 1 ингредиент.
- quantity числом >= 0.
- unit короткая строка типа: г, мл, шт, ст.л., ч.л.
- nutrients только числа >= 0.
- Если точных данных нет, дай реалистичную оценку.
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
      throw const GeminiRecipeException('Добавьте фото блюда.');
    }

    final normalizedDescription = description.trim();
    final textPrompt = '''
Ты кулинарный ассистент.
Определи блюдо по фото и создай черновик рецепта.
${normalizedDescription.isEmpty ? '' : 'Дополнительное описание от пользователя: $normalizedDescription'}

Верни ТОЛЬКО JSON-объект в формате:
{
  "name": "...",
  "description": "...",
  "icon": "restaurant",
  "ingredients": [
    {"name": "...", "quantity": 100, "unit": "г"}
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

Правила:
- icon выбери только из списка: ${_allowedIconNames.join(', ')}.
- ingredients должен содержать минимум 1 ингредиент.
- quantity числом >= 0.
- unit короткая строка типа: г, мл, шт, ст.л., ч.л.
- nutrients только числа >= 0.
- Если точных данных нет, дай реалистичную оценку.
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
      throw const GeminiRecipeException('Добавьте хотя бы один ингредиент.');
    }

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      throw const GeminiRecipeException(
        'Не найден ключ Groq. Добавьте GROQ_API_KEY в .env или передайте --dart-define=GROQ_API_KEY=... при запуске.',
      );
    }

    final ingredientsText = ingredients
        .map((i) => '- ${i.name}: ${i.quantity} ${i.unit}'.trim())
        .join('\n');

    final prompt = '''
Ты помощник-нутрициолог.
Оцени пищевую ценность рецепта на 1 порцию на основе списка ингредиентов.
Рецепт:
- Название: ${recipeName.trim().isEmpty ? 'Без названия' : recipeName.trim()}
- Описание: ${recipeDescription.trim().isEmpty ? '—' : recipeDescription.trim()}
- Ингредиенты:
$ingredientsText

Верни ТОЛЬКО JSON-объект с числовыми полями (double, без единиц измерения) и ключами:
${nutrientKeys.join(', ')}

Единицы:
- calories: ккал
- protein, carbs, fat, fiber, sugar, saturated_fat, polyunsaturated_fat, monounsaturated_fat, trans_fat: граммы
- cholesterol, sodium, potassium, calcium, iron, vitamin_c: миллиграммы
- vitamin_a, vitamin_d: микрограммы

Если точных данных нет, дай реалистичную оценку. Отрицательные значения недопустимы.
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
Ты фитнес-ассистент и нутрициолог.
Сделай короткий отчет по данным пользователя за период $periodLabel.

Данные:
- Цель калорий: $calorieGoal ккал
- Цель белков: $proteinGoal г
- Цель жиров: $fatGoal г
- Цель углеводов: $carbsGoal г
- Средние калории: ${avgCalories.toStringAsFixed(0)} ккал
- Средние белки: ${avgProteinGrams.toStringAsFixed(1)} г
- Средние жиры: ${avgFatGrams.toStringAsFixed(1)} г
- Средние углеводы: ${avgCarbsGrams.toStringAsFixed(1)} г
- Средняя клетчатка: ${avgFiberGrams.toStringAsFixed(1)} г
- Средний сахар: ${avgSugarGrams.toStringAsFixed(1)} г
- Средние насыщенные жиры: ${avgSaturatedFatGrams.toStringAsFixed(1)} г
- Средние полиненасыщенные жиры: ${avgPolyunsaturatedFatGrams.toStringAsFixed(1)} г
- Средние мононенасыщенные жиры: ${avgMonounsaturatedFatGrams.toStringAsFixed(1)} г
- Средние трансжиры: ${avgTransFatGrams.toStringAsFixed(2)} г
- Средний холестерин: ${avgCholesterolMg.toStringAsFixed(1)} мг
- Средний натрий: ${avgSodiumMg.toStringAsFixed(1)} мг
- Средний калий: ${avgPotassiumMg.toStringAsFixed(1)} мг
- Средний витамин A: ${avgVitaminAMcg.toStringAsFixed(1)} мкг
- Средний витамин C: ${avgVitaminCMg.toStringAsFixed(1)} мг
- Средний витамин D: ${avgVitaminDMcg.toStringAsFixed(1)} мкг
- Средний кальций: ${avgCalciumMg.toStringAsFixed(1)} мг
- Среднее железо: ${avgIronMg.toStringAsFixed(1)} мг
- Итого за период: ${totalCalories.toStringAsFixed(0)} ккал, белки ${totalProteinGrams.toStringAsFixed(1)} г, жиры ${totalFatGrams.toStringAsFixed(1)} г, углеводы ${totalCarbsGrams.toStringAsFixed(1)} г
- Итого за период (детально): клетчатка ${totalFiberGrams.toStringAsFixed(1)} г, сахар ${totalSugarGrams.toStringAsFixed(1)} г, насыщенные ${totalSaturatedFatGrams.toStringAsFixed(1)} г, полиненасыщенные ${totalPolyunsaturatedFatGrams.toStringAsFixed(1)} г, мононенасыщенные ${totalMonounsaturatedFatGrams.toStringAsFixed(1)} г, трансжиры ${totalTransFatGrams.toStringAsFixed(2)} г
- Итого минералы/витамины: холестерин ${totalCholesterolMg.toStringAsFixed(1)} мг, натрий ${totalSodiumMg.toStringAsFixed(1)} мг, калий ${totalPotassiumMg.toStringAsFixed(1)} мг, витамин A ${totalVitaminAMcg.toStringAsFixed(1)} мкг, витамин C ${totalVitaminCMg.toStringAsFixed(1)} мг, витамин D ${totalVitaminDMcg.toStringAsFixed(1)} мкг, кальций ${totalCalciumMg.toStringAsFixed(1)} мг, железо ${totalIronMg.toStringAsFixed(1)} мг
- Цель шагов: $stepsGoal
- Средние шаги: $avgSteps
- Цель веса: ${weightGoal.toStringAsFixed(1)} кг
- Последний вес: ${latestWeight.toStringAsFixed(1)} кг
- Цель воды: ${waterGoalLiters.toStringAsFixed(1)} л
- Средняя вода: ${avgWaterLiters.toStringAsFixed(1)} л
- Тренировок: $workouts
- Средние ккал активности за тренировку: $avgActivityCalories

Формат ответа:
1) Очень короткая выжимка: 2-4 предложения максимум
2) Учитывай не только калории, но и макро/микронутриенты и активность
3) Дай 2-3 практических шага на следующий период
3) Тон: поддерживающий, без запугивания
4) Не используй markdown, только обычный текст.
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
      throw const GeminiRecipeException('Нейросеть вернула пустой отчет.');
    }
    return text;
  }

  Future<DailyGoalsDraft> generateDailyGoals({
    required UserProfile profile,
  }) async {
    final prompt = '''
Ты нутрициолог и фитнес-консультант.
На основе данных пользователя предложи дневные цели.

Пользователь:
- Пол: ${profile.gender.ruLabel}
- Возраст: ${profile.age}
- Рост: ${profile.height} см
- Текущий вес: ${profile.weight.toStringAsFixed(1)} кг
- Целевой вес: ${profile.weightGoal.toStringAsFixed(1)} кг
- Тип цели: ${profile.goalType.ruLabel}
- Смысл цели: ${profile.goalType.ruHint}

Верни ТОЛЬКО JSON-объект в формате:
{
  "calorieGoal": 0,
  "proteinGoal": 0,
  "fatGoal": 0,
  "carbsGoal": 0,
  "waterGoal": 0,
  "stepsGoal": 0
}

Правила:
- Все значения должны быть целыми положительными числами.
- waterGoal укажи в миллилитрах.
- stepsGoal укажи в шагах.
- Цели должны быть реалистичными для ежедневного выполнения.
- Учитывай тип цели пользователя и базовые физические параметры.
- Не добавляй пояснения вне JSON.
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
      throw const GeminiRecipeException(
        'Не найден ключ Groq. Добавьте GROQ_API_KEY в .env или передайте --dart-define=GROQ_API_KEY=... при запуске.',
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
    throw const GeminiRecipeException('Не удалось получить ответ от Groq.');
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
      throw const GeminiRecipeException(
        'Не удалось получить ингредиенты из ответа Groq. Уточните описание и попробуйте снова.',
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
      name: rawName.isEmpty ? 'Новое блюдо' : rawName,
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
      return 'Groq вернул 403 (доступ запрещен). Проверьте GROQ_API_KEY и ограничения доступа.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }
    if (code == 401) {
      return 'Groq вернул 401 (неавторизован). Проверьте корректность GROQ_API_KEY.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }
    if (code == 429) {
      return 'Groq вернул 429 (лимит запросов). Попробуйте чуть позже.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }

    return 'Groq вернул ошибку ($code).${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
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
      throw const GeminiRecipeException('Пустой ответ от Groq.');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const GeminiRecipeException('Неожиданный формат ответа Groq.');
    }

    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const GeminiRecipeException('Не удалось прочитать ответ Groq.');
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const GeminiRecipeException('Groq вернул пустой текст.');
    }
    return content;
  }

  Map<String, dynamic> _decodeJsonObject(String text) {
    final trimmed = text.trim();
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) {
        return direct;
      }
    } catch (_) {
      // fallback below
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final candidate = trimmed.substring(start, end + 1);
      final parsed = jsonDecode(candidate);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    }

    throw const GeminiRecipeException(
        'Не удалось разобрать JSON из ответа Groq.');
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
