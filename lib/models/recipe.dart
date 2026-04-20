import 'package:flutter/material.dart';
import 'package:nutri_log/services/recipe_loader.dart';

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: (json['name'] as String? ?? '').trim(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] as String? ?? '').trim(),
    );
  }

  static RecipeIngredient fromDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      return RecipeIngredient.fromJson(value);
    }

    // Поддержка старого формата, где ингредиенты были строками.
    final fallbackName = (value as String? ?? '').trim();
    return RecipeIngredient(name: fallbackName, quantity: 0, unit: '');
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  String get displayValue {
    if (quantity <= 0 && unit.isEmpty) return name;

    final isInteger = quantity.truncateToDouble() == quantity;
    final quantityText =
        isInteger ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    final amountText = unit.isEmpty ? quantityText : '$quantityText $unit';
    return '$name — $amountText';
  }
}

class Recipe {
  String id;
  String name;
  String description;
  // Changed to double to accommodate fractional values from new design
  Map<String, double> nutrients;
  List<RecipeIngredient> ingredients;
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
    final Map<String, double> nutrients = (json['nutrients']
                as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, (value as num).toDouble())) ??
        {};
    final fallbackName = (json['name'] as String? ?? 'recipe').trim();
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? const [];
    final ingredients = rawIngredients
        .map(RecipeIngredient.fromDynamic)
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList();

    return Recipe(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : 'recipe_${DateTime.now().microsecondsSinceEpoch}_${fallbackName.hashCode}',
      name: json['name'] ?? 'Без названия',
      description: json['description'] ?? '',
      nutrients: nutrients,
      ingredients: ingredients,
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'])
          : [],
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
      'ingredients':
          ingredients.map((ingredient) => ingredient.toJson()).toList(),
      'instructions': instructions,
      'icon': _iconToString(icon),
      'isUserRecipe': isUserRecipe,
    };
  }

  static String _iconToString(IconData icon) {
    return RecipeLoader.getIconName(icon);
  }
}
