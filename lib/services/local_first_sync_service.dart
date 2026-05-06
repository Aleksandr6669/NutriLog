import 'dart:async';

import 'firebase_auth_service.dart';
import 'daily_log_service.dart';
import 'profile_service.dart';
import 'recipe_service.dart';

class LocalFirstSyncService {
  LocalFirstSyncService._();

  static final LocalFirstSyncService instance = LocalFirstSyncService._();

  StreamSubscription? _authSubscription;
  Timer? _periodicSyncTimer;
  bool _started = false;
  bool _isSyncing = false;

  void start() {
    if (_started) return;
    _started = true;

    _authSubscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) {
        if (user == null) return;
        syncNow();
      },
    );

    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => syncNow(),
    );

    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing || !FirebaseAuthService.instance.isSignedIn) return;

    _isSyncing = true;
    try {
      await ProfileService().syncWithCloud();
      await DailyLogService().syncWithCloud();
      await RecipeService().syncWithCloud();
    } catch (_) {
      // Все данные уже записаны локально. Следующий retry догонит облако.
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _started = false;
  }
}
