import 'package:flutter/material.dart';

import '../../../styles/app_styles.dart';

class ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String primaryLine;
  final String secondaryLine;
  final Color color;
  final num? goal;
  final bool isWeight;
  final bool isWater;

  const ProgressCard({
    super.key,
    required this.icon,
    required this.title,
    required this.primaryLine,
    required this.secondaryLine,
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (goalText != null)
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          goalText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              primaryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              secondaryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
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
