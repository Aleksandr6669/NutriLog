import 'package:flutter/foundation.dart';

@immutable
class IngredientProduct {
  final String name; // Уникальное имя (будет в нижнем регистре для поиска)
  final Map<String, double>
      nutrients; // КБЖУ, витамины, минералы, металлы, токсины на 100г (или на 1 шт/упаковку)
  final double?
      weightPerUnit; // Вес в граммах одной штуки (pcs), ложки (tsp/tbsp) или упаковки (pack)
  final bool isReadyProduct; // Готовый упакованный продукт
  final DateTime updatedAt; // Время последнего обновления (для синхронизации)
  final DateTime
      lastAccessedAt; // Время последнего использования (для LRU кэша)

  const IngredientProduct({
    required this.name,
    required this.nutrients,
    this.weightPerUnit,
    this.isReadyProduct = false,
    required this.updatedAt,
    required this.lastAccessedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'nutrients': nutrients,
      'weightPerUnit': weightPerUnit,
      'isReadyProduct': isReadyProduct,
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }

  factory IngredientProduct.fromJson(Map<String, dynamic> json) {
    final rawNutrients = json['nutrients'] as Map<String, dynamic>? ?? const {};
    final Map<String, double> nutrients = rawNutrients.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return IngredientProduct(
      name: (json['name'] as String? ?? '').trim(),
      nutrients: nutrients,
      weightPerUnit: (json['weightPerUnit'] as num?)?.toDouble(),
      isReadyProduct: json['isReadyProduct'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String)
          : DateTime.now(),
    );
  }

  IngredientProduct copyWith({
    String? name,
    Map<String, double>? nutrients,
    double? weightPerUnit,
    bool? isReadyProduct,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
  }) {
    return IngredientProduct(
      name: name ?? this.name,
      nutrients: nutrients ?? this.nutrients,
      weightPerUnit: weightPerUnit ?? this.weightPerUnit,
      isReadyProduct: isReadyProduct ?? this.isReadyProduct,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}
