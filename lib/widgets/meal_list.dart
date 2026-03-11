import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MealList extends StatelessWidget {
  const MealList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Приемы пищи', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {},
              child: const Text('История', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Removed const
        _MealCard(icon: Symbols.wb_sunny, meal: 'Завтрак', recommended: '450 - 600', consumed: 320, iconColor: Colors.orange),
        _MealCard(icon: Symbols.lunch_dining, meal: 'Обед', recommended: '600 - 800', consumed: 520, iconColor: Colors.green),
        _MealCard(icon: Symbols.nightlight, meal: 'Ужин', recommended: '450 - 600', consumed: 0, iconColor: Colors.purple),
        _MealCard(icon: Symbols.cookie, meal: 'Перекус', recommended: '150 - 250', consumed: 0, iconColor: Colors.pink),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String meal;
  final String recommended;
  final int consumed;

  // Removed const
   const _MealCard({
    required this.icon,
    required this.iconColor,
    required this.meal,
    required this.recommended,
    required this.consumed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Рекомендовано: $recommended ккал', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            Text('$consumed ккал', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Container(
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
