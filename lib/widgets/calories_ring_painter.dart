import 'dart:math';
import 'package:flutter/material.dart';

class CaloriesRingPainter extends CustomPainter {
  final double remainingCalories;
  final double totalCalories;
  final double strokeWidth;
  final Color backgroundColor;
  final Color ringColor;

  CaloriesRingPainter({
    required this.remainingCalories,
    required this.totalCalories,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progress = (totalCalories - remainingCalories) / totalCalories;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Начинаем с верха
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
