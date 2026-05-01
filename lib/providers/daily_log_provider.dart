import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/daily_log_service.dart';
import '../services/health_steps_service.dart';
import '../services/home_widget_service.dart';
import '../services/profile_service.dart';

class DailyLogProvider with ChangeNotifier {
  final DailyLogService _service = DailyLogService();
  final HealthStepsService _healthStepsService = HealthStepsService();
  final HomeWidgetSyncService _homeWidgetSyncService = HomeWidgetSyncService();
  final ProfileService _profileService = ProfileService();
  
  DateTime _selectedDate = DateTime.now();
  DailyLog? _currentLog;
  bool _isLoading = false;
  Set<DateTime> _loggedDates = {};

  DateTime get selectedDate => _selectedDate;
  DailyLog? get currentLog => _currentLog;
  bool get isLoading => _isLoading;
  Set<DateTime> get loggedDates => _loggedDates;

  DailyLogProvider() {
    loadLoggedDates();
    loadLogForDate(_selectedDate);
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
    
    // Sync widget safely
    try {
      final profile = await _profileService.loadProfile();
      await _homeWidgetSyncService.syncDailyData(log: log, profile: profile);
    } catch (_) {}
  }

  Future<void> loadLoggedDates() async {
    _loggedDates = await _service.getLoggedDates();
    notifyListeners();
  }

  Future<void> refreshCurrentLog() async {
    _currentLog = await _service.getLogForDate(_selectedDate);
    await loadLoggedDates();
    notifyListeners();
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
