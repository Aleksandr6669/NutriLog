import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class IconMapper {
  static final Map<String, IconData> _iconMap = {
    'restaurant': Symbols.restaurant,
    'lunch_dining': Symbols.lunch_dining,
    'local_bar': Symbols.local_bar,
    'cake': Symbols.cake,
    'fastfood': Symbols.fastfood,
    'breakfast_dining': Symbols.breakfast_dining,
    'ramen_dining': Symbols.ramen_dining,
    'icecream': Symbols.icecream,
    'local_pizza': Symbols.local_pizza,
    'wb_sunny': Symbols.wb_sunny,
    'nights_stay': Symbols.nights_stay,
    'cookie': Symbols.cookie,
  };

  static IconData getIcon(String name) {
    return _iconMap[name] ?? Symbols.restaurant; // Возвращаем иконку по умолчанию
  }

  static String getName(IconData icon) {
    return _iconMap.entries.firstWhere((entry) => entry.value == icon, orElse: () => _iconMap.entries.first).key;
  }
}
