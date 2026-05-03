import 'dart:math';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/daily_log.dart';
import '../../models/user_profile.dart';

class AiService {
  // final FirebaseVertexAI _vertexAI;

  // AiService({FirebaseVertexAI? vertexAI})
  //     : _vertexAI = vertexAI ?? FirebaseVertexAI.instance;

  Future<String> _getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    if (saved == 'ru' || saved == 'uk' || saved == 'en') {
      return saved!;
    }

    final system = ui.PlatformDispatcher.instance.locale.languageCode;
    if (system == 'ru' || system == 'uk' || system == 'en') {
      return system;
    }
    return 'en';
  }

  List<String> _recommendations(String lang) {
    switch (lang) {
      case 'ru':
        return const [
          'Вы отлично справляетесь! Продолжайте в том же духе.',
          'Неплохая неделя! Попробуйте добавить еще одну тренировку для лучших результатов.',
          'Отличная работа с калориями! Постарайтесь пить немного больше воды в течение дня.',
          'Вы на верном пути! Добавление белка в ваш рацион поможет ускорить достижение цели.',
        ];
      case 'uk':
        return const [
          'Ви чудово справляєтесь! Продовжуйте в тому ж дусі.',
          'Гарний тиждень! Спробуйте додати ще одне тренування для кращих результатів.',
          'Чудова робота з калоріями! Спробуйте пити трохи більше води протягом дня.',
          'Ви на правильному шляху! Додавання білка в раціон допоможе швидше досягти цілі.',
        ];
      default:
        return const [
          'You are doing great! Keep up the good work.',
          'Good week! Try adding one more workout for even better results.',
          'Great work with calories! Try to drink a bit more water during the day.',
          'You are on the right track! Adding more protein can help you reach your goal faster.',
        ];
    }
  }

  String _noDataText(String lang) {
    switch (lang) {
      case 'ru':
        return 'Нет данных за неделю для анализа.';
      case 'uk':
        return 'Немає даних за тиждень для аналізу.';
      default:
        return 'No weekly data available for analysis.';
    }
  }

  String _highCaloriesText(String lang) {
    switch (lang) {
      case 'ru':
        return 'На этой неделе вы немного превышали норму калорий. Попробуйте более осознанно подходить к выбору продуктов.';
      case 'uk':
        return 'Цього тижня ви трохи перевищували норму калорій. Спробуйте більш усвідомлено підходити до вибору продуктів.';
      default:
        return 'This week you were slightly above your calorie target. Try to make food choices a bit more mindfully.';
    }
  }

  Future<String> getWeeklyAnalysis(
    List<DailyLog> logs,
    UserProfile profile,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    final lang = await _getLanguageCode();

    if (logs.isEmpty) {
      return _noDataText(lang);
    }

    final avgCalories =
        logs.map((l) => l.totalNutrients.calories).fold(0.0, (a, b) => a + b) /
            logs.length;
    final calorieIntakeRatio = avgCalories / profile.calorieGoal;

    if (calorieIntakeRatio > 1.1) {
      return _highCaloriesText(lang);
    }

    final recommendations = _recommendations(lang);
    final random = Random();
    return recommendations[random.nextInt(recommendations.length)];
  }
}
