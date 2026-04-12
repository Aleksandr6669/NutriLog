import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String userName;
  final double weight;
  final double weightGoal;
  final int calorieGoal;
  final int waterGoal; // в мл
  final int activityGoal; // в ккал
  final int stepsGoal;
  final int proteinGoal; // в граммах
  final int carbsGoal; // в граммах
  final int fatGoal; // в граммах
  final List<WeightEntry> weightHistory;

  const UserProfile({
    required this.userName,
    required this.weight,
    required this.weightGoal,
    required this.calorieGoal,
    required this.waterGoal,
    required this.activityGoal,
    required this.stepsGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.weightHistory,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var weightHistoryFromJson = json['weightHistory'] as List? ?? [];
    List<WeightEntry> weightHistoryList = weightHistoryFromJson
        .map((i) => WeightEntry.fromJson(i))
        .toList();

    return UserProfile(
      userName: json['userName'] ?? 'Пользователь',
      weight: (json['userWeight'] as num?)?.toDouble() ?? 0,
      weightGoal: (json['weightGoal'] as num?)?.toDouble() ?? 0,
      calorieGoal: json['calorieGoal'] ?? 0,
      waterGoal: json['waterGoal'] ?? 0,
      activityGoal: json['activityGoal'] ?? 0,
      stepsGoal: json['stepsGoal'] ?? 0,
      proteinGoal: json['proteinGoal'] ?? 0,
      carbsGoal: json['carbsGoal'] ?? 0,
      fatGoal: json['fatGoal'] ?? 0,
      weightHistory: weightHistoryList,
    );
  }

  UserProfile copyWith({
    String? userName,
    double? weight,
    double? weightGoal,
    int? calorieGoal,
    int? waterGoal,
    int? activityGoal,
    int? stepsGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    List<WeightEntry>? weightHistory,
  }) {
    return UserProfile(
      userName: userName ?? this.userName,
      weight: weight ?? this.weight,
      weightGoal: weightGoal ?? this.weightGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      waterGoal: waterGoal ?? this.waterGoal,
      activityGoal: activityGoal ?? this.activityGoal,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      weightHistory: weightHistory ?? this.weightHistory,
    );
  }
}

@immutable
class WeightEntry {
  final DateTime date;
  final double weight;

  const WeightEntry({required this.date, required this.weight});

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }
}
