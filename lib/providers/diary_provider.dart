import 'package:flutter/material.dart';
import '../models/fatsecret_food.dart';

class DiaryProvider with ChangeNotifier {
  final Map<String, List<FatsecretFood>> _meals = {
    'Завтрак': [],
    'Обед': [],
    'Ужин': [],
    'Перекус': [],
  };

  Map<String, List<FatsecretFood>> get meals => _meals;

  void addFood(String meal, FatsecretFood food) {
    _meals[meal]?.add(food);
    notifyListeners();
  }

  void removeFood(String meal, FatsecretFood food) {
    _meals[meal]?.remove(food);
    notifyListeners();
  }
}
