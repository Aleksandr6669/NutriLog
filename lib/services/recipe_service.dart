import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class RecipeService {
  static const _userRecipesKey = 'user_recipes';

  // Загрузка пользовательских рецептов
  Future<List<Recipe>> loadUserRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userRecipesKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => Recipe.fromJson(json)).toList();
    }
    return [];
  }

  // Сохранение всех пользовательских рецептов
  Future<void> _saveUserRecipes(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = recipes.map((r) => r.toJson()).toList();
    await prefs.setString(_userRecipesKey, json.encode(jsonList));
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
