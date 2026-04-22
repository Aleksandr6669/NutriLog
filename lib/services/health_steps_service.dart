import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthStepsService {
  static const String _connectedKey = 'health_steps_connected';
  final Health _health = Health();

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_connectedKey) ?? false;
  }

  Future<bool> connect() async {
    try {
      final granted = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, granted == true);
      return granted == true;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, false);
      return false;
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, false);
  }

  Future<int?> fetchStepsForDate(
    DateTime date, {
    bool requestAuthorizationIfNeeded = false,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      if (requestAuthorizationIfNeeded) {
        final granted = await connect();
        if (!granted) return null;
      } else {
        final connected = await isConnected();
        if (!connected) return null;
      }

      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }
}
