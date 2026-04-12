import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/recipe.dart';

class RecipeLoader {
  static Future<List<Recipe>> loadRecipesFromAssets() async {
    final String response = await rootBundle.loadString('assets/data/recipes.json');
    // JSON верхнего уровня - это список, а не объект с ключом 'recipes'
    final List<dynamic> data = await json.decode(response);
    return data.map((json) => Recipe.fromJson(json)).toList();
  }

  static IconData getIcon(String iconName) {
    // Расширяем сопоставление, чтобы включить все иконки из JSON
    switch (iconName) {
      case 'breakfast_dining':
        return Symbols.breakfast_dining;
      case 'lunch_dining':
        return Symbols.lunch_dining;
      case 'ramen_dining':
        return Symbols.ramen_dining;
      case 'local_bar':
        return Symbols.local_bar;
      case 'set_meal':
        return Symbols.set_meal;
      case 'restaurant':
        return Symbols.restaurant;
      case 'dinner_dining':
        return Symbols.dinner_dining;
      case 'blender':
        return Symbols.blender;
      case 'soup_kitchen':
        return Symbols.soup_kitchen;
      case 'cake':
        return Symbols.cake;
      // Добавляем ранее существовавшие, чтобы ничего не сломать
      case 'Symbols.restaurant':
        return Symbols.restaurant;
      case 'Symbols.lunch_dining':
        return Symbols.lunch_dining;
      case 'Symbols.local_bar':
        return Symbols.local_bar;
      case 'Symbols.cake':
        return Symbols.cake;
      case 'Symbols.fastfood':
        return Symbols.fastfood;
      case 'Symbols.breakfast_dining':
        return Symbols.breakfast_dining;
      case 'Symbols.ramen_dining':
        return Symbols.ramen_dining;
      case 'Symbols.icecream':
        return Symbols.icecream;
      case 'Symbols.local_pizza':
        return Symbols.local_pizza;
      default:
        return Symbols.restaurant; // Иконка по умолчанию
    }
  }
}
