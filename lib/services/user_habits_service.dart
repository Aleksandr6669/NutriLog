import 'dart:async';

import '../models/recipe.dart';
import 'daily_log_service.dart';
import 'recipe_service.dart';

class UserHabitsService {
  UserHabitsService._();

  static final UserHabitsService instance = UserHabitsService._();

  /// Анализирует историю последних 20 рецептов и 30 дней дневников питания,
  /// выявляя типичные порции и любимые специи/добавки пользователя.
  /// Возвращает текстовый блок с инструкциями для ИИ на русском языке.
  Future<String> compileUserHabitsContext() async {
    try {
      // 1. Загружаем рецепты пользователя
      final recipes = await RecipeService()
          .loadUserRecipes(refreshPublicInBackground: false);
      final userRecipes = recipes.where((r) => r.isUserRecipe).toList();
      final recentRecipes = userRecipes.reversed.take(20).toList();

      // 2. Загружаем дневники питания за последние 30 дней
      final dailyLogService = DailyLogService();
      final loggedDates = await dailyLogService.getLoggedDates();
      final sortedDates = loggedDates.toList()..sort((a, b) => b.compareTo(a));
      final recentDates = sortedDates.take(30).toList();

      final List<List<RecipeIngredient>> allIngredientLists = [];

      for (final recipe in recentRecipes) {
        allIngredientLists.add(recipe.ingredients);
      }

      for (final date in recentDates) {
        final log = await dailyLogService.getLogForDate(date);
        for (final meal in log.meals.values) {
          for (final foodItem in meal) {
            final ingredients = foodItem.recipeIngredients
                .map((e) =>
                    RecipeIngredient.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            if (ingredients.isNotEmpty) {
              allIngredientLists.add(ingredients);
            }
          }
        }
      }

      if (allIngredientLists.isEmpty) {
        return '';
      }

      // 3. Анализируем вес порций и количество упоминаний каждого ингредиента
      final Map<String, List<double>> ingredientQuantities = {};
      final Map<String, int> ingredientOccurrences = {};

      for (final list in allIngredientLists) {
        final seenInThisList = <String>{};
        for (final ing in list) {
          final name = ing.name.trim().toLowerCase();
          if (name.isEmpty) continue;

          // Учитываем вес только для граммовых или пустых мер
          final unitLower = ing.unit.toLowerCase();
          final isGram = unitLower == 'г' ||
              unitLower == 'g' ||
              unitLower == 'грамм' ||
              unitLower.isEmpty;

          if (isGram && ing.quantity > 0) {
            ingredientQuantities.putIfAbsent(name, () => []).add(ing.quantity);
          }

          if (!seenInThisList.contains(name)) {
            ingredientOccurrences[name] =
                (ingredientOccurrences[name] ?? 0) + 1;
            seenInThisList.add(name);
          }
        }
      }

      // 4. Формируем контекст типичных порций
      final List<String> portionsContext = [];
      ingredientQuantities.forEach((name, quantities) {
        if (quantities.length >= 2) {
          final average =
              quantities.reduce((a, b) => a + b) / quantities.length;
          // Округляем до ближайших 10 грамм для красоты
          final rounded = (average / 10).round() * 10;
          if (rounded > 0) {
            portionsContext.add(
                '  - "$name": $rounded г (обычно пользователь использует именно столько)');
          }
        }
      });

      // 5. Выявляем частые добавки, специи и соусы (встречаются >= 3 раза)
      final List<String> additionsContext = [];
      final totalMealsCount = allIngredientLists.length;

      ingredientOccurrences.forEach((name, count) {
        final isFrequent = count >= 3 ||
            (totalMealsCount >= 5 && count / totalMealsCount >= 0.2);

        if (isFrequent) {
          final quantities = ingredientQuantities[name] ?? [];
          final avgQuantity = quantities.isNotEmpty
              ? quantities.reduce((a, b) => a + b) / quantities.length
              : 0.0;

          final isSpiceOrAddition = avgQuantity > 0 && avgQuantity <= 15;
          final isCommonSpice = name.contains('перец') ||
              name.contains('соль') ||
              name.contains('масло') ||
              name.contains('чеснок') ||
              name.contains('укроп') ||
              name.contains('петрушка') ||
              name.contains('специ') ||
              name.contains('приправ');

          if (isSpiceOrAddition || isCommonSpice) {
            final qtyStr = avgQuantity > 0
                ? '${avgQuantity.toStringAsFixed(1)} г'
                : 'по вкусу';
            additionsContext.add(
                '  - "$name" ($qtyStr): добавляется почти во все совместимые горячие блюда и салаты');
          }
        }
      });

      final buffer = StringBuffer();
      buffer.writeln(
          '\n=== ПРЕДПОЧТЕНИЯ И ПРИВЫЧКИ ПОЛЬЗОВАТЕЛЯ (USER HABITS) ===');

      if (portionsContext.isNotEmpty) {
        buffer.writeln(
            'Типичные размеры порций (если встретишь эти ингредиенты, используй эти веса вместо стандартных):');
        buffer.writeln(portionsContext.join('\n'));
      }

      if (additionsContext.isNotEmpty) {
        buffer.writeln(
            'Частые специи/добавки (автоматически добавляй их в совместимые блюда с указанным весом):');
        buffer.writeln(additionsContext.join('\n'));
      }

      buffer.writeln(
          '========================================================\n');
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }
}
