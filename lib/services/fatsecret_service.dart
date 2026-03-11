import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/fatsecret_food.dart';

class FatsecretService {
  final String _baseUrl = 'https://platform.fatsecret.com/rest/server.api';
  final String _clientId = dotenv.env['FATSECRET_CLIENT_ID']!;
  final String _clientSecret = dotenv.env['FATSECRET_CLIENT_SECRET']!;
  String? _accessToken;

  Future<void> _authenticate() async {
    final response = await http.post(
      Uri.parse('https://oauth.fatsecret.com/connect/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'scope': 'basic',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Failed to authenticate with FatSecret API');
    }
  }

  Future<List<FatsecretFood>> searchFoods(String query) async {
    if (_accessToken == null) {
      await _authenticate();
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'method': 'foods.search',
        'search_expression': query,
        'format': 'json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['foods'] != null && data['foods']['food'] != null) {
        final List<dynamic> foodList = data['foods']['food'];
        return foodList.map((json) => FatsecretFood.fromJson(json)).toList();
      }
      return [];
    } else {
      // If token expired, re-authenticate and retry once.
      if (response.statusCode == 401) {
        await _authenticate();
        return searchFoods(query); // Retry the request
      }
      throw Exception('Failed to search foods: ${response.body}');
    }
  }
}
