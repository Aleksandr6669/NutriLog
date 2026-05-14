import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import 'cloud_data_service.dart';

class RecipeService {
  static final StreamController<void> _cacheUpdatesController =
      StreamController<void>.broadcast();

  static const _legacyUserRecipesKey = 'user_recipes';
  static const _legacyPublicRecipesKey = 'public_recipes_cache';

  Stream<void> get cacheUpdates => _cacheUpdatesController.stream;

  static String _scopeSuffixFromCurrentUser() {
    final uid = CloudDataService.instance.currentUserId?.trim();
    if (uid == null || uid.isEmpty) return 'local';
    return uid;
  }

  static String _scopedUserRecipesKey() {
    return 'user_recipes_${_scopeSuffixFromCurrentUser()}';
  }

  static String _scopedPublicRecipesKey() {
    return 'public_recipes_cache_${_scopeSuffixFromCurrentUser()}';
  }

  void _notifyCacheUpdated() {
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  /// Очищает локальный кеш рецептов пользователя
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedUserRecipesKey());
    await prefs.remove(_scopedPublicRecipesKey());
    if (!_cacheUpdatesController.isClosed) {
      _cacheUpdatesController.add(null);
    }
  }

  List<Recipe> _loadRecipesFromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return <Recipe>[];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .whereType<Map>()
        .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
        .toList(growable: false);
  }

  Future<String?> _readWithLegacyMigration(
    SharedPreferences prefs, {
    required String scopedKey,
    required String legacyKey,
  }) async {
    final scoped = prefs.getString(scopedKey);
    if (scoped != null) return scoped;

    final legacy = prefs.getString(legacyKey);
    if (legacy == null || legacy.isEmpty) return null;

    // One-time migration from old global key to current scoped key.
    await prefs.setString(scopedKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  Future<List<Recipe>> _loadLocalPrivateRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = await _readWithLegacyMigration(
      prefs,
      scopedKey: _scopedUserRecipesKey(),
      legacyKey: _legacyUserRecipesKey,
    );
    final local = _loadRecipesFromJsonString(localJson);
    return local
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
        .toList(growable: false);
  }

  Future<List<Recipe>> _loadLocalPublicRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final localJson = await _readWithLegacyMigration(
      prefs,
      scopedKey: _scopedPublicRecipesKey(),
      legacyKey: _legacyPublicRecipesKey,
    );
    final local = _loadRecipesFromJsonString(localJson);
    // Не переопределяем isUserRecipe — значение из JSON сохраняет права автора.
    return local
        .map((recipe) => recipe.copyWith(isPublic: true))
        .toList(growable: false);
  }

  Future<void> _savePrivateRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedUserRecipesKey();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: false).toJson())
        .toList(growable: false);
    final encoded = json.encode(jsonList);
    if (prefs.getString(key) == encoded) return;

    await prefs.setString(key, encoded);
    _notifyCacheUpdated();
  }

  Future<void> _savePublicRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedPublicRecipesKey();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: true).toJson())
        .toList(growable: false);
    final encoded = json.encode(jsonList);
    if (prefs.getString(key) == encoded) return;

    await prefs.setString(key, encoded);
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
      // Fetch both published and donated recipes
      final publicDocs = await cloudService.readCollection('publicRecipes');
      final donatedDocs = await cloudService.readCollection('donatedRecipes');

      final publicRecipes = publicDocs
          .whereType<Map>()
          .map((rawMap) => _mapPublicRecipeFromCloud(rawMap, uid))
          .toList();

      final donatedRecipes = donatedDocs
          .whereType<Map>()
          .map((rawMap) {
            final recipe = _mapPublicRecipeFromCloud(rawMap, uid);
            return recipe.copyWith(isDonated: true, isPublic: true);
          })
          .toList();

      await _savePublicRecipesToPrefs([...publicRecipes, ...donatedRecipes]);
    } catch (_) {
      // Офлайн/permission: остаёмся на локальном кэше, повтор при следующем цикле.
    }
  }

  Future<void> pullFromCloudReplaceLocal() async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return;

    try {
      final privateData = await cloudService.readMap('recipes');
      final cloudRecipesRaw = privateData?['recipes'];
      if (cloudRecipesRaw is List) {
        final cloudPrivateRecipes = cloudRecipesRaw
            .whereType<Map>()
            .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
            .map((r) => r.copyWith(isUserRecipe: true, isPublic: false))
            .toList(growable: false);
        await _savePrivateRecipesToPrefs(cloudPrivateRecipes);
      }

      final publicDocs = await cloudService.readCollection('publicRecipes');
      final donatedDocs = await cloudService.readCollection('donatedRecipes');

      final publicRecipes = publicDocs
          .whereType<Map>()
          .map((rawMap) => _mapPublicRecipeFromCloud(rawMap, uid))
          .toList();

      final donatedRecipes = donatedDocs
          .whereType<Map>()
          .map((rawMap) {
            final recipe = _mapPublicRecipeFromCloud(rawMap, uid);
            return recipe.copyWith(isDonated: true, isPublic: true);
          })
          .toList();

      await _savePublicRecipesToPrefs([...publicRecipes, ...donatedRecipes]);
    } catch (_) {
      // Keep local cache if pull fails.
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

      // При дублях предпочтение данным владельца, чтобы локальные правки
      // (например, переименование) не затирались публичным кэшем.
      final preferIncoming = recipe.isUserRecipe && !existing.isUserRecipe;
      final preferExisting = existing.isUserRecipe && !recipe.isUserRecipe;
      final preferExistingPrivateOverIncomingPublic = existing.isUserRecipe &&
          !existing.isPublic &&
          recipe.isUserRecipe &&
          recipe.isPublic;
      final preferIncomingPrivateOverExistingPublic = recipe.isUserRecipe &&
          !recipe.isPublic &&
          existing.isUserRecipe &&
          existing.isPublic;
      String pickString(String current, String next) {
        if (preferExistingPrivateOverIncomingPublic) {
          return current.isNotEmpty ? current : next;
        }
        if (preferIncomingPrivateOverExistingPublic) {
          return next.isNotEmpty ? next : current;
        }
        if (preferIncoming) return next.isNotEmpty ? next : current;
        if (preferExisting) return current.isNotEmpty ? current : next;
        return next.isNotEmpty ? next : current;
      }

      final merged = existing.copyWith(
        name: pickString(existing.name, recipe.name),
        description: pickString(existing.description, recipe.description),
        clarification: pickString(existing.clarification, recipe.clarification),
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

    final localPublicRecipes = await _loadLocalPublicRecipes();
    final publicOthers = localPublicRecipes
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
    final created = recipe.copyWith(isUserRecipe: true);
    recipes.add(created);
    await _saveUserRecipes(recipes, syncCloud: false);
    unawaited(_syncSingleRecipeMutationInBackground(
      previous: null,
      current: created,
      allOwnedRecipes: recipes,
    ));
  }

  Future<void> updateRecipe(Recipe updatedRecipe) async {
    final recipes = await _loadOwnedRecipesForMutation();
    final index = recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index == -1) return;
    if (recipes[index].isDonated) return;

    final previous = recipes[index];
    final shouldStayOwned = !updatedRecipe.isDonated;
    final current = updatedRecipe.copyWith(isUserRecipe: shouldStayOwned);
    recipes[index] = current;
    await _saveUserRecipes(recipes, syncCloud: false);
    unawaited(_syncSingleRecipeMutationInBackground(
      previous: previous,
      current: current,
      allOwnedRecipes: recipes,
    ));
  }

  Future<void> deleteRecipe(String recipeId) async {
    final recipes = await _loadOwnedRecipesForMutation();
    final deletedRecipe = recipes.firstWhere(
      (r) => r.id == recipeId,
      orElse: () => Recipe.empty(),
    );
    if (deletedRecipe.isDonated) return;

    recipes.removeWhere((r) => r.id == recipeId);
    await _saveUserRecipes(recipes, syncCloud: false);

    unawaited(_syncSingleRecipeMutationInBackground(
      previous: deletedRecipe,
      current: null,
      allOwnedRecipes: recipes,
    ));

    // Удаление из облака запускаем в фоне, чтобы не блокировать офлайн-удаление.
    if (deletedRecipe.isPublic) {
      unawaited(_deletePublicRecipeInBackground(recipeId));
    }
  }

  Future<void> _syncSingleRecipeMutationInBackground({
    required Recipe? previous,
    required Recipe? current,
    required List<Recipe> allOwnedRecipes,
  }) async {
    try {
      final cloudService = CloudDataService.instance;
      if (!cloudService.isSignedIn) return;

      final privateRecipes = allOwnedRecipes
          .where((recipe) => !recipe.isPublic && !recipe.isDonated)
          .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
          .toList(growable: false);

      await cloudService.writeMap('recipes', {
        'recipes':
            privateRecipes.map((r) => r.toJson()).toList(growable: false),
      });

      final shouldPublishCurrent =
          current != null && current.isPublic && !current.isDonated;
      final wasPublishedBefore = previous != null && previous.isPublic;

      if (shouldPublishCurrent) {
        final uid = cloudService.currentUserId;
        if (uid != null && uid.isNotEmpty) {
          await cloudService.upsertDocument('publicRecipes', current.id, {
            ...current.copyWith(isPublic: true).toJson(),
            'userId': uid,
          });
        }
      } else if (wasPublishedBefore) {
        await cloudService.deleteDocument('publicRecipes', previous.id);
      }
    } catch (_) {
      // Повторная синхронизация произойдёт автоматически при следующем цикле.
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
    final controller = StreamController<List<Recipe>>.broadcast();

    List<Map<String, dynamic>> lastPublic = [];
    List<Map<String, dynamic>> lastDonated = [];

    void emit() {
      final publicRecipes = lastPublic.map((rawMap) {
        return _mapPublicRecipeFromCloud(rawMap, uid ?? '');
      });

      final donatedRecipes = lastDonated.map((rawMap) {
        final recipe = _mapPublicRecipeFromCloud(rawMap, uid ?? '');
        return recipe.copyWith(isDonated: true, isPublic: true);
      });

      final combined = [...publicRecipes, ...donatedRecipes];
      unawaited(_savePublicRecipesToPrefs(combined));
      if (!controller.isClosed) {
        controller.add(combined);
      }
    }

    final sub1 = cloudService.collectionStream('publicRecipes').listen((docs) {
      lastPublic = docs;
      emit();
    });

    final sub2 = cloudService.collectionStream('donatedRecipes').listen((docs) {
      lastDonated = docs;
      emit();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Real-time поток приватных рецептов текущего пользователя.
  /// Позволяет мгновенно синхронизировать рецепты между устройствами.
  Stream<List<Recipe>> privateRecipesStream() {
    return CloudDataService.instance
        .docStream('recipes')
        .asyncMap((data) async {
      final localPrivate = await _loadLocalPrivateRecipes();

      if (data == null) return localPrivate;
      final cloudRecipes = data['recipes'];
      if (cloudRecipes is! List) return localPrivate;
      final recipes = cloudRecipes
          .whereType<Map>()
          .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
          .map((r) => r.copyWith(isUserRecipe: true, isPublic: false))
          .toList(growable: false);

      // Облако — источник истины для межустройственной синхронизации приватных рецептов.
      await _savePrivateRecipesToPrefs(recipes);
      return recipes;
    });
  }
}
