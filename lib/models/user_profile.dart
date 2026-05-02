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
  String get ruLabel {
    switch (this) {
      case ActivityFrequency.sedentary:
        return 'Почти нет активности';
      case ActivityFrequency.light:
        return 'Легкая активность 1-2 раза в неделю';
      case ActivityFrequency.moderate:
        return 'Умеренная активность 3-4 раза в неделю';
      case ActivityFrequency.active:
        return 'Активный режим 5-6 раз в неделю';
      case ActivityFrequency.veryActive:
        return 'Очень высокий уровень, почти каждый день';
    }
  }

  String get ruHint {
    switch (this) {
      case ActivityFrequency.sedentary:
        return 'Сидячая работа, редкие тренировки и мало шагов.';
      case ActivityFrequency.light:
        return 'Иногда спорт или прогулки, но без стабильного графика.';
      case ActivityFrequency.moderate:
        return 'Регулярная активность несколько раз в неделю.';
      case ActivityFrequency.active:
        return 'Частые тренировки и высокий средний уровень движения.';
      case ActivityFrequency.veryActive:
        return 'Интенсивные нагрузки и спорт почти ежедневно.';
    }
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

  String get ruHint {
    switch (this) {
      case GoalType.loseWeight:
        return 'Мягкое снижение веса за счет умеренного дефицита калорий, контроля порций и стабильного режима питания без резких ограничений.';
      case GoalType.gainWeight:
        return 'Постепенный набор веса через аккуратный профицит калорий, регулярные приемы пищи и отслеживание динамики каждую неделю.';
      case GoalType.gainMuscle:
        return 'Рост мышечной массы с фокусом на белок, силовые тренировки и восстановление, чтобы прогресс был заметным и устойчивым.';
      case GoalType.healthyEating:
        return 'Сбалансированный рацион на каждый день: больше цельных продуктов, разнообразие нутриентов и комфортный ритм без перегибов.';
      case GoalType.energetic:
        return 'Больше энергии на весь день за счет регулярного питания, качественного сна, достаточной воды и более ровного уровня активности.';
    }
  }
}
