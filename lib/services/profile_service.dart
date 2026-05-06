import 'dart:convert';
import 'package:nutri_log/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_data_service.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';

  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileString = prefs.getString(_profileKey);

    UserProfile localProfile;
    bool hasLocalProfile = false;

    if (profileString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(profileString);
        localProfile = UserProfile.fromJson(jsonMap);
        hasLocalProfile = true;
      } catch (e) {
        localProfile = _createDefaultProfile();
      }
    } else {
      localProfile = _createDefaultProfile();
    }

    try {
      final cloud = CloudDataService.instance;
      final cloudMap = await cloud.readMap('profile');
      if (cloudMap != null && cloudMap.isNotEmpty) {
        final cloudProfile = UserProfile.fromJson(cloudMap);
        await saveProfile(cloudProfile);
        return cloudProfile;
      }

      if (hasLocalProfile && cloud.isSignedIn) {
        await cloud.writeMap('profile', localProfile.toJson());
      }
    } catch (_) {
      // Если облако недоступно, используем локальные данные.
    }

    return localProfile;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String profileString = json.encode(profile.toJson());
    await prefs.setString(_profileKey, profileString);

    try {
      await CloudDataService.instance.writeMap('profile', profile.toJson());
    } catch (_) {
      // Локальное сохранение уже выполнено.
    }
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
