import 'dart:async';
import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/cloud_data_service.dart';
import '../services/daily_log_service.dart';
import '../services/health_steps_service.dart';
import '../services/home_widget_service.dart';
import '../services/profile_service.dart';

class DailyLogProvider with ChangeNotifier {
  final DailyLogService _service = DailyLogService();
  final HealthStepsService _healthStepsService = HealthStepsService();
  final HomeWidgetSyncService _homeWidgetSyncService = HomeWidgetSyncService();
  final ProfileService _profileService = ProfileService();
  StreamSubscription<Map<String, dynamic>?>? _syncSubscription;
  StreamSubscription<void>? _cacheUpdatesSubscription;

  DateTime _selectedDate = DateTime.now();
  DailyLog? _currentLog;
  bool _isLoading = false;
  Set<DateTime> _loggedDates = {};

  DateTime get selectedDate => _selectedDate;
  DailyLog? get currentLog => _currentLog;
  bool get isLoading => _isLoading;
  Set<DateTime> get loggedDates => _loggedDates;

  DailyLogProvider() {
    _cacheUpdatesSubscription = DailyLogService.cacheUpdates.listen((_) async {
      final updatedLog = await _service.getLogForDate(_selectedDate);
      _currentLog = updatedLog;
      _loggedDates = await _service.getLoggedDates();
      notifyListeners();
      await _syncHomeWidgetForToday();
    });
    loadLoggedDates();
    loadLogForDate(_selectedDate);
    // Запускаем realtime sync после первого кадра, чтобы Firebase
    // успел инициализироваться до первого обращения к FirebaseAuth.
    Future.microtask(_startRealtimeSyncSafe);
  }

  void _startRealtimeSyncSafe() {
    try {
      _startRealtimeSync();
    } catch (_) {
      // Firebase ещё не готов — повторим через 2 секунды
      Future.delayed(const Duration(seconds: 2), _startRealtimeSyncSafe);
    }
  }

  /// Подписывается на Firestore-документ дневника.
  /// При получении изменений с другого устройства сохраняет их локально
  /// и обновляет текущий дневник без записи обратно в Firestore.
  void _startRealtimeSync() {
    _syncSubscription?.cancel();
    _syncSubscription = CloudDataService.instance
        .docStream('daily_logs')
        .listen((remoteData) async {
      if (remoteData == null) return;
      final logs = remoteData['logs'];
      if (logs is! Map<String, dynamic>) return;
      try {
        await _service.saveRawDataFromCloud(logs);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _cacheUpdatesSubscription?.cancel();
    super.dispose();
  }

  void setSelectedDate(DateTime date) {
    if (DateUtils.isSameDay(_selectedDate, date)) return;
    _selectedDate = date;
    loadLogForDate(date);
  }

  Future<void> loadLogForDate(DateTime date) async {
    _isLoading = true;
    notifyListeners();

    DailyLog log = await _service.getLogForDate(date);

    // Sync steps if connected
    try {
      final isConnected = await _healthStepsService.isConnected();
      if (isConnected) {
        final steps = await _healthStepsService.fetchStepsForDate(date);
        if (steps != null && steps > 0) {
          log = log.copyWith(steps: steps);
          await _service.setSteps(date, steps: steps);
        }
      }
    } catch (_) {}

    _currentLog = log;
    _isLoading = false;
    notifyListeners();

    await _syncHomeWidgetForToday();
  }

  Future<void> loadLoggedDates() async {
    _loggedDates = await _service.getLoggedDates();
    notifyListeners();
  }

  Future<void> refreshCurrentLog() async {
    final log = await _service.getLogForDate(_selectedDate);
    _currentLog = log;
    await loadLoggedDates();
    notifyListeners();

    await _syncHomeWidgetForToday();
  }

  Future<void> _syncHomeWidgetForToday({bool forceReload = false}) async {
    try {
      final todayLog = await _service.getLogForDate(DateTime.now());
      final profile = await _profileService.loadProfile();
      await _homeWidgetSyncService.syncDailyData(
        log: todayLog,
        profile: profile,
        forceReload: forceReload,
      );
    } catch (e, stack) {
      debugPrint('HOME_WIDGET: sync failed: $e');
      debugPrint(stack.toString());
    }
  }

  // --- Actions ---

  Future<void> updateWater(int amount) async {
    if (_currentLog == null) return;
    if (amount >= 0) {
      await _service.addWater(_selectedDate, amount: amount);
    } else {
      await _service.removeWater(_selectedDate, amount: amount.abs());
    }
    await refreshCurrentLog();
  }

  Future<void> updateSteps(int steps) async {
    await _service.setSteps(_selectedDate, steps: steps);
    await refreshCurrentLog();
  }

  Future<void> updateWeight(double weight) async {
    await _service.setWeight(_selectedDate, weight: weight);
    await refreshCurrentLog();
  }
}
