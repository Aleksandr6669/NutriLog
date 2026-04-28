import 'dart:convert';
import 'package:nutri_log/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileString = prefs.getString(_profileKey);

    if (profileString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(profileString);
        return UserProfile.fromJson(jsonMap);
      } catch (e) {
        // Если данные повреждены, возвращаем профиль по умолчанию
        return _createAndSaveDefaultProfile();
      }
    } else {
      // Если данных нет, создаем профиль по умолчанию
      return _createAndSaveDefaultProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String profileString = json.encode(profile.toJson());
    await prefs.setString(_profileKey, profileString);
  }

  Future<UserProfile> _createAndSaveDefaultProfile() async {
    final defaultProfile = UserProfile(
      name: 'Пользователь',
      gender: Gender.female,
      birthDate: DateTime(1997, 6, 15),
      height: 168,
      weight: 62.5,
      weightGoal: 60.0,
      goalType: GoalType.healthyEating,
      activityFrequency: ActivityFrequency.light,
      activityTypes: '',
      aiContext: '',
      calorieGoal: 1800,
      proteinGoal: 120,
      fatGoal: 60,
      carbsGoal: 195,
      waterGoal: 2000,
      stepsGoal: 10000,
      weightHistory: const [],
    );
    await saveProfile(defaultProfile);
    return defaultProfile;
  }
}
