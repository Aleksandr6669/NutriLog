import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/cloud_data_service.dart';
import '../services/firebase_bootstrap_service.dart';
import '../services/profile_service.dart';

import '../services/daily_log_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _service = ProfileService();
  final DailyLogService _dailyLogService = DailyLogService();
  UserProfile? _profile;
  bool _isLoading = false;
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;
  StreamSubscription<void>? _cacheUpdatesSubscription;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  ProfileProvider() {
    _cacheUpdatesSubscription = ProfileService.cacheUpdates.listen((_) async {
      _profile = await _service.loadProfile();
      notifyListeners();
    });
    unawaited(_startRealtimeSyncSafely());
  }

  Future<void> _startRealtimeSyncSafely() async {
    try {
      await FirebaseBootstrapService.ensureInitialized();
      _startRealtimeSync();
    } catch (_) {
      // Firebase может быть недоступен на раннем старте/оффлайн:
      // профиль продолжит работать в local-first режиме.
    }
  }

  /// Подписывается на Firestore-документ профиля.
  /// Пропускает локальные записи (hasPendingWrites) чтобы не вызывать
  /// лишних перерисовок при сохранении с этого устройства.
  void _startRealtimeSync() {
    _syncSubscription?.cancel();
    _syncSubscription = CloudDataService.instance
        .docStream('profile')
        .listen((remoteData) async {
      if (remoteData == null || remoteData.isEmpty) return;
      try {
        await _service.saveProfileRaw(remoteData);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _cacheUpdatesSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (_profile != null && !_isLoading) {
      await _checkSubscriptionExpiration();
      return;
    }

    _isLoading = true;
    notifyListeners();

    await _dailyLogService.syncProfileWeightFromLogs();
    _profile = await _service.loadProfile();
    
    await _checkSubscriptionExpiration();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkSubscriptionExpiration() async {
    if (_profile == null || _profile!.tier == SubscriptionTier.free) return;
    if (_profile!.subscriptionUntil != null &&
        DateTime.now().isAfter(_profile!.subscriptionUntil!)) {
      final downgraded = _profile!.copyWith(
        tier: SubscriptionTier.free,
        subscriptionUntil: null,
      );
      await updateProfile(downgraded);
    }
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
