import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для кеширования фото аватара Google-аккаунта локально
class AvatarCacheService {
  static const String _cacheKeyPrefix = 'cached_google_photo_';

  /// Загрузить фото по URL и сохранить в кеш как base64.
  /// Возвращает true, если фото обновилось (изменилось или загружено впервые).
  static Future<bool> cacheGooglePhoto(String? photoUrl, String uid) async {
    if (photoUrl == null || photoUrl.isEmpty || uid.isEmpty) return false;

    try {
      final response = await http.get(Uri.parse(photoUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final newBase64 = base64Encode(response.bodyBytes);
        final prefs = await SharedPreferences.getInstance();
        final oldBase64 = prefs.getString('$_cacheKeyPrefix$uid');
        if (newBase64 == oldBase64) return false; // не изменилось
        await prefs.setString('$_cacheKeyPrefix$uid', newBase64);
        return true; // обновилось
      }
    } catch (e) {
      debugPrint('Failed to cache Google photo: $e');
    }
    return false;
  }

  /// Получить кешированное фото как base64
  static Future<String?> getCachedPhoto(String uid) async {
    if (uid.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_cacheKeyPrefix$uid');
  }

  /// Удалить кеш при выходе
  static Future<void> clearCache(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$uid');
  }

  /// Конвертировать base64 в памяти для Image.memory()
  static Uint8List? decodeBase64Photo(String base64String) {
    try {
      return Uint8List.fromList(base64Decode(base64String));
    } catch (e) {
      debugPrint('Failed to decode photo: $e');
      return null;
    }
  }
}
