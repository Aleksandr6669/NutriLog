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

  static Future<List<Recipe>> loadRecipesFromAssets() async {
    final String response = await rootBundle.loadString('assets/data/recipes.json');
    // JSON верхнего уровня - это список, а не объект с ключом 'recipes'
    final List<dynamic> data = await json.decode(response);
    return data.map((json) => Recipe.fromJson(json)).toList();
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
