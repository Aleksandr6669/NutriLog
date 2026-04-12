import 'package:flutter/material.dart';

import '../../../styles/app_styles.dart';

class ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final Color color;
  final num? goal;
  final bool isWeight;
  final bool isWater;

  const ProgressCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    this.goal,
    this.isWeight = false,
    this.isWater = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalText = _getGoalText();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                if (goalText != null)
                  Text(
                    goalText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 RichText(
                    text: TextSpan(
                      style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: value),
                        TextSpan(
                          text: ' ${unit.split(' ').first}', // Только первая часть юнита
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color)
                        ),
                      ]
                    )
                  ),
                Text(title, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  String? _getGoalText() {
    if (goal == null || goal == 0) return null;
    if (isWeight) return 'Цель: ${goal!.toStringAsFixed(0)} кг';
    if (isWater) return 'Цель: ${goal!.toStringAsFixed(1)} л';
    return 'Цель: ${goal!.toInt()}';
  }
}
