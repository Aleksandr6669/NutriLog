import 'package:flutter/foundation.dart';

enum Gender {
  male,
  female,
}

@immutable
class UserProfile {
  final String name;
  final String? avatarImagePath; // Путь к файлу аватара
  final Gender gender;
  final int age;
  final int height;
  final double weight;
  final double weightGoal;
  final int calorieGoal;
  final int proteinGoal;
  final int fatGoal;
  final int carbsGoal;
  final int waterGoal; // в мл
  final int stepsGoal;
  final List<Map<String, dynamic>> weightHistory;

  const UserProfile({
    required this.name,
    this.avatarImagePath,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.weightGoal,
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
    int? age,
    int? height,
    double? weight,
    double? weightGoal,
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
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      weightGoal: weightGoal ?? this.weightGoal,
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
      age: json['age'] as int,
      height: json['height'] as int,
      weight: (json['weight'] as num).toDouble(),
      weightGoal: (json['weightGoal'] as num).toDouble(),
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
      'age': age,
      'height': height,
      'weight': weight,
      'weightGoal': weightGoal,
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
