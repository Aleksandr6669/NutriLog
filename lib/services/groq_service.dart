import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqService {
  final String _apiKey = dotenv.env['GROQ_API_KEY']!;
  final String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<String> analyzeImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final imageDataUrl = 'data:image/jpeg;base64,$base64Image';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // ИСПОЛЬЗУЕМ НОВУЮ, УКАЗАННУЮ ВАМИ МОДЕЛЬ
          'model': 'meta-llama/llama-4-scout-17b-16e-instruct', 
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Определи, какая еда на этой фотографии. В ответе укажи только название блюда и его примерную калорийность на 100 грамм в формате: "Название блюда: XXX ккал". Если на фото не еда, напиши "Не удалось распознать еду".'
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': imageDataUrl}
                }
              ]
            }
          ],
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        }
        return 'Не удалось получить ответ от AI.';
      } else {
        return 'Ошибка API: ${response.statusCode} ${response.body}';
      }
    } catch (e) {
      return 'Произошла ошибка: $e';
    }
  }

  Future<String> getFoodAnalysisFromText(String query) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama3-8b-8192',
          'messages': [
            {
              'role': 'system',
              'content': 'Ты — эксперт-диетолог. Проанализируй следующий прием пищи. Верни только название продукта или блюда, без лишних слов. Например, если пользователь вводит "тарелка борща и кусок хлеба", ты должен вернуть "Борщ с хлебом".'
            },
            {
              'role': 'user',
              'content': query,
            }
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        }
        return 'Не удалось получить ответ от AI.';
      } else {
        return 'Ошибка API: ${response.statusCode} ${response.body}';
      }
    } catch (e) {
      return 'Произошла ошибка: $e';
    }
  }
}
