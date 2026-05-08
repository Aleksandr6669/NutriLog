import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'firebase_auth_service.dart';
import 'cloud_data_service.dart';
import 'daily_log_service.dart';
import 'profile_service.dart';
import 'recipe_service.dart';

enum SyncStatus { idle, syncing, synced, error }

enum SignInDataResolution {
  keepLocal,
  useCloud,
}

class LocalFirstSyncService {
  LocalFirstSyncService._();

  static final LocalFirstSyncService instance = LocalFirstSyncService._();

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier(SyncStatus.idle);
  DateTime? lastSyncedAt;

  StreamSubscription? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>?>? _profileDocSubscription;
  StreamSubscription<Map<String, dynamic>?>? _dailyLogsDocSubscription;
  StreamSubscription<Map<String, dynamic>?>? _recipesDocSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _publicRecipesSubscription;
  Timer? _periodicSyncTimer;
  Timer? _realtimePullDebounce;
  bool _started = false;
  bool _isSyncing = false;
  bool _isApplyingRemote = false;
  bool _signInConflictResolutionPending = false;
  bool _wasConnected = false;
  String? _preparedUid;

  void start() {
    if (_started) return;
    if (CloudDataService.instance.isLocalOnlyMode) {
      statusNotifier.value = SyncStatus.idle;
      return;
    }
    _started = true;

    _authSubscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) async {
        if (user == null) {
          _preparedUid = null;
          _signInConflictResolutionPending = false;
          _cancelRealtimeSubscriptions();
          return;
        }

        if (_preparedUid != user.uid) {
          _preparedUid = user.uid;
          _setupRealtimeSubscriptions();
          return;
        }

        syncNow();
      },
    );

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_wasConnected) {
        _wasConnected = true;
        syncNow();
      } else if (!hasConnection) {
        _wasConnected = false;
      }
    });

    // Проверяем начальное состояние сети
    Connectivity().checkConnectivity().then((results) {
      _wasConnected = results.any((r) => r != ConnectivityResult.none);
    });

    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => syncNow(),
    );

    syncNow();
  }

  Future<void> syncNow() async {
    if (CloudDataService.instance.isLocalOnlyMode) {
      statusNotifier.value = SyncStatus.idle;
      return;
    }
    if (_signInConflictResolutionPending) return;
    if (_isSyncing || !FirebaseAuthService.instance.isSignedIn) return;

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;
    try {
      await ProfileService().syncWithCloud();
      await DailyLogService().syncWithCloud();
      await RecipeService().syncWithCloud();
      lastSyncedAt = DateTime.now();
      statusNotifier.value = SyncStatus.synced;
    } catch (_) {
      statusNotifier.value = SyncStatus.error;
      // Все данные уже записаны локально. Следующий retry догонит облако.
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> hasLocalData() async {
    final profile = await ProfileService().loadProfile();
    final hasProfile = profile.name.trim().isNotEmpty ||
        profile.height > 0 ||
        profile.weight > 0 ||
        profile.calorieGoal > 0 ||
        profile.proteinGoal > 0 ||
        profile.fatGoal > 0 ||
        profile.carbsGoal > 0 ||
        profile.waterGoal > 0 ||
        profile.stepsGoal > 0;

    final hasDiary = (await DailyLogService().getLoggedDates()).isNotEmpty;
    final recipes =
        await RecipeService().loadUserRecipes(refreshPublicInBackground: false);
    final hasOwnRecipes = recipes.any((recipe) => recipe.isUserRecipe);

    return hasProfile || hasDiary || hasOwnRecipes;
  }

  Future<bool> hasCloudData() async {
    final cloud = CloudDataService.instance;
    if (!cloud.isSignedIn) return false;

    final remoteProfile = await cloud.readMap('profile');
    final remoteDaily = await cloud.readMap('daily_logs');
    final remoteRecipes = await cloud.readMap('recipes');

    final hasProfile = remoteProfile != null && remoteProfile.isNotEmpty;
    final hasDiary = remoteDaily != null &&
        remoteDaily['logs'] is Map<String, dynamic> &&
        (remoteDaily['logs'] as Map<String, dynamic>).isNotEmpty;
    final hasRecipes = remoteRecipes != null &&
        remoteRecipes['recipes'] is List &&
        (remoteRecipes['recipes'] as List).isNotEmpty;

    return hasProfile || hasDiary || hasRecipes;
  }

  Future<bool> needsSignInConflictResolution() async {
    if (!FirebaseAuthService.instance.isSignedIn) return false;
    final local = await hasLocalData();
    if (!local) {
      _signInConflictResolutionPending = false;
      return false;
    }
    final cloud = await hasCloudData();
    _signInConflictResolutionPending = cloud;
    return cloud;
  }

  Future<void> resolveSignInDataConflict(SignInDataResolution resolution) async {
    try {
      if (resolution == SignInDataResolution.useCloud) {
        _signInConflictResolutionPending = false;
        await _resetLocalAndPullFromCloud();
        return;
      }

      _signInConflictResolutionPending = false;
      await syncNow();
    } finally {
      _signInConflictResolutionPending = false;
    }
  }

  Future<void> _resetLocalAndPullFromCloud() async {
    if (_isSyncing || !FirebaseAuthService.instance.isSignedIn) return;

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;
    try {
      await ProfileService.clearCache();
      await DailyLogService.clearCache();
      await RecipeService.clearCache();

      await ProfileService().pullFromCloudReplaceLocal();
      await DailyLogService().pullFromCloudReplaceLocal();
      await RecipeService().pullFromCloudReplaceLocal();

      lastSyncedAt = DateTime.now();
      statusNotifier.value = SyncStatus.synced;
    } catch (_) {
      statusNotifier.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  void _setupRealtimeSubscriptions() {
    _cancelRealtimeSubscriptions();

    _profileDocSubscription =
        CloudDataService.instance.docStream('profile').listen((_) {
      _scheduleRealtimePull();
    });

    _dailyLogsDocSubscription =
        CloudDataService.instance.docStream('daily_logs').listen((_) {
      _scheduleRealtimePull();
    });

    _recipesDocSubscription =
        CloudDataService.instance.docStream('recipes').listen((_) {
      _scheduleRealtimePull();
    });

    _publicRecipesSubscription =
        CloudDataService.instance.collectionStream('publicRecipes').listen((_) {
      _scheduleRealtimePull();
    });
  }

  void _cancelRealtimeSubscriptions() {
    _realtimePullDebounce?.cancel();
    _profileDocSubscription?.cancel();
    _dailyLogsDocSubscription?.cancel();
    _recipesDocSubscription?.cancel();
    _publicRecipesSubscription?.cancel();
    _profileDocSubscription = null;
    _dailyLogsDocSubscription = null;
    _recipesDocSubscription = null;
    _publicRecipesSubscription = null;
  }

  void _scheduleRealtimePull() {
    if (!FirebaseAuthService.instance.isSignedIn) return;
    _realtimePullDebounce?.cancel();
    _realtimePullDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_pullFromCloudInBackground());
    });
  }

  Future<void> _pullFromCloudInBackground() async {
    if (_signInConflictResolutionPending ||
        _isSyncing ||
        _isApplyingRemote ||
        !FirebaseAuthService.instance.isSignedIn) {
      return;
    }

    _isApplyingRemote = true;
    try {
      await ProfileService().pullFromCloudReplaceLocal();
      await DailyLogService().pullFromCloudReplaceLocal();
      await RecipeService().pullFromCloudReplaceLocal();
      lastSyncedAt = DateTime.now();
      statusNotifier.value = SyncStatus.synced;
    } catch (_) {
      // Silent: local-first режим остаётся рабочим.
    } finally {
      _isApplyingRemote = false;
    }
  }

  void dispose() {
    _cancelRealtimeSubscriptions();
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    statusNotifier.dispose();
    _started = false;
  }
}
