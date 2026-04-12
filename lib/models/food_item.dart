import 'package:flutter/material.dart';

class NutritionalInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  // Detailed breakdown
  final double saturatedFat;
  final double polyunsaturatedFat;
  final double monounsaturatedFat;
  final double transFat;
  final double cholesterol; // mg
  final double sodium; // mg
  final double potassium; // mg
  final double fiber;
  final double sugar;
  // Vitamins & Minerals in absolute values
  final double vitaminA; // mcg (micrograms)
  final double vitaminC; // mg
  final double vitaminD; // mcg (micrograms) / IU
  final double calcium;  // mg
  final double iron;     // mg

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.saturatedFat = 0,
    this.polyunsaturatedFat = 0,
    this.monounsaturatedFat = 0,
    this.transFat = 0,
    this.cholesterol = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.vitaminA = 0,
    this.vitaminC = 0,
    this.vitaminD = 0,
    this.calcium = 0,
    this.iron = 0,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      saturatedFat: (json['saturatedFat'] as num?)?.toDouble() ?? 0.0,
      polyunsaturatedFat: (json['polyunsaturatedFat'] as num?)?.toDouble() ?? 0.0,
      monounsaturatedFat: (json['monounsaturatedFat'] as num?)?.toDouble() ?? 0.0,
      transFat: (json['transFat'] as num?)?.toDouble() ?? 0.0,
      cholesterol: (json['cholesterol'] as num?)?.toDouble() ?? 0.0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
      potassium: (json['potassium'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      vitaminA: (json['vitaminA'] as num?)?.toDouble() ?? 0,
      vitaminC: (json['vitaminC'] as num?)?.toDouble() ?? 0,
      vitaminD: (json['vitaminD'] as num?)?.toDouble() ?? 0,
      calcium: (json['calcium'] as num?)?.toDouble() ?? 0,
      iron: (json['iron'] as num?)?.toDouble() ?? 0,
    );
  }

  static NutritionalInfo get zero => NutritionalInfo(calories: 0, protein: 0, carbs: 0, fat: 0);

  NutritionalInfo operator +(NutritionalInfo other) {
    return NutritionalInfo(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
      saturatedFat: saturatedFat + other.saturatedFat,
      polyunsaturatedFat: polyunsaturatedFat + other.polyunsaturatedFat,
      monounsaturatedFat: monounsaturatedFat + other.monounsaturatedFat,
      transFat: transFat + other.transFat,
      cholesterol: cholesterol + other.cholesterol,
      sodium: sodium + other.sodium,
      potassium: potassium + other.potassium,
      fiber: fiber + other.fiber,
      sugar: sugar + other.sugar,
      vitaminA: vitaminA + other.vitaminA,
      vitaminC: vitaminC + other.vitaminC,
      vitaminD: vitaminD + other.vitaminD,
      calcium: calcium + other.calcium,
      iron: iron + other.iron,
    );
  }
}

class FoodItem {
  final IconData icon;
  final String name;
  final String description;
  final NutritionalInfo nutrients;

  FoodItem({
    required this.icon,
    required this.name,
    required this.description,
    required this.nutrients,
  });
}
