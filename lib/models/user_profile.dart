import 'package:flutter/foundation.dart';

enum Gender {
  male,
  female,
}

enum GoalType {
  loseWeight,
  gainWeight,
  gainMuscle,
  healthyEating,
  energetic,
}

@immutable
class UserProfile {
  final String name;
  final String? avatarImagePath; // Путь к файлу аватара
  final Gender gender;
  final DateTime birthDate;
  final int height;
  final double weight;
  final double weightGoal;
  final GoalType goalType;
  final int calorieGoal;
  final int proteinGoal;
  final int fatGoal;
  final int carbsGoal;
  final int waterGoal; // в мл
  final int stepsGoal;
  final List<Map<String, dynamic>> weightHistory;

  int get age {
    final today = DateTime.now();
    int years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years;
  }

  const UserProfile({
    required this.name,
    this.avatarImagePath,
    required this.gender,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.weightGoal,
    required this.goalType,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.waterGoal,
    required this.stepsGoal,
    required this.weightHistory,
  });

  UserProfile copyWith({
    String? name,
    String? avatarImagePath,
    Gender? gender,
    DateTime? birthDate,
    int? height,
    double? weight,
    double? weightGoal,
    GoalType? goalType,
    int? calorieGoal,
    int? proteinGoal,
    int? fatGoal,
    int? carbsGoal,
    int? waterGoal,
    int? stepsGoal,
    List<Map<String, dynamic>>? weightHistory,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      weightGoal: weightGoal ?? this.weightGoal,
      goalType: goalType ?? this.goalType,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      waterGoal: waterGoal ?? this.waterGoal,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      weightHistory: weightHistory ?? this.weightHistory,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      avatarImagePath: json['avatarImagePath'] as String?,
      gender: Gender.values[json['gender'] as int],
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : DateTime.now()
              .subtract(Duration(days: (json['age'] as int? ?? 25) * 365)),
      height: json['height'] as int,
      weight: (json['weight'] as num).toDouble(),
      weightGoal: (json['weightGoal'] as num).toDouble(),
      goalType: GoalType
          .values[(json['goalType'] as int?) ?? GoalType.healthyEating.index],
      calorieGoal: json['calorieGoal'] as int,
      proteinGoal: json['proteinGoal'] as int,
      fatGoal: json['fatGoal'] as int,
      carbsGoal: json['carbsGoal'] as int,
      waterGoal: json['waterGoal'] as int,
      stepsGoal: json['stepsGoal'] as int,
      weightHistory: (json['weightHistory'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarImagePath': avatarImagePath,
      'gender': gender.index,
      'birthDate': birthDate.toIso8601String(),
      'height': height,
      'weight': weight,
      'weightGoal': weightGoal,
      'goalType': goalType.index,
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'fatGoal': fatGoal,
      'carbsGoal': carbsGoal,
      'waterGoal': waterGoal,
      'stepsGoal': stepsGoal,
      'weightHistory': weightHistory,
    };
  }
}

extension GenderX on Gender {
  String get ruLabel {
    switch (this) {
      case Gender.male:
        return 'Мужской';
      case Gender.female:
        return 'Женский';
    }
  }
}

extension GoalTypeX on GoalType {
  String get ruLabel {
    switch (this) {
      case GoalType.loseWeight:
        return 'Сбросить вес';
      case GoalType.gainWeight:
        return 'Набрать вес';
      case GoalType.gainMuscle:
        return 'Набрать мышечную массу';
      case GoalType.healthyEating:
        return 'Здоровое питание';
      case GoalType.energetic:
        return 'Энергия на весь день';
    }
  }
}
