import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

import '../services/daily_log_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _service = ProfileService();
  final DailyLogService _dailyLogService = DailyLogService();
  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    if (_profile != null && !_isLoading) return; // Уже загружено
    
    _isLoading = true;
    notifyListeners();
    
    await _dailyLogService.syncProfileWeightFromLogs();
    _profile = await _service.loadProfile();
    
    _isLoading = false;
    notifyListeners();
  }

  /// Сбрасывает кэш и перечитывает профиль из хранилища.
  /// Вызывать после онбординга или внешнего сохранения.
  Future<void> reloadProfile() async {
    _profile = null;
    await loadProfile();
  }

  Future<void> refreshProfile() async {
    await _dailyLogService.syncProfileWeightFromLogs();
    _profile = await _service.loadProfile();
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    await _service.saveProfile(newProfile);
    _profile = newProfile;
    notifyListeners();
  }
}
