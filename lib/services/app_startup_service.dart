import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_data_service.dart';
import 'profile_service.dart';
import 'daily_log_service.dart';
import 'recipe_service.dart';

class StartupState {
  final bool needsOnboarding;
  final bool hasAcceptedAgreement;
  final String? whatsNewText;
  final String currentVersion;

  const StartupState({
    required this.needsOnboarding,
    required this.hasAcceptedAgreement,
    required this.whatsNewText,
    required this.currentVersion,
  });
}

class AppStartupService {
  static const String _onboardingDoneKey = 'onboarding_completed';
  static const String _lastSeenWhatsNewVersionKey = 'whats_new_seen_version';
  static const String _agreementAcceptedKey = 'user_agreement_accepted';

  static const String _changelogAssetPath = 'assets/data/changelog.json';

  // Кэш загруженного changelog.
  static List<Map<String, dynamic>>? _changelogCache;

  static Future<List<Map<String, dynamic>>> _loadChangelog() async {
    if (_changelogCache != null) return _changelogCache!;
    final raw = await rootBundle.loadString(_changelogAssetPath);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _changelogCache = list;
    return list;
  }

  static Future<String?> getWhatsNewForVersion(
      String version, String lang) async {
    final list = await _loadChangelog();
    final entry = list.firstWhere(
      (e) => e['version'] == version,
      orElse: () => {},
    );
    if (entry.isEmpty) return null;
    return (entry[lang] ?? entry['en']) as String?;
  }

  /// Возвращает список всех версий с текстом изменений для заданного языка.
  static Future<List<MapEntry<String, String>>> getAllVersionChangelog(
      String lang) async {
    final list = await _loadChangelog();
    return list
        .map((e) => MapEntry(
            e['version'] as String, (e[lang] ?? e['en'] ?? '') as String))
        .toList();
  }

  Future<StartupState> loadState() async {
    final prefs = await SharedPreferences.getInstance();

    // Используем таймаут для получения версии, чтобы не блокировать запуск
    final currentVersion = await _resolveCurrentVersion().timeout(
      const Duration(seconds: 2),
      onTimeout: () => '0.0.0+0',
    );

    var profileStr = prefs.getString('user_profile') ?? '';
    var onboardingCompleted = prefs.getBool(_onboardingDoneKey) ?? false;
    var hasAcceptedAgreement = prefs.getBool(_agreementAcceptedKey) ?? false;
    var isEmptyName = profileStr.isEmpty || profileStr.contains('"name":""');

    // Если данные профиля уже есть в SharedPreferences (например, восстановлены операционной системой/бэкапом),
    // но флаги завершения онбординга или соглашения сброшены — мы автоматически считаем их пройденными и используем
    if (!isEmptyName) {
      if (!onboardingCompleted) {
        onboardingCompleted = true;
        await prefs.setBool(_onboardingDoneKey, true);
        debugPrint(
            'STARTUP: Valid profile found in SharedPreferences. Auto-completing onboarding.');
      }
      if (!hasAcceptedAgreement) {
        hasAcceptedAgreement = true;
        await prefs.setBool(_agreementAcceptedKey, true);
        debugPrint(
            'STARTUP: Valid profile found in SharedPreferences. Auto-accepting agreement.');
      }
    }

    // Если локальных данных нет, но сессия Firebase Auth сохранилась в Keychain/Smart Lock (приложение переустановили)
    if ((!onboardingCompleted || profileStr.isEmpty || isEmptyName) &&
        CloudDataService.instance.isSignedIn) {
      try {
        debugPrint(
            'STARTUP: User is signed in but local profile is missing. Attempting cloud recovery...');
        // Пробуем быстро восстановить профиль из Firestore
        await ProfileService().pullFromCloudReplaceLocal().timeout(
              const Duration(seconds: 3),
            );

        // Перечитываем сохранённые значения профиля
        profileStr = prefs.getString('user_profile') ?? '';
        isEmptyName = profileStr.isEmpty || profileStr.contains('"name":""');

        if (!isEmptyName) {
          debugPrint(
              'STARTUP: Cloud profile successfully recovered. Skipping onboarding.');
          onboardingCompleted = true;
          hasAcceptedAgreement = true;
          await prefs.setBool(_onboardingDoneKey, true);
          await prefs.setBool(_agreementAcceptedKey, true);

          // Загружаем лог и рецепты асинхронно, чтобы не задерживать запуск
          unawaited(DailyLogService().pullFromCloudReplaceLocal().timeout(
                const Duration(seconds: 5),
                onTimeout: () => {},
              ));
          unawaited(RecipeService().pullFromCloudReplaceLocal().timeout(
                const Duration(seconds: 5),
                onTimeout: () => {},
              ));
        } else {
          debugPrint('STARTUP: Cloud recovery succeeded but profile is empty.');
        }
      } catch (e) {
        debugPrint('STARTUP: Cloud recovery failed: $e');
      }
    }

    final needsOnboarding =
        !onboardingCompleted || profileStr.isEmpty || isEmptyName;

    final lastSeenVersion = prefs.getString(_lastSeenWhatsNewVersionKey);
    final currentLang = prefs.getString('app_locale') ?? 'ru';
    final whatsNewText =
        await getWhatsNewForVersion(currentVersion, currentLang);
    final shouldShowWhatsNew = whatsNewText != null &&
        whatsNewText.trim().isNotEmpty &&
        lastSeenVersion != currentVersion;

    return StartupState(
      needsOnboarding: needsOnboarding,
      hasAcceptedAgreement: hasAcceptedAgreement,
      whatsNewText: shouldShowWhatsNew ? whatsNewText : null,
      currentVersion: currentVersion,
    );
  }

  Future<String> _resolveCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = '${packageInfo.version}+${packageInfo.buildNumber}';

      return version;
    } catch (e) {
      return '0.0.0+0';
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }

  Future<void> acceptAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_agreementAcceptedKey, true);
  }

  Future<void> markWhatsNewSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenWhatsNewVersionKey, version);
  }
}
