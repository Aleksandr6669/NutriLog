import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_styles.dart';

class ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String primaryLine;
  final String secondaryLine;
  final Color color;
  final num? goal;
  final num? metricValue;
  final List<double>? trendData;
  final bool isWeight;
  final bool isWater;
  final bool useStrictGoalComparison;

  const ProgressCard({
    super.key,
    required this.icon,
    required this.title,
    required this.primaryLine,
    required this.secondaryLine,
    required this.color,
    this.goal,
    this.metricValue,
    this.trendData,
    this.isWeight = false,
    this.isWater = false,
    this.useStrictGoalComparison = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalText = _getGoalText(context);
    final trendGraphic = _buildTrendGraphic(theme);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
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
                if (goalText != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      goalText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: trendGraphic != null ? 1 : 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                if (trendGraphic != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: trendGraphic,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _getGoalText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (goal == null || goal == 0) return null;
    if (useStrictGoalComparison) return l10n.goalAbove(goal!.toInt());
    if (isWeight) return l10n.goalWeightKg(goal!.toStringAsFixed(0));
    if (isWater) return l10n.goalWaterL(goal!.toStringAsFixed(1));
    return l10n.goalValue(goal!.toInt());
  }

  Widget? _buildTrendGraphic(ThemeData theme) {
    final series = (trendData ?? const <double>[])
        .where((v) => v.isFinite)
        .toList(growable: false);

    if (goal == null || goal == 0) return null;

    final referenceValue =
        metricValue ?? (series.isNotEmpty ? series.last : null);
    if (referenceValue == null) return null;

    final meetsGoal = useStrictGoalComparison
        ? referenceValue > goal!
        : referenceValue >= goal!;
    var diffRatio = ((referenceValue - goal!) / goal!).clamp(-1.0, 1.0);
    if (!meetsGoal && diffRatio >= 0) {
      diffRatio = -0.12;
    }
    final graphicColor = meetsGoal ? Colors.green : Colors.red;

    return SizedBox(
      height: 42,
      child: CustomPaint(
        painter: _TrendLinePainter(
          color: graphicColor,
          diffRatio: diffRatio,
          trendData: series,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final Color color;
  final double diffRatio;
  final List<double> trendData;

  const _TrendLinePainter({
    required this.color,
    required this.diffRatio,
    required this.trendData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    if (trendData.length >= 2) {
      final minValue = trendData.reduce((a, b) => a < b ? a : b);
      final maxValue = trendData.reduce((a, b) => a > b ? a : b);
      final range =
          (maxValue - minValue).abs() < 1e-9 ? 1.0 : (maxValue - minValue);

      for (var i = 0; i < trendData.length; i++) {
        final x = 2 + ((size.width - 4) * i / (trendData.length - 1));
        final normalized = (trendData[i] - minValue) / range;
        final y = (size.height - 3) - (normalized * (size.height - 6));

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      final midY = size.height / 2;
      final maxOffset = (size.height / 2) - 3.0;
      final endY =
          (midY - (maxOffset * diffRatio)).clamp(3.0, size.height - 3.0);
      final controlY = (midY - ((maxOffset * diffRatio) * 0.45))
          .clamp(3.0, size.height - 3.0);

      path
        ..moveTo(2, midY)
        ..lineTo(size.width * 0.45, midY)
        ..quadraticBezierTo(size.width * 0.75, controlY, size.width - 2, endY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.diffRatio != diffRatio ||
        oldDelegate.trendData != trendData;
  }
}
