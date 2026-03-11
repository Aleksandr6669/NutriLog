import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import './calories_ring_painter.dart';

class DailySummary extends StatelessWidget {
  const DailySummary({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: CaloriesRingPainter(
                remainingCalories: 1420,
                totalCalories: 2100,
                strokeWidth: 20,
                backgroundColor: Colors.grey[200]!,
                ringColor: Colors.green,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('1420', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                    Text('ОСТАЛОСЬ ККАЛ', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _InfoColumn(icon: Symbols.restaurant_menu, value: '840', label: 'ЕДА'),
              _InfoColumn(icon: Symbols.exercise, value: '160', label: 'УПР-ИЯ'),
              _InfoColumn(icon: Symbols.tour, value: '2100', label: 'ЦЕЛЬ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _InfoColumn({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
