import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupState {
  final bool needsOnboarding;
  final String? whatsNewText;
  final String currentVersion;

  const StartupState({
    required this.needsOnboarding,
    required this.whatsNewText,
    required this.currentVersion,
  });
}

class AppStartupService {
  static const String _onboardingDoneKey = 'onboarding_completed';
  static const String _lastSeenWhatsNewVersionKey = 'whats_new_seen_version';

  // Текст новинок по версии. Если версии нет в карте - экран новинок не показываем.
  static const Map<String, String> _whatsNewByVersion = {
    '1.2.5+17': '• Улучшена производительность приложения.\n'
        '• Исправлены мелкие баги и улучшена стабильность.\n'
        '• Добавлены уведомления по воде и приемам пищи.\n'
        '• Добавлены уведомления напоминания взвеситься.\n'
        '• Улучшена интеграция с нейросетью.\n'
        '• Добавлены виджеты для андроида.\n'
        '• Добавлена поддержка новых устройств и экранов.',
    '1.2.2+14': '• Добавлен многошаговый онбординг на первом запуске.\n'
        '• Появился экран "Подключения и сообщения" в настройках профиля.\n'
        '• Напоминания о воде теперь рассчитываются автоматически по дневной цели.\n'
        '• Дневные цели в онбординге можно рассчитать через нейросеть.',
    '1.2.0+13': '• Добавлен шагомер с синхронизацией из приложения здоровья.\n'
        '• Появился ручной ввод шагов, если источник здоровья недоступен.\n'
        '• Улучшены карточки прогресса и аналитика.\n'
        '• Добавлены настраиваемые push-напоминания по воде и приемам пищи.',
  };

  Future<StartupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = await _resolveCurrentVersion();

    final needsOnboarding = !(prefs.getBool(_onboardingDoneKey) ?? false);

    final lastSeenVersion = prefs.getString(_lastSeenWhatsNewVersionKey);
    final whatsNewText = _whatsNewByVersion[currentVersion];
    final shouldShowWhatsNew = whatsNewText != null &&
        whatsNewText.trim().isNotEmpty &&
        lastSeenVersion != currentVersion;

    return StartupState(
      needsOnboarding: needsOnboarding,
      whatsNewText: shouldShowWhatsNew ? whatsNewText : null,
      currentVersion: currentVersion,
    );
  }

  Future<String> _resolveCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      // Для web/preview-платформ не блокируем запуск, если plugin недоступен.
      return '0.0.0+0';
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }

  Future<void> markWhatsNewSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenWhatsNewVersionKey, version);
  }
}
