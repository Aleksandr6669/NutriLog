import 'dart:math';


import '../../models/daily_log.dart';
import '../../models/user_profile.dart';

class AiService {
  // final FirebaseVertexAI _vertexAI;

  // AiService({FirebaseVertexAI? vertexAI}) 
  //     : _vertexAI = vertexAI ?? FirebaseVertexAI.instance;

  Future<String> getWeeklyAnalysis(List<DailyLog> logs, UserProfile profile) async {
    // --- ВРЕМЕННАЯ ЗАГЛУШКА ДЛЯ AI-ОТЧЕТА ---
    // Возвращаем статический текст вместо вызова API
    await Future.delayed(const Duration(seconds: 1)); // Имитация задержки сети

    if (logs.isEmpty) {
      return 'Нет данных за неделю для анализа.';
    }

    final avgCalories = logs.map((l) => l.totalNutrients.calories).fold(0.0, (a, b) => a + b) / logs.length;
    final calorieIntakeRatio = avgCalories / profile.calorieGoal;

    final recommendations = [
      'Вы отлично справляетесь! Продолжайте в том же духе.',
      'Неплохая неделя! Попробуйте добавить еще одну тренировку для лучших результатов.',
      'Отличная работа с калориями! Постарайтесь пить немного больше воды в течение дня.',
      'Вы на верном пути! Добавление белка в ваш рацион поможет ускорить достижение цели.',
    ];

    if (calorieIntakeRatio > 1.1) {
      return 'На этой неделе вы немного превышали норму калорий. Попробуйте более осознанно подходить к выбору продуктов.';
    }

    // Возвращаем случайную рекомендацию
    final random = Random();
    return recommendations[random.nextInt(recommendations.length)];
  }

  // Метод _buildWeeklyPrompt больше не нужен для заглушки, но оставлен для будущего использования
  /*
  String _buildWeeklyPrompt(List<DailyLog> logs, UserProfile profile) {
    final avgCalories = logs.map((l) => l.totalNutrients.calories).reduce((a, b) => a + b) / logs.length;
    final avgProtein = logs.map((l) => l.totalNutrients.protein).reduce((a, b) => a + b) / logs.length;
    final avgCarbs = logs.map((l) => l.totalNutrients.carbs).reduce((a, b) => a + b) / logs.length;
    final avgFat = logs.map((l) => l.totalNutrients.fat).reduce((a, b) => a + b) / logs.length;

    final logSummary = logs.map((log) {
      return 'День ${log.date.weekday}: ${log.totalNutrients.calories.round()} ккал, Белки: ${log.totalNutrients.protein.round()}г, Углеводы: ${log.totalNutrients.carbs.round()}г, Жиры: ${log.totalNutrients.fat.round()}г, Активность: ${log.activityCalories} ккал, Вес: ${log.weight ?? 'не указан'}';
    }).join('\n');

    return '''
    Выступи в роли умного фитнес-помощника и диетолога.
    Проанализируй мои данные по питанию и активности за последнюю неделю.
    Дай мне краткий, но емкий отчет (не более 3-4 предложений) с основными выводами и одной ключевой, наиболее важной рекомендацией для улучшения.
    Будь позитивным и мотивирующим.

    Мои цели:
    - Калории: ${profile.calorieGoal} ккал
    - Белки: ${profile.proteinGoal} г
    - Углеводы: ${profile.carbsGoal} г
    - Жиры: ${profile.fatGoal} г
    - Цель по весу: ${profile.weightGoal} кг

    Мои средние показатели за неделю:
    - Калории: ${avgCalories.round()} ккал
    - Белки: ${avgProtein.round()} г
    - Углеводы: ${avgCarbs.round()} г
    - Жиры: ${avgFat.round()} г

    Данные по дням:
    $logSummary

    Твой отчет:
    ''';
  }
  */
}
