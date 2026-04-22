import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class GeminiRecipeService {
  static const String _model = 'gemini-3.1-flash-lite-preview';

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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

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

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
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
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiRecipeException(
        'Gemini вернул ошибку (${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(payload);
    final decoded = _decodeJsonObject(text);

    final normalized = <String, double>{};
    for (final key in nutrientKeys) {
      normalized[key] = _toNonNegativeDouble(decoded[key]);
    }
    return normalized;
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

class GeminiRecipeException implements Exception {
  final String message;

  const GeminiRecipeException(this.message);

  @override
  String toString() => message;
}
