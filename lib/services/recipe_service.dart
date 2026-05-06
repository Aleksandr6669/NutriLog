import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import 'cloud_data_service.dart';

class RecipeService {
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
    return local
        .map((recipe) => recipe.copyWith(isUserRecipe: false, isPublic: true))
        .toList(growable: false);
  }

  Future<void> _savePrivateRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: false).toJson())
        .toList(growable: false);
    await prefs.setString(_userRecipesKey, json.encode(jsonList));
  }

  Future<void> _savePublicRecipesToPrefs(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = recipes
        .map((r) => r.copyWith(isPublic: true).toJson())
        .toList(growable: false);
    await prefs.setString(_publicRecipesKey, json.encode(jsonList));
  }

  Future<List<Recipe>> _loadOwnedRecipesForMutation() async {
    final allRecipes = await loadUserRecipes();
    return allRecipes.where((recipe) => recipe.isUserRecipe).toList();
  }

  // Загружает приватные рецепты пользователя + публичные рецепты всех пользователей.
  Future<List<Recipe>> loadUserRecipes() async {
    final localPrivateRecipes = await _loadLocalPrivateRecipes();
    final localPublicRecipes = await _loadLocalPublicRecipes();

    return [...localPrivateRecipes, ...localPublicRecipes];
  }

  Future<void> syncWithCloud() async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return;

    final localPrivateRecipes = await _loadLocalPrivateRecipes();
    final localPublicRecipes = await _loadLocalPublicRecipes();
    final ownPublicRecipes = localPublicRecipes
        .where((recipe) => recipe.isUserRecipe)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: true))
        .toList(growable: false);

    final cloudMap = await cloudService.readMap('recipes');
    final cloudRecipes = cloudMap?['recipes'];

    if (localPrivateRecipes.isEmpty && cloudRecipes is List) {
      final cloudPrivateRecipes = cloudRecipes
          .whereType<Map>()
          .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
          .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
          .toList(growable: false);
      await _savePrivateRecipesToPrefs(cloudPrivateRecipes);
    } else {
      await cloudService.writeMap('recipes', {
        'recipes':
            localPrivateRecipes.map((r) => r.toJson()).toList(growable: false),
      });
    }

    await _syncOwnPublicRecipesToCloud(ownPublicRecipes);

    final publicDocs = await cloudService.readCollection('publicRecipes');
    final publicRecipes = publicDocs.whereType<Map>().map((rawMap) {
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
    }).toList(growable: false);

    await _savePublicRecipesToPrefs(publicRecipes);
  }

  Future<void> _syncOwnPublicRecipesToCloud(List<Recipe> publicRecipes) async {
    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    final uid = cloudService.currentUserId;
    if (uid == null || uid.isEmpty) return;

    final existingDocs = await cloudService.readCollection('publicRecipes');
    final existingOwnIds = existingDocs
        .where((doc) => doc['userId'] == uid)
        .map((doc) => doc['__docId'] as String?)
        .whereType<String>()
        .toSet();

    final targetIds = publicRecipes.map((recipe) => recipe.id).toSet();

    for (final recipe in publicRecipes) {
      await cloudService.upsertDocument('publicRecipes', recipe.id, {
        ...recipe.copyWith(isPublic: true).toJson(),
        'userId': uid,
      });
    }

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
        .where((recipe) => !recipe.isPublic)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: false))
        .toList(growable: false);

    final ownPublicRecipes = ownedRecipes
        .where((recipe) => recipe.isPublic)
        .map((recipe) => recipe.copyWith(isUserRecipe: true, isPublic: true))
        .toList(growable: false);

    await _savePrivateRecipesToPrefs(privateRecipes);

    final allRecipes = await loadUserRecipes();
    final publicOthers = allRecipes
        .where((recipe) => recipe.isPublic && !recipe.isUserRecipe)
        .map((recipe) => recipe.copyWith(isUserRecipe: false, isPublic: true))
        .toList(growable: false);
    await _savePublicRecipesToPrefs([...publicOthers, ...ownPublicRecipes]);

    if (!syncCloud) return;

    try {
      await CloudDataService.instance.writeMap('recipes', {
        'recipes':
            privateRecipes.map((r) => r.toJson()).toList(growable: false),
      });
      await _syncOwnPublicRecipesToCloud(ownPublicRecipes);
    } catch (_) {
      // Локальное сохранение уже выполнено.
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

    recipes[index] = updatedRecipe.copyWith(isUserRecipe: true);
    await _saveUserRecipes(recipes);
  }

  Future<void> deleteRecipe(String recipeId) async {
    final recipes = await _loadOwnedRecipesForMutation();
    recipes.removeWhere((r) => r.id == recipeId);
    await _saveUserRecipes(recipes);
  }
}
