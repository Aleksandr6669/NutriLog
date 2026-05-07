import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'firebase_auth_service.dart';
import 'cloud_data_service.dart';
import 'daily_log_service.dart';
import 'profile_service.dart';
import 'recipe_service.dart';

enum SyncStatus { idle, syncing, synced, error }

class LocalFirstSyncService {
  LocalFirstSyncService._();

  static final LocalFirstSyncService instance = LocalFirstSyncService._();

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier(SyncStatus.idle);
  DateTime? lastSyncedAt;

  StreamSubscription? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  bool _started = false;
  bool _isSyncing = false;
  bool _wasConnected = false;

  void start() {
    if (_started) return;
    if (CloudDataService.instance.isLocalOnlyMode) {
      statusNotifier.value = SyncStatus.idle;
      return;
    }
    _started = true;

    _authSubscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) {
        if (user == null) return;
        syncNow();
      },
    );

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection =
          results.any((r) => r != ConnectivityResult.none);
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

  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    statusNotifier.dispose();
    _started = false;
  }
}
