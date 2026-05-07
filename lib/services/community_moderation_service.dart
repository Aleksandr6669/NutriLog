import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';
import 'cloud_data_service.dart';
import 'gemini_recipe_service.dart';
import 'recipe_service.dart';

/// Фоновая проверка публичных рецептов при старте приложения.
///
/// Логика:
/// - Загружает список запрещённых паттернов из assets.
/// - Проверяет все публичные рецепты из локального кеша.
/// - Если рецепт принадлежит текущему пользователю и нарушает правила:
///     • делает локальную копию непубличной (`isPublic = false`), сохраняя рецепт;
///     • удаляет его из Firestore-коллекции `publicRecipes`.
/// - Если рецепт чужой и нарушает правила:
///     • удаляет его из локального кеша (не показывает в UI).
/// - Для собственных публичных рецептов дополнительно запускает AI-модерацию.
///   Если AI временно недоступен, периодически повторяет попытку в фоне,
///   и при следующей успешной проверке переводит неподходящие рецепты в приватные.
///
/// Запускается через [runStartupCheck], которая не бросает исключений.
class CommunityModerationService {
  static const _blocklistAssetPath = 'assets/data/moderation_blocklist.json';
  static const _publicRecipesKey = 'public_recipes_cache';
  static const _aiRetryInterval = Duration(minutes: 10);

  static Timer? _aiRetryTimer;
  static bool _isAiModerationRunning = false;

  CommunityModerationService._();

  /// Запускает фоновую проверку. Не бросает исключений.
  static Future<void> runStartupCheck() async {
    try {
      await _runLocalBlocklistPass();
      final aiReady = await _runAiModerationPass();
      if (aiReady) {
        _stopAiRetryLoop();
      } else {
        _ensureAiRetryLoop();
      }
    } catch (_) {
      // Не блокируем запуск приложения ни при каких условиях.
    }
  }

  static Future<void> _runLocalBlocklistPass() async {
    final patterns = await _loadPatterns();
    if (patterns.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final recipeService = RecipeService();

    // --- Публичные рецепты (кеш) ---
    final publicCacheRaw = prefs.getString(_publicRecipesKey);
    if (publicCacheRaw != null && publicCacheRaw.isNotEmpty) {
      final List<dynamic> jsonList = json.decode(publicCacheRaw);
      final publicRecipes = jsonList
          .whereType<Map>()
          .map((m) => Recipe.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      bool publicCacheChanged = false;
      final cleanPublic = <Recipe>[];

      for (final recipe in publicRecipes) {
        if (_violatesBlocklist(recipe, patterns)) {
          publicCacheChanged = true;

          if (recipe.isUserRecipe) {
            await _privatizeOwnedRecipe(recipeService, recipe);
          }

          // Чужой рецепт — просто не включаем в обновлённый кеш.
        } else {
          cleanPublic.add(recipe);
        }
      }

      if (publicCacheChanged) {
        await prefs.setString(
          _publicRecipesKey,
          json.encode(cleanPublic.map((r) => r.toJson()).toList()),
        );
      }
    }
  }

  static Future<bool> _runAiModerationPass() async {
    if (_isAiModerationRunning) return false;

    final cloudService = CloudDataService.instance;
    final currentUid = cloudService.currentUserId;
    if (currentUid == null || currentUid.isEmpty) return true;

    _isAiModerationRunning = true;
    try {
      final recipeService = RecipeService();
      final allRecipes = await recipeService.loadUserRecipes(
        refreshPublicInBackground: false,
      );
      final ownPublicRecipes = allRecipes
          .where((recipe) => recipe.isUserRecipe && recipe.isPublic)
          .where((recipe) => !recipe.isDonated)
          .toList(growable: false);

      if (ownPublicRecipes.isEmpty) return true;

      final moderationService = GeminiRecipeService();
      for (final recipe in ownPublicRecipes) {
        if (recipe.name.trim().isEmpty || recipe.ingredients.isEmpty) {
          await _privatizeOwnedRecipe(recipeService, recipe);
          continue;
        }

        try {
          final result =
              await moderationService.validateRecipeForCommunityDonation(
            recipeName: recipe.name,
            recipeDescription: recipe.description,
            clarification: recipe.clarification,
            ingredients: recipe.ingredients,
            nutrients: recipe.nutrients,
          );

          if (!result.approved) {
            await _privatizeOwnedRecipe(recipeService, recipe);
          }
        } on GeminiRecipeException {
          return false;
        } catch (_) {
          return false;
        }
      }

      return true;
    } finally {
      _isAiModerationRunning = false;
    }
  }

  static void _ensureAiRetryLoop() {
    final timer = _aiRetryTimer;
    if (timer != null && timer.isActive) return;

    _aiRetryTimer = Timer.periodic(_aiRetryInterval, (_) {
      unawaited(_retryAiModeration());
    });
  }

  static Future<void> _retryAiModeration() async {
    final aiReady = await _runAiModerationPass();
    if (aiReady) {
      _stopAiRetryLoop();
    }
  }

  static void _stopAiRetryLoop() {
    _aiRetryTimer?.cancel();
    _aiRetryTimer = null;
  }

  /// Загружает список паттернов из JSON-ассета.
  static Future<List<String>> _loadPatterns() async {
    try {
      final raw = await rootBundle.loadString(_blocklistAssetPath);
      final data = json.decode(raw) as Map<String, dynamic>;
      return (data['patterns'] as List<dynamic>? ?? const [])
          .map((p) => p.toString().toLowerCase().trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Проверяет рецепт на соответствие blocklist.
  static bool _violatesBlocklist(Recipe recipe, List<String> patterns) {
    final text = [
      recipe.name,
      recipe.description,
      recipe.clarification,
      ...recipe.ingredients.map((i) => i.name),
    ].join(' ').toLowerCase();

    return patterns.any((pattern) => text.contains(pattern));
  }

  static Future<void> _privatizeOwnedRecipe(
    RecipeService recipeService,
    Recipe recipe,
  ) async {
    if (!recipe.isUserRecipe || !recipe.isPublic) return;

    final privateRecipe = recipe.copyWith(
      isUserRecipe: true,
      isPublic: false,
      isDonated: false,
    );

    await recipeService.updateRecipe(privateRecipe);

    final cloudService = CloudDataService.instance;
    if (!cloudService.isSignedIn) return;

    try {
      await cloudService.deleteDocument('publicRecipes', recipe.id);
    } catch (_) {
      // При офлайне удаление будет дожато обычной синхронизацией рецептов.
    }
  }
}
