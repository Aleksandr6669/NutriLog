import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Сервис для получения информации о продуктах из USDA FoodData Central API
/// Получить API-ключ: https://fdc.nal.usda.gov/api-key-signup.html
class UsdaFoodDataService {
  static const String _baseUrl = 'https://api.nal.usda.gov/fdc/v1';
  final String apiKey;

  factory UsdaFoodDataService.fromEnv() {
    final key = dotenv.env['USDA_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('Не найден ключ USDA_API_KEY в .env');
    }
    return UsdaFoodDataService(apiKey: key);
  }

  UsdaFoodDataService({required this.apiKey});

  /// Поиск продуктов по названию (возвращает список продуктов)
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final url =
        '$_baseUrl/foods/search?query=${Uri.encodeComponent(query)}&pageSize=5&api_key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['foods'] != null) {
        return List<Map<String, dynamic>>.from(data['foods']);
      }
    }
    return [];
  }

  /// Получить подробную информацию о продукте по FDC ID
  Future<Map<String, dynamic>?> getProductInfo(int fdcId) async {
    final url = '$_baseUrl/food/$fdcId?api_key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    return null;
  }
}
