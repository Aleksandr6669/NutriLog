import 'package:flutter/material.dart';

class MacronutrientProgress extends StatelessWidget {
  const MacronutrientProgress({super.key});

  @override
  Widget build(BuildContext context) {
    // Using Expanded to make the layout flexible and prevent overflow.
    return Row(
      children: const [
        Expanded(
          child: _MacroWidget(name: 'Углеводы', percent: 50, consumed: 120, total: 250, color: Colors.green),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MacroWidget(name: 'Белки', percent: 40, consumed: 60, total: 150, color: Colors.orange),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MacroWidget(name: 'Жиры', percent: 65, consumed: 45, total: 70, color: Colors.blue),
        ),
      ],
    );
  }
}

class _MacroWidget extends StatelessWidget {
  final String name;
  final int percent;
  final int consumed;
  final int total;
  final Color color;

  const _MacroWidget({
    required this.name,
    required this.percent,
    required this.consumed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Removed fixed width to allow Expanded to manage the size.
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$percent%',
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: consumed / total,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '$consumedг / $totalг',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
