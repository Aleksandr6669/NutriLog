import 'dart:async';
import 'dart:convert';
import 'package:nutri_log/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_data_service.dart';

class ProfileService {
  /// Очищает локальный кеш профиля пользователя
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }

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
    // Phone-first: облако всегда обновляется локальным состоянием.
    await cloud.writeMap('profile', localProfile.toJson());
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final String profileString = json.encode(profile.toJson());
    await prefs.setString(_profileKey, profileString);

    // Не ждём сеть: локальное сохранение уже завершено, облако синкаем в фоне.
    unawaited(_syncProfileToCloudInBackground(profile));
  }

  Future<void> _syncProfileToCloudInBackground(UserProfile profile) async {
    try {
      await CloudDataService.instance.writeMap('profile', profile.toJson());
    } catch (_) {
      // Повтор произойдёт при следующем цикле локально-first синхронизации.
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
