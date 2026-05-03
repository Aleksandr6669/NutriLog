import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

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

enum ActivityFrequency {
  sedentary,
  light,
  moderate,
  active,
  veryActive,
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
  final ActivityFrequency activityFrequency;
  final String activityTypes;
  final String aiContext;
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
    required this.activityFrequency,
    required this.activityTypes,
    required this.aiContext,
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
    ActivityFrequency? activityFrequency,
    String? activityTypes,
    String? aiContext,
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
      activityFrequency: activityFrequency ?? this.activityFrequency,
      activityTypes: activityTypes ?? this.activityTypes,
      aiContext: aiContext ?? this.aiContext,
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
      activityFrequency: ActivityFrequency.values[
          (json['activityFrequency'] as int?) ?? ActivityFrequency.light.index],
      activityTypes: (json['activityTypes'] as String? ?? '').trim(),
      aiContext: (json['aiContext'] as String? ?? '').trim(),
      calorieGoal: json['calorieGoal'] as int,
      proteinGoal: json['proteinGoal'] as int,
      fatGoal: json['fatGoal'] as int,
      carbsGoal: json['carbsGoal'] as int,
      waterGoal: json['waterGoal'] as int,
      stepsGoal: json['stepsGoal'] as int,
      weightHistory: ((json['weightHistory'] as List<dynamic>?) ?? [])
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
      'activityFrequency': activityFrequency.index,
      'activityTypes': activityTypes,
      'aiContext': aiContext,
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

extension ActivityFrequencyX on ActivityFrequency {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ActivityFrequency.sedentary:
        return l10n.sedentary;
      case ActivityFrequency.light:
        return l10n.lightActivity;
      case ActivityFrequency.moderate:
        return l10n.moderateActivity;
      case ActivityFrequency.active:
        return l10n.activeActivity;
      case ActivityFrequency.veryActive:
        return l10n.veryActiveActivity;
    }
  }

  String get enLabel => ruLabel;

  String get ruLabel {
    switch (this) {
      case ActivityFrequency.sedentary:
        return 'Almost no activity';
      case ActivityFrequency.light:
        return 'Light activity 1-2 times per week';
      case ActivityFrequency.moderate:
        return 'Moderate activity 3-4 times per week';
      case ActivityFrequency.active:
        return 'Active lifestyle 5-6 times per week';
      case ActivityFrequency.veryActive:
        return 'Very high level, almost every day';
    }
  }

  String get enHint => ruHint;

  String get ruHint {
    switch (this) {
      case ActivityFrequency.sedentary:
        return 'Sedentary work, rare workouts and low step count.';
      case ActivityFrequency.light:
        return 'Occasional sports or walks, but no consistent schedule.';
      case ActivityFrequency.moderate:
        return 'Regular activity several times per week.';
      case ActivityFrequency.active:
        return 'Frequent workouts and a high average movement level.';
      case ActivityFrequency.veryActive:
        return 'Intense workouts and sports almost every day.';
    }
  }

  String localizedHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ActivityFrequency.sedentary:
        return l10n.activitySedentaryHint;
      case ActivityFrequency.light:
        return l10n.activityLightHint;
      case ActivityFrequency.moderate:
        return l10n.activityModerateHint;
      case ActivityFrequency.active:
        return l10n.activityActiveHint;
      case ActivityFrequency.veryActive:
        return l10n.activityVeryActiveHint;
    }
  }
}

extension GenderX on Gender {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case Gender.male:
        return l10n.male;
      case Gender.female:
        return l10n.female;
    }
  }

  String get enLabel => ruLabel;

  String get ruLabel {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
    }
  }
}

extension GoalTypeX on GoalType {
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case GoalType.loseWeight:
        return l10n.loseWeight;
      case GoalType.gainWeight:
        return l10n.gainWeight;
      case GoalType.gainMuscle:
        return l10n.gainMuscle;
      case GoalType.healthyEating:
        return l10n.healthyEating;
      case GoalType.energetic:
        return l10n.energetic;
    }
  }

  String get enLabel => ruLabel;

  String get ruLabel {
    switch (this) {
      case GoalType.loseWeight:
        return 'Lose weight';
      case GoalType.gainWeight:
        return 'Gain weight';
      case GoalType.gainMuscle:
        return 'Build muscle mass';
      case GoalType.healthyEating:
        return 'Healthy eating';
      case GoalType.energetic:
        return 'Energy throughout the day';
    }
  }

  String get enHint => ruHint;

  String get ruHint {
    switch (this) {
      case GoalType.loseWeight:
        return 'Gentle weight loss through a moderate calorie deficit, portion control, and a stable eating routine without harsh restrictions.';
      case GoalType.gainWeight:
        return 'Gradual weight gain through a careful calorie surplus, regular meals, and weekly progress tracking.';
      case GoalType.gainMuscle:
        return 'Muscle growth with a focus on protein, strength training, and recovery for noticeable and sustainable progress.';
      case GoalType.healthyEating:
        return 'A balanced daily diet: more whole foods, nutrient variety, and a comfortable rhythm without extremes.';
      case GoalType.energetic:
        return 'More energy throughout the day through regular meals, quality sleep, adequate hydration, and a steadier activity level.';
    }
  }

  String localizedHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case GoalType.loseWeight:
        return l10n.goalLoseWeightHint;
      case GoalType.gainWeight:
        return l10n.goalGainWeightHint;
      case GoalType.gainMuscle:
        return l10n.goalGainMuscleHint;
      case GoalType.healthyEating:
        return l10n.goalHealthyEatingHint;
      case GoalType.energetic:
        return l10n.goalEnergeticHint;
    }
  }
}
