import 'package:flutter/material.dart';

class NutritionalInfo {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double alcohol;
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
  final double calcium; // mg
  final double iron; // mg
  final double vitaminE; // mg
  final double vitaminK; // mcg
  final double vitaminB1; // mg
  final double vitaminB2; // mg
  final double vitaminB3; // mg
  final double vitaminB5; // mg
  final double vitaminB6; // mg
  final double vitaminB7; // mcg
  final double vitaminB9; // mcg
  final double vitaminB12; // mcg
  final double magnesium; // mg
  final double phosphorus; // mg
  final double zinc; // mg
  final double copper; // mg
  final double manganese; // mg
  final double selenium; // mcg
  final double iodine; // mcg
  final double chromium; // mcg
  final double molybdenum; // mcg
  final double fluoride; // mg
  final double lead; // mcg
  final double mercury; // mcg
  final double cadmium; // mcg
  final double arsenic; // mcg
  final double nitrates; // mg
  final double pesticides; // mcg

  NutritionalInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.alcohol = 0,
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
    this.vitaminE = 0,
    this.vitaminK = 0,
    this.vitaminB1 = 0,
    this.vitaminB2 = 0,
    this.vitaminB3 = 0,
    this.vitaminB5 = 0,
    this.vitaminB6 = 0,
    this.vitaminB7 = 0,
    this.vitaminB9 = 0,
    this.vitaminB12 = 0,
    this.magnesium = 0,
    this.phosphorus = 0,
    this.zinc = 0,
    this.copper = 0,
    this.manganese = 0,
    this.selenium = 0,
    this.iodine = 0,
    this.chromium = 0,
    this.molybdenum = 0,
    this.fluoride = 0,
    this.lead = 0,
    this.mercury = 0,
    this.cadmium = 0,
    this.arsenic = 0,
    this.nitrates = 0,
    this.pesticides = 0,
  });

  factory NutritionalInfo.fromJson(Map<String, dynamic> json) {
    return NutritionalInfo(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      alcohol: (json['alcohol'] as num?)?.toDouble() ?? 0.0,
      saturatedFat: (json['saturatedFat'] as num?)?.toDouble() ?? 0.0,
      polyunsaturatedFat:
          (json['polyunsaturatedFat'] as num?)?.toDouble() ?? 0.0,
      monounsaturatedFat:
          (json['monounsaturatedFat'] as num?)?.toDouble() ?? 0.0,
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
      vitaminE: (json['vitaminE'] as num?)?.toDouble() ?? 0,
      vitaminK: (json['vitaminK'] as num?)?.toDouble() ?? 0,
      vitaminB1: (json['vitaminB1'] as num?)?.toDouble() ?? 0,
      vitaminB2: (json['vitaminB2'] as num?)?.toDouble() ?? 0,
      vitaminB3: (json['vitaminB3'] as num?)?.toDouble() ?? 0,
      vitaminB5: (json['vitaminB5'] as num?)?.toDouble() ?? 0,
      vitaminB6: (json['vitaminB6'] as num?)?.toDouble() ?? 0,
      vitaminB7: (json['vitaminB7'] as num?)?.toDouble() ?? 0,
      vitaminB9: (json['vitaminB9'] as num?)?.toDouble() ?? 0,
      vitaminB12: (json['vitaminB12'] as num?)?.toDouble() ?? 0,
      magnesium: (json['magnesium'] as num?)?.toDouble() ?? 0,
      phosphorus: (json['phosphorus'] as num?)?.toDouble() ?? 0,
      zinc: (json['zinc'] as num?)?.toDouble() ?? 0,
      copper: (json['copper'] as num?)?.toDouble() ?? 0,
      manganese: (json['manganese'] as num?)?.toDouble() ?? 0,
      selenium: (json['selenium'] as num?)?.toDouble() ?? 0,
      iodine: (json['iodine'] as num?)?.toDouble() ?? 0,
      chromium: (json['chromium'] as num?)?.toDouble() ?? 0,
      molybdenum: (json['molybdenum'] as num?)?.toDouble() ?? 0,
      fluoride: (json['fluoride'] as num?)?.toDouble() ?? 0,
      lead: (json['lead'] as num?)?.toDouble() ?? 0,
      mercury: (json['mercury'] as num?)?.toDouble() ?? 0,
      cadmium: (json['cadmium'] as num?)?.toDouble() ?? 0,
      arsenic: (json['arsenic'] as num?)?.toDouble() ?? 0,
      nitrates: (json['nitrates'] as num?)?.toDouble() ?? 0,
      pesticides: (json['pesticides'] as num?)?.toDouble() ?? 0,
    );
  }

  static NutritionalInfo get zero =>
      NutritionalInfo(calories: 0, protein: 0, carbs: 0, fat: 0);

  NutritionalInfo operator +(NutritionalInfo other) {
    return NutritionalInfo(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
      alcohol: alcohol + other.alcohol,
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
      vitaminE: vitaminE + other.vitaminE,
      vitaminK: vitaminK + other.vitaminK,
      vitaminB1: vitaminB1 + other.vitaminB1,
      vitaminB2: vitaminB2 + other.vitaminB2,
      vitaminB3: vitaminB3 + other.vitaminB3,
      vitaminB5: vitaminB5 + other.vitaminB5,
      vitaminB6: vitaminB6 + other.vitaminB6,
      vitaminB7: vitaminB7 + other.vitaminB7,
      vitaminB9: vitaminB9 + other.vitaminB9,
      vitaminB12: vitaminB12 + other.vitaminB12,
      magnesium: magnesium + other.magnesium,
      phosphorus: phosphorus + other.phosphorus,
      zinc: zinc + other.zinc,
      copper: copper + other.copper,
      manganese: manganese + other.manganese,
      selenium: selenium + other.selenium,
      iodine: iodine + other.iodine,
      chromium: chromium + other.chromium,
      molybdenum: molybdenum + other.molybdenum,
      fluoride: fluoride + other.fluoride,
      lead: lead + other.lead,
      mercury: mercury + other.mercury,
      cadmium: cadmium + other.cadmium,
      arsenic: arsenic + other.arsenic,
      nitrates: nitrates + other.nitrates,
      pesticides: pesticides + other.pesticides,
    );
  }
}

class FoodItem {
  final String? id;
  final IconData icon;
  final String name;
  final String description;
  final NutritionalInfo nutrients;
  final List<Map<String, dynamic>> recipeIngredients;
  final List<String> recipeInstructions;

  FoodItem({
    this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.nutrients,
    this.recipeIngredients = const [],
    this.recipeInstructions = const [],
  });
}
