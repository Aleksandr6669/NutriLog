import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_data_service.dart';

class RecipeAdviceService {
  static final StreamController<void> _cacheUpdatesController =
      StreamController<void>.broadcast();

  static Stream<void> get cacheUpdates => _cacheUpdatesController.stream;

  static void _notifyCacheUpdated() {
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  static String _scopeSuffixFromCurrentUser() {
    final uid = CloudDataService.instance.currentUserId?.trim();
    if (uid == null || uid.isEmpty) return 'local';
    return uid;
  }

  static String _scopedAdvicesKey() {
    return 'user_recipe_advices_${_scopeSuffixFromCurrentUser()}';
  }

  /// Очищает локальный кеш рекомендаций пользователя
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedAdvicesKey());
    _notifyCacheUpdated();
  }

  /// Загружает все советы (карту) из локального кэша SharedPreferences
  Future<Map<String, dynamic>> loadAdvices() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_scopedAdvicesKey());
    if (rawJson == null || rawJson.isEmpty) return <String, dynamic>{};
    try {
      return json.decode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Загружает совет для конкретного рецепта по его ID
  Future<Map<String, dynamic>?> getAdvice(String recipeId) async {
    final advices = await loadAdvices();
    final adviceData = advices[recipeId];
    if (adviceData is Map<String, dynamic>) {
      return adviceData;
    }
    return null;
  }

  /// Сохраняет совет локально и запускает фоновую синхронизацию с Firestore
  Future<void> saveAdvice(String recipeId, String advice, String hash) async {
    final advices = await loadAdvices();
    advices[recipeId] = {
      'advice': advice,
      'hash': hash,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedAdvicesKey(), json.encode(advices));
    _notifyCacheUpdated();

    // Не ждём сеть: локальное сохранение завершено, облако синкаем в фоне
    unawaited(_syncAdvicesToCloudInBackground(advices));
  }

  Future<void> _syncAdvicesToCloudInBackground(Map<String, dynamic> advices) async {
    try {
      await CloudDataService.instance.writeMap('recipe_advices', advices);
    } catch (_) {
      // Повтор произойдет при следующем цикле синхронизации LocalFirstSyncService
    }
  }

  /// Синхронизация локальных данных с облаком (вызывается из LocalFirstSyncService)
  Future<void> syncWithCloud() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return;

    final localAdvices = await loadAdvices();
    // Пишем всю карту в один документ 'recipe_advices' в Firestore
    await cloud.writeMap('recipe_advices', localAdvices);
  }

  /// Получение данных из облака с заменой локальных (вызывается из LocalFirstSyncService)
  Future<void> pullFromCloudReplaceLocal() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return;

    final remote = await cloud.readMap('recipe_advices');
    if (remote == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedAdvicesKey(), json.encode(remote));
    _notifyCacheUpdated();
  }
}
