import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/daily_summary.dart';
import '../../widgets/macronutrient_progress.dart';
import '../../widgets/meal_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Symbols.calendar_today, color: Colors.green),
            const SizedBox(width: 8),
            Text('Сегодня', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Symbols.notifications), onPressed: () {}),
          IconButton(icon: const Icon(Symbols.search), onPressed: () {}),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      // Removed const
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DailySummary(),
              SizedBox(height: 24),
              MacronutrientProgress(),
              SizedBox(height: 24),
              MealList(),
            ],
          ),
        ),
      ),
    );
  }
}
