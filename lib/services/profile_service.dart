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
    if (profileString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(profileString);
        localProfile = UserProfile.fromJson(jsonMap);
      } catch (e) {
        localProfile = _createDefaultProfile();
      }
    } else {
      localProfile = _createDefaultProfile();
    }

    return localProfile;
  }

  Future<void> syncWithCloud() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return;

    final localProfile = await loadProfile();
    final cloudMap = await cloud.readMap('profile');

    if (cloudMap != null && cloudMap.isNotEmpty) {
      final cloudProfile = UserProfile.fromJson(cloudMap);
      // Локальные данные приоритетны: облаком заполняем только пустой профиль.
      final hasMeaningfulLocalData = localProfile.name.trim().isNotEmpty ||
          localProfile.height > 0 ||
          localProfile.weight > 0 ||
          localProfile.calorieGoal > 0;
      if (!hasMeaningfulLocalData) {
        await saveProfile(cloudProfile);
        return;
      }
    }

    await cloud.writeMap('profile', localProfile.toJson());
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
