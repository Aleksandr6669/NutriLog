import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import 'cloud_data_service.dart';

class RecipeService {
  static const _userRecipesKey = 'user_recipes';

  // Загрузка пользовательских рецептов
  Future<List<Recipe>> loadUserRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userRecipesKey);
    List<Recipe> localRecipes = [];
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      localRecipes = jsonList.map((json) => Recipe.fromJson(json)).toList();
    }

    try {
      final cloudMap = await CloudDataService.instance.readMap('recipes');
      final cloudRecipes = cloudMap?['recipes'];
      if (cloudRecipes is List) {
        final recipes = cloudRecipes
            .whereType<Map>()
            .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json)))
            .toList(growable: false);
        await _saveUserRecipes(recipes, syncCloud: false);
        return recipes;
      }

      if (localRecipes.isNotEmpty) {
        await CloudDataService.instance.writeMap('recipes', {
          'recipes': localRecipes.map((r) => r.toJson()).toList(),
        });
      }
    } catch (_) {
      // Если облако недоступно, используем локальные данные.
    }

    return localRecipes;
  }

  // Сохранение всех пользовательских рецептов
  Future<void> _saveUserRecipes(
    List<Recipe> recipes, {
    bool syncCloud = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList =
        recipes.map((r) => r.toJson()).toList();
    await prefs.setString(_userRecipesKey, json.encode(jsonList));

    if (!syncCloud) return;
    try {
      await CloudDataService.instance
          .writeMap('recipes', {'recipes': jsonList});
    } catch (_) {
      // Локальное сохранение уже выполнено.
    }
  }

  // Добавление нового рецепта
  Future<void> addRecipe(Recipe recipe) async {
    final recipes = await loadUserRecipes();
    recipes.add(recipe);
    await _saveUserRecipes(recipes);
  }

  // Обновление существующего рецепта
  Future<void> updateRecipe(Recipe updatedRecipe) async {
    final recipes = await loadUserRecipes();
    final index = recipes.indexWhere((r) => r.id == updatedRecipe.id);
    if (index != -1) {
      recipes[index] = updatedRecipe;
      await _saveUserRecipes(recipes);
    }
  }

  // Удаление рецепта
  Future<void> deleteRecipe(String recipeId) async {
    final recipes = await loadUserRecipes();
    recipes.removeWhere((r) => r.id == recipeId);
    await _saveUserRecipes(recipes);
  }
}
