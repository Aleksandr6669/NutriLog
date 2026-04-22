import 'dart:convert';

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

    http.Response? lastErrorResponse;

    for (final model in _models) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(payload);
        final decoded = _decodeJsonObject(text);

        final normalized = <String, double>{};
        for (final key in nutrientKeys) {
          normalized[key] = _toNonNegativeDouble(decoded[key]);
        }
        return normalized;
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

class GeminiRecipeException implements Exception {
  final String message;

  const GeminiRecipeException(this.message);

  @override
  String toString() => message;
}
