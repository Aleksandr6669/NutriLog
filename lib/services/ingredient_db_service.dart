import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ingredient_product.dart';
import 'cloud_data_service.dart';

class IngredientDbService {
  IngredientDbService._();

  static final IngredientDbService instance = IngredientDbService._();

  final Map<String, IngredientProduct> _cache = {};
  bool _loaded = false;

  static final StreamController<void> _cacheUpdatesController =
      StreamController<void>.broadcast();

  Stream<void> get cacheUpdates => _cacheUpdatesController.stream;

  static String _scopedKey() {
    return 'ingredients_db_global';
  }

  void _notifyCacheUpdated() {
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  /// Очищает локальный кеш ингредиентов
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey());
    instance._cache.clear();
    instance._loaded = false;
    instance._notifyCacheUpdated();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_scopedKey());
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _cache[key] = IngredientProduct.fromJson(value);
          }
        });
      } catch (_) {
        // Игнорируем поврежденный кеш
      }
    }
    _loaded = true;
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> toEncode = {};
    _cache.forEach((key, value) {
      toEncode[key] = value.toJson();
    });
    await prefs.setString(_scopedKey(), json.encode(toEncode));
  }

  void _evictOldestIfNeeded() {
    if (_cache.length <= 500) return;

    // Сортируем ключи по времени последнего доступа по возрастанию
    final sortedKeys = _cache.keys.toList()
      ..sort((a, b) {
        final aTime = _cache[a]?.lastAccessedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = _cache[b]?.lastAccessedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    // Удаляем самые старые элементы, пока не уложимся в лимит 500
    while (_cache.length > 500 && sortedKeys.isNotEmpty) {
      final keyToRemove = sortedKeys.removeAt(0);
      _cache.remove(keyToRemove);
    }
  }

  /// Поиск ингредиента по имени (регистронезависимый) с Firebase-First логикой
  Future<IngredientProduct?> findByName(String name) async {
    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return null;

    await _ensureLoaded();

    // Сначала ищем в локальном кеше
    if (_cache.containsKey(cleanName)) {
      final product = _cache[cleanName]!;
      final updated = product.copyWith(lastAccessedAt: DateTime.now());
      _cache[cleanName] = updated;
      unawaited(_saveToPrefs());
      return updated;
    }

    // Если локально нет, запрашиваем общее облако Firebase (shared_ingredients_db)
    try {
      final cloudData = await CloudDataService.instance.readSharedMap('shared_ingredients_db');
      if (cloudData != null && cloudData['ingredients'] is Map) {
        final ingredientsMap = cloudData['ingredients'] as Map<String, dynamic>;
        if (ingredientsMap.containsKey(cleanName)) {
          final raw = ingredientsMap[cleanName];
          if (raw is Map<String, dynamic>) {
            final product = IngredientProduct.fromJson(raw).copyWith(
              lastAccessedAt: DateTime.now(),
            );
            _cache[cleanName] = product;
            _evictOldestIfNeeded();
            await _saveToPrefs();
            _notifyCacheUpdated();
            return product;
          }
        }
      }
    } catch (_) {
      // Ошибка сети или прав: продолжаем работать по локальным данным
    }

    return null;
  }

  /// Сохранение ингредиента локально и в облако
  Future<void> saveIngredient(IngredientProduct product) async {
    final cleanName = product.name.trim().toLowerCase();
    if (cleanName.isEmpty) return;

    await _ensureLoaded();

    final updatedProduct = product.copyWith(
      name: cleanName,
      lastAccessedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _cache[cleanName] = updatedProduct;
    _evictOldestIfNeeded();

    await _saveToPrefs();
    _notifyCacheUpdated();

    // Асинхронно синхронизируем с облаком
    unawaited(syncWithCloud());
  }

  /// Синхронизация локальной базы с облаком Firestore
  Future<void> syncWithCloud() async {
    final cloudService = CloudDataService.instance;

    await _ensureLoaded();

    try {
      final cloudData = await cloudService.readSharedMap('shared_ingredients_db');
      final Map<String, IngredientProduct> cloudCache = {};
      if (cloudData != null && cloudData['ingredients'] is Map) {
        final ingredientsMap = cloudData['ingredients'] as Map<String, dynamic>;
        ingredientsMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            cloudCache[key] = IngredientProduct.fromJson(value);
          }
        });
      }

      bool changed = false;
      final mergedKeys = {..._cache.keys, ...cloudCache.keys};
      for (final key in mergedKeys) {
        final localVal = _cache[key];
        final cloudVal = cloudCache[key];

        if (localVal != null && cloudVal != null) {
          if (localVal.updatedAt.isAfter(cloudVal.updatedAt)) {
            cloudCache[key] = localVal;
            changed = true;
          } else if (cloudVal.updatedAt.isAfter(localVal.updatedAt)) {
            _cache[key] = cloudVal;
            changed = true;
          }
        } else if (localVal != null) {
          cloudCache[key] = localVal;
          changed = true;
        } else if (cloudVal != null) {
          _cache[key] = cloudVal;
          changed = true;
        }
      }

      _evictOldestIfNeeded();

      if (changed) {
        await _saveToPrefs();
        _notifyCacheUpdated();
      }

      final Map<String, dynamic> toWrite = {};
      cloudCache.forEach((key, value) {
        toWrite[key] = value.toJson();
      });

      await cloudService.writeSharedMap('shared_ingredients_db', {
        'ingredients': toWrite,
      });
    } catch (_) {
      // Ошибка сети — синхронизация повторится при следующем запуске или по таймеру
    }
  }

  /// Полное замещение локальных данных облачными
  Future<void> pullFromCloudReplaceLocal() async {
    final cloudService = CloudDataService.instance;

    try {
      final cloudData = await cloudService.readSharedMap('shared_ingredients_db');
      if (cloudData != null && cloudData['ingredients'] is Map) {
        final ingredientsMap = cloudData['ingredients'] as Map<String, dynamic>;
        _cache.clear();
        ingredientsMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _cache[key] = IngredientProduct.fromJson(value);
          }
        });
        _evictOldestIfNeeded();
        await _saveToPrefs();
        _notifyCacheUpdated();
      }
    } catch (_) {
      // Ошибка сети: оставляем локальный кеш
    }
  }
}
