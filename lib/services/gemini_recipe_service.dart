import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class GeminiRecipeService {
  static const List<String> _models = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite-preview',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-3.1-flash-lite',
    'gemini-3.1-flash',
    'gemini-3.1-flash-lite-preview',
    'gemini-3.1-pro',
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
- ingredients должен содержать минимум 1 ингредиент.
- quantity числом >= 0.
- unit короткая строка типа: г, мл, шт, ст.л., ч.л.
- nutrients только числа >= 0.
- Если точных данных нет, дай реалистичную оценку.
''';

    final response = await _requestWithFallback(
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'responseMimeType': 'application/json',
        },
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
- ingredients должен содержать минимум 1 ингредиент.
- quantity числом >= 0.
- unit короткая строка типа: г, мл, шт, ст.л., ч.л.
- nutrients только числа >= 0.
- Если точных данных нет, дай реалистичную оценку.
''';

    final response = await _requestWithFallback(
      body: {
        'contents': [
          {
            'parts': [
              {'text': textPrompt},
              {
                'inline_data': {
                  'mime_type': imageMimeType,
                  'data': base64Encode(imageBytes),
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'responseMimeType': 'application/json',
        },
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

    final apiKey = (dotenv.env['GEMINI_API_KEY'] ??
            const String.fromEnvironment('GEMINI_API_KEY'))
        .trim();
    if (apiKey.isEmpty) {
      throw const GeminiRecipeException(
        'Не найден ключ Gemini. Добавьте GEMINI_API_KEY в .env или передайте --dart-define=GEMINI_API_KEY=... при запуске.',
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
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
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

  Future<http.Response> _requestWithFallback({
    required Map<String, dynamic> body,
    String? apiKeyOverride,
  }) async {
    final apiKey = (apiKeyOverride ??
            dotenv.env['GEMINI_API_KEY'] ??
            const String.fromEnvironment('GEMINI_API_KEY'))
        .trim();
    if (apiKey.isEmpty) {
      throw const GeminiRecipeException(
        'Не найден ключ Gemini. Добавьте GEMINI_API_KEY в .env или передайте --dart-define=GEMINI_API_KEY=... при запуске.',
      );
    }

    http.Response? lastErrorResponse;
    for (final model in _models) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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
    throw const GeminiRecipeException('Не удалось получить ответ от Gemini.');
  }

  GeminiRecipeDraft _draftFromDecodedJson(
    Map<String, dynamic> decoded, {
    required String fallbackDescription,
  }) {
    final rawName = (decoded['name'] as String? ?? '').trim();
    final rawDescription = (decoded['description'] as String? ?? '').trim();

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
        'Не удалось получить ингредиенты из ответа Gemini. Уточните описание и попробуйте снова.',
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
      ingredients: ingredients,
      nutrients: nutrients,
    );
  }

  String _buildHttpErrorMessage(http.Response response) {
    final code = response.statusCode;
    final apiMessage = _extractApiErrorMessage(response.body);

    if (code == 403) {
      return 'Gemini вернул 403 (доступ запрещен). Проверьте GEMINI_API_KEY, подключение Generative Language API и ограничения ключа в Google Cloud.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }
    if (code == 401) {
      return 'Gemini вернул 401 (неавторизован). Проверьте корректность GEMINI_API_KEY.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }
    if (code == 429) {
      return 'Gemini вернул 429 (лимит запросов). Попробуйте чуть позже.${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
    }

    return 'Gemini вернул ошибку ($code).${apiMessage.isEmpty ? '' : ' Детали: $apiMessage'}';
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
    final candidates = payload['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const GeminiRecipeException('Пустой ответ от Gemini.');
    }
    final first = candidates.first;
    if (first is! Map<String, dynamic>) {
      throw const GeminiRecipeException('Неожиданный формат ответа Gemini.');
    }

    final content = first['content'];
    if (content is! Map<String, dynamic>) {
      throw const GeminiRecipeException('Не удалось прочитать ответ Gemini.');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const GeminiRecipeException('Gemini не вернул контент.');
    }

    final firstPart = parts.first;
    if (firstPart is! Map<String, dynamic>) {
      throw const GeminiRecipeException('Некорректный ответ Gemini.');
    }

    final text = firstPart['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const GeminiRecipeException('Gemini вернул пустой текст.');
    }
    return text;
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
        'Не удалось разобрать JSON из ответа Gemini.');
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
  final List<RecipeIngredient> ingredients;
  final Map<String, double> nutrients;

  const GeminiRecipeDraft({
    required this.name,
    required this.description,
    required this.ingredients,
    required this.nutrients,
  });
}

class GeminiRecipeException implements Exception {
  final String message;

  const GeminiRecipeException(this.message);

  @override
  String toString() => message;
}
