import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/recipe.dart';

class RecipeLoader {
  static const Map<String, IconData> _iconMap = {
    'restaurant': Symbols.restaurant,
    'lunch_dining': Symbols.lunch_dining,
    'local_bar': Symbols.local_bar,
    'cake': Symbols.cake,
    'fastfood': Symbols.fastfood,
    'breakfast_dining': Symbols.breakfast_dining,
    'ramen_dining': Symbols.ramen_dining,
    'icecream': Symbols.icecream,
    'local_pizza': Symbols.local_pizza,
    'set_meal': Symbols.set_meal,
    'dinner_dining': Symbols.dinner_dining,
    'blender': Symbols.blender,
    'soup_kitchen': Symbols.soup_kitchen,
    'coffee': Symbols.coffee,
    'wine_bar': Symbols.wine_bar,
    'liquor': Symbols.liquor,
    'bakery_dining': Symbols.bakery_dining,
    'egg': Symbols.egg,
    'egg_alt': Symbols.egg_alt,
    'cooking': Symbols.cooking,
    'kebab_dining': Symbols.kebab_dining,
    'takeout_dining': Symbols.takeout_dining,
    'rice_bowl': Symbols.rice_bowl,
    'cookie': Symbols.cookie,
    'donut_large': Symbols.donut_large,
    'local_cafe': Symbols.local_cafe,
    'local_drink': Symbols.local_drink,
    'tapas': Symbols.tapas,
    'flatware': Symbols.flatware,
    'outdoor_grill': Symbols.outdoor_grill,
    'kitchen': Symbols.kitchen,
    'microwave': Symbols.microwave,
    'skillet': Symbols.skillet,
    'nutrition': Symbols.nutrition,
    'eco': Symbols.eco,
    'restaurant_menu': Symbols.restaurant_menu,
  };

  static Future<List<Recipe>> loadRecipesFromAssets(
      {String locale = 'ru'}) async {
    final String response =
        await rootBundle.loadString('assets/data/recipes.json');
    final List<dynamic> data = json.decode(response);

    // Загружаем i18n-переводы для всех языков
    Map<String, dynamic> i18n = {};
    try {
      final String i18nRaw =
          await rootBundle.loadString('assets/data/recipes_i18n.json');
      i18n = json.decode(i18nRaw) as Map<String, dynamic>;
    } catch (_) {}

    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final source = entry.value as Map<String, dynamic>;
      final normalized = Map<String, dynamic>.from(source);
      final rawId = (normalized['id'] as String?)?.trim() ?? '';
      if (rawId.isEmpty) {
        normalized['id'] = 'builtin_$index';
      }

      // Применяем перевод если есть
      final id = normalized['id'] as String;
      final translation =
          (i18n[id] as Map<String, dynamic>?)?[locale] as Map<String, dynamic>?;
      if (translation != null) {
        if (translation['name'] != null) {
          normalized['name'] = translation['name'];
        }
        if (translation['description'] != null) {
          normalized['description'] = translation['description'];
        }

        // Переводим ингредиенты: заменяем name и unit, quantity оставляем из оригинала
        final transIngredients = translation['ingredients'] as List<dynamic>?;
        final origIngredients = normalized['ingredients'] as List<dynamic>?;
        if (transIngredients != null &&
            origIngredients != null &&
            transIngredients.length == origIngredients.length) {
          normalized['ingredients'] =
              List.generate(transIngredients.length, (i) {
            final orig = Map<String, dynamic>.from(origIngredients[i] as Map);
            final trans = transIngredients[i] as Map<String, dynamic>;
            if (trans['name'] != null) orig['name'] = trans['name'];
            if (trans['unit'] != null) orig['unit'] = trans['unit'];
            return orig;
          });
        }

        if (translation['instructions'] != null) {
          normalized['instructions'] = translation['instructions'];
        }
      }

      return Recipe.fromJson(normalized);
    }).toList();
  }

  static IconData getIcon(String iconName) {
    final normalizedName = iconName.startsWith('Symbols.')
        ? iconName.substring('Symbols.'.length)
        : iconName;
    return _iconMap[normalizedName] ?? Symbols.restaurant;
  }

  static String getIconName(IconData icon) {
    for (final entry in _iconMap.entries) {
      if (entry.value == icon) return entry.key;
    }
    return 'restaurant';
  }
}
