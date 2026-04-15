import 'package:flutter/material.dart';
import 'package:nutri_log/services/recipe_loader.dart';

class Recipe {
  String id;
  String name;
  String description;
  // Changed to double to accommodate fractional values from new design
  Map<String, double> nutrients;
  List<String> ingredients;
  List<String> instructions;
  IconData icon;
  bool isUserRecipe;

  Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.nutrients = const {},
    this.ingredients = const [],
    this.instructions = const [],
    required this.icon,
    this.isUserRecipe = false,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Updated to parse to Map<String, double>
    final Map<String, double> nutrients = (json['nutrients'] as Map<String, dynamic>?)
        ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ?? {};

    return Recipe(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Без названия',
      description: json['description'] ?? '',
      nutrients: nutrients,
      ingredients: json['ingredients'] != null ? List<String>.from(json['ingredients']) : [],
      instructions: json['instructions'] != null ? List<String>.from(json['instructions']) : [],
      icon: RecipeLoader.getIcon(json['icon'] as String? ?? 'restaurant'),
      isUserRecipe: json['isUserRecipe'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'nutrients': nutrients, // Already Map<String, double>
      'ingredients': ingredients,
      'instructions': instructions,
      'icon': _iconToString(icon),
      'isUserRecipe': isUserRecipe,
    };
  }

  static String _iconToString(IconData icon) {
    return RecipeLoader.getIconName(icon);
  }
}
