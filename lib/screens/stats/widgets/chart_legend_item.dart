import 'package:flutter/material.dart';

class ChartLegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final int percentage;

  const ChartLegendItem({
    super.key,
    required this.color,
    required this.text,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        Text('$percentage%',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
