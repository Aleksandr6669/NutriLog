import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import 'cloud_data_service.dart';

class RecipeService {
  static final StreamController<void> _cacheUpdatesController =
      StreamController<void>.broadcast();

  Stream<void> get cacheUpdates => _cacheUpdatesController.stream;

  void _notifyCacheUpdated() {
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  /// Очищает локальный кеш рецептов пользователя
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userRecipesKey);
    await prefs.remove(_publicRecipesKey);
  }

  static const _userRecipesKey = 'user_recipes';
  static const _publicRecipesKey = 'public_recipes_cache';

  List<Recipe> _loadRecipesFromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return <Recipe>[];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .whereType<Map>()
        .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
        .toList(growable: false);
  }

  Future<List<Recipe>> _loadLocalPrivateRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _loadRecipesFromJsonString(prefs.getString(_userRecipesKey));
    return local
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
        .toList(growable: false);
  }

  Future<List<Recipe>> _loadLocalPublicRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final local =
        _loadRecipesFromJsonString(prefs.getString(_publicRecipesKey));
    // Не переопределяем isUserRecipe — значение из JSON сохраняет права автора.
    return local
        .map((recipe) => recipe.copyWith(isPublic: true))
        .toList(growable: false);
  }

  Future<void> _savePrivateRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: false).toJson())
        .toList(growable: false);
    final encoded = json.encode(jsonList);
    if (prefs.getString(_userRecipesKey) == encoded) return;

    await prefs.setString(_userRecipesKey, encoded);
    _notifyCacheUpdated();
  }

  Future<void> _savePublicRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: true).toJson())
        .toList(growable: false);
    final encoded = json.encode(jsonList);
    if (prefs.getString(_publicRecipesKey) == encoded) return;

    await prefs.setString(_publicRecipesKey, encoded);
    _notifyCacheUpdated();
  }

  Future<List<Recipe>> _loadOwnedRecipesForMutation() async {
    final allRecipes = await loadUserRecipes(refreshPublicInBackground: false);
    return allRecipes.where((recipe) => recipe.isUserRecipe).toList();
  }

  // Загружает приватные рецепты пользователя + публичные рецепты всех пользователей.
  Future<List<Recipe>> loadUserRecipes({
    bool refreshPublicInBackground = true,
  }) async {
    final localPrivateRecipes = await _loadLocalPrivateRecipes();
    final localPublicRecipes = await _loadLocalPublicRecipes();

    if (refreshPublicInBackground && CloudDataService.instance.isSignedIn) {
      // Не блокируем UI: свежие публичные рецепты подтянутся и обновят локальный кэш.
      unawaited(_refreshPublicRecipesCacheFromCloud());
    }

    return _dedupeRecipesById([...localPrivateRecipes, ...localPublicRecipes]);
  }

  Recipe _mapPublicRecipeFromCloud(Map rawMap, String uid) {
    final map = Map<String, dynamic>.from(rawMap);
    final ownerId = map['userId'] as String?;
    final docId = map['__docId'] as String?;
    map.remove('userId');
    map.remove('__docId');

    if ((map['id'] as String?)?.trim().isEmpty != false &&
        docId != null &&
        docId.isNotEmpty) {
      map['id'] = docId;
    }

    final recipe = Recipe.fromJson(map);
    return recipe.copyWith(
      isPublic: true,
      isUserRecipe: ownerId != null && ownerId == uid,
    );
  }

  Future<void> _refreshPublicRecipesCacheFromCloud() async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return;

    try {
      final publicDocs = await cloudService.readCollection('publicRecipes');
      final publicRecipes = publicDocs
          .whereType<Map>()
          .map((rawMap) => _mapPublicRecipeFromCloud(rawMap, uid))
          .toList(growable: false);
      await _savePublicRecipesToPrefs(publicRecipes);
    } catch (_) {
      // Офлайн/permission: остаёмся на локальном кэше, повтор при следующем цикле.
    }
  }

  List<Recipe> _dedupeRecipesById(List<Recipe> recipes) {
    final byId = <String, Recipe>{};
    for (final recipe in recipes) {
      final id = recipe.id.trim();
      if (id.isEmpty) continue;

      final existing = byId[id];
      if (existing == null) {
        byId[id] = recipe;
        continue;
      }

      // При дублях оставляем более «богатую» и приоритетную запись.
      final merged = existing.copyWith(
        name: recipe.name.isNotEmpty ? recipe.name : existing.name,
        description: recipe.description.isNotEmpty
            ? recipe.description
            : existing.description,
        nutrients:
            recipe.nutrients.isNotEmpty ? recipe.nutrients : existing.nutrients,
        ingredients: recipe.ingredients.isNotEmpty
            ? recipe.ingredients
            : existing.ingredients,
        instructions: recipe.instructions.isNotEmpty
            ? recipe.instructions
            : existing.instructions,
        icon: recipe.icon,
        isUserRecipe: existing.isUserRecipe || recipe.isUserRecipe,
        isPublic: existing.isPublic || recipe.isPublic,
        isDonated: existing.isDonated || recipe.isDonated,
      );
      byId[id] = merged;
    }
    return byId.values.toList(growable: false);
  }

  Future<int> syncWithCloud() async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return 0;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return 0;

    final localPrivateRecipes = await _loadLocalPrivateRecipes();
    final localPublicRecipes = await _loadLocalPublicRecipes();
    final ownPublicRecipes = localPublicRecipes
        .where((recipe) => recipe.isUserRecipe)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: true))
        .toList(growable: false);

    // Phone-first: приватные рецепты в облаке всегда переписываются локальными.
    await cloudService.writeMap('recipes', {
      'recipes':
          localPrivateRecipes.map((r) => r.toJson()).toList(growable: false),
    });

    await _syncOwnPublicRecipesToCloud(ownPublicRecipes);

    // Публичные рецепты других пользователей подтягиваем отдельной фоновой задачей.
    unawaited(_refreshPublicRecipesCacheFromCloud());

    final totalPrivate = localPrivateRecipes.length;
    final totalPublic = ownPublicRecipes.length;
    return totalPrivate + totalPublic;
  }

  Future<void> _syncOwnPublicRecipesToCloud(List<Recipe> publicRecipes) async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return;

    // При изменении/удалении рецепта сразу пишем в Firestore —
    // все подписчики сразу видят изменение через collectionStream
    for (final recipe in publicRecipes) {
      await cloudService.upsertDocument('publicRecipes', recipe.id, {
        ...recipe.copyWith(isPublic: true).toJson(),
        'userId': uid,
      });
    }

    // Удаляем те, которых больше нет в списке (были отозваны или сделаны приватными)
    // Читаем единственный раз во время полного синка
    final existingDocs = await cloudService.readCollection('publicRecipes');
    final existingOwnIds = existingDocs
        .where((doc) => doc['userId'] == uid)
        .map((doc) => doc['__docId'] as String?)
        .whereType<String>()
        .toSet();
    final targetIds = publicRecipes.map((recipe) => recipe.id).toSet();
    for (final staleId in existingOwnIds.difference(targetIds)) {
      await cloudService.deleteDocument('publicRecipes', staleId);
    }
  }

  // Сохраняет только собственные рецепты пользователя.
  Future<void> _saveUserRecipes(
    List<Recipe> ownedRecipes, {
    bool syncCloud = true,
  }) async {
    final privateRecipes = ownedRecipes
        .where((recipe) => !recipe.isPublic && !recipe.isDonated)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
        .toList(growable: false);

    final ownPublicRecipes = ownedRecipes
        .where((recipe) => recipe.isPublic && !recipe.isDonated)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: true))
        .toList(growable: false);

    final donatedAsPublicOthers = ownedRecipes
        .where((recipe) => recipe.isDonated)
        .map((recipe) => recipe.copyWith(isUserRecipe: false, isPublic: true))
        .toList(growable: false);

    await _savePrivateRecipesToPrefs(privateRecipes);

    final allRecipes = await loadUserRecipes(refreshPublicInBackground: false);
    final publicOthers = allRecipes
        .where((recipe) => recipe.isPublic && !recipe.isUserRecipe)
        .map((recipe) => recipe.copyWith(isUserRecipe: false, isPublic: true))
        .toList(growable: false);
    await _savePublicRecipesToPrefs([
      ...publicOthers,
      ...donatedAsPublicOthers,
      ...ownPublicRecipes,
    ]);

    if (!syncCloud) return;

    // Не ждём сеть: UI должен работать офлайн без задержек.
    unawaited(
        _syncRecipesToCloudInBackground(privateRecipes, ownPublicRecipes));
  }

  Future<void> _syncRecipesToCloudInBackground(
    List<Recipe> privateRecipes,
    List<Recipe> ownPublicRecipes,
  ) async {
    try {
      await CloudDataService.instance.writeMap('recipes', {
        'recipes':
            privateRecipes.map((r) => r.toJson()).toList(growable: false),
      });
      await _syncOwnPublicRecipesToCloud(ownPublicRecipes);
    } catch (_) {
      // Будет повторная синхронизация в фоне.
    }
  }

  Future<void> addRecipe(Recipe recipe) async {
    final recipes = await _loadOwnedRecipesForMutation();
    recipes.add(recipe.copyWith(isUserRecipe: true));
    await _saveUserRecipes(recipes);
  }

  Future<void> updateRecipe(Recipe updatedRecipe) async {
    final recipes = await _loadOwnedRecipesForMutation();
    final index = recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index == -1) return;
    if (recipes[index].isDonated) return;

    final shouldStayOwned = !updatedRecipe.isDonated;
    recipes[index] = updatedRecipe.copyWith(isUserRecipe: shouldStayOwned);
    await _saveUserRecipes(recipes);
  }

  Future<void> deleteRecipe(String recipeId) async {
    final recipes = await _loadOwnedRecipesForMutation();
    final deletedRecipe = recipes.firstWhere(
      (r) => r.id == recipeId,
      orElse: () => Recipe.empty(),
    );
    if (deletedRecipe.isDonated) return;

    recipes.removeWhere((r) => r.id == recipeId);
    await _saveUserRecipes(recipes);

    // Удаление из облака запускаем в фоне, чтобы не блокировать офлайн-удаление.
    if (deletedRecipe.isPublic) {
      unawaited(_deletePublicRecipeInBackground(recipeId));
    }
  }

  Future<void> _deletePublicRecipeInBackground(String recipeId) async {
    try {
      final cloudService = CloudDataService.instance;
      if (cloudService.isSignedIn) {
        await cloudService.deleteDocument('publicRecipes', recipeId);
      }
    } catch (_) {
      // При офлайне удаление в облаке будет дожато следующей синхронизацией.
    }
  }

  /// Real-time поток публичных рецептов из Firestore.
  /// Каждое обновление в облаке сохраняется в локальный кеш для оффлайн-доступа.
  Stream<List<Recipe>> publicRecipesStream() {
    final cloudService = CloudDataService.instance;
    final uid = cloudService.currentUserId;

    return cloudService
        .collectionStream('publicRecipes')
        .asyncMap((docs) async {
      final publicRecipes = docs.whereType<Map>().map((rawMap) {
        return _mapPublicRecipeFromCloud(rawMap, uid ?? '');
      }).toList(growable: false);

      // Сохраняем в локальный кеш для оффлайн-использования
      await _savePublicRecipesToPrefs(publicRecipes);
      return publicRecipes;
    });
  }

  /// Real-time поток приватных рецептов текущего пользователя.
  /// Позволяет мгновенно синхронизировать рецепты между устройствами.
  Stream<List<Recipe>> privateRecipesStream() {
    return CloudDataService.instance
        .docStream('recipes')
        .asyncMap((data) async {
      final localPrivate = await _loadLocalPrivateRecipes();

      // Если на телефоне уже есть данные, не перетираем их облаком.
      if (localPrivate.isNotEmpty) {
        return localPrivate;
      }

      if (data == null) return <Recipe>[];
      final cloudRecipes = data['recipes'];
      if (cloudRecipes is! List) return <Recipe>[];
      final recipes = cloudRecipes
          .whereType<Map>()
          .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
          .map((r) => r.copyWith(isUserRecipe: true, isPublic: false))
          .toList(growable: false);

      // Инициализация с облака только когда локально пусто.
      await _savePrivateRecipesToPrefs(recipes);
      return recipes;
    });
  }
}
