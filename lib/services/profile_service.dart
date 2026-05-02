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
        return _createDefaultProfile();
      }
    } else {
      return _createDefaultProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String profileString = json.encode(profile.toJson());
    await prefs.setString(_profileKey, profileString);
  }

  UserProfile _createDefaultProfile() {
    return UserProfile(
      name: '',
      gender: Gender.female,
      birthDate: DateTime(2000, 1, 1),
      height: 0,
      weight: 0.0,
      weightGoal: 0.0,
      goalType: GoalType.healthyEating,
      activityFrequency: ActivityFrequency.light,
      activityTypes: '',
      aiContext: '',
      calorieGoal: 0,
      proteinGoal: 0,
      fatGoal: 0,
      carbsGoal: 0,
      waterGoal: 0,
      stepsGoal: 0,
      weightHistory: const [],
    );
  }
}
