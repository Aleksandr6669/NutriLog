import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart';
import 'dart:math' as math;
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Symbols.calendar_today, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            const Text('Сегодня'),
          ],
        ),
        actions: [
          _buildAppBarAction(theme, Symbols.search),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Padding for nav bar
        child: Column(
          children: [
            _buildCaloriesCard(theme),
            const SizedBox(height: 16),
            _buildMacronutrients(theme),
            const SizedBox(height: 24),
            _buildMealsSection(theme),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(theme),
      extendBody: true,
    );
  }

  Widget _buildAppBarAction(ThemeData theme, IconData icon) {
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }

  Widget _buildCaloriesCard(ThemeData theme) {
    return Card(
       shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.largeBorderRadius,
          border: Border.all(color: AppColors.primary.withOpacity(0.1))
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _CircularProgress(progress: 0.67, strokeWidth: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('1 420', style: theme.textTheme.displayLarge?.copyWith(fontSize: 52, color: theme.colorScheme.onSurface)),
                        Text('осталось ккал', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, color: theme.textTheme.bodySmall?.color)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(theme, Symbols.restaurant, '840', 'Еда', color: AppColors.primary),
                    SizedBox(height: 40, child: VerticalDivider(color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.fitness_center, '160', 'Упр-ия', color: Colors.orange.shade400),
                    SizedBox(height: 40, child: VerticalDivider(color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.flag, '2 100', 'Цель', color: Colors.blue.shade400),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, IconData icon, String value, String label, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildMacronutrients(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _MacronutrientCard(name: 'Углеводы', value: '120г', total: '250г', percentage: 0.48, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _MacronutrientCard(name: 'Белки', value: '60г', total: '150г', percentage: 0.4, color: Colors.orange.shade400)),
        const SizedBox(width: 12),
        Expanded(child: _MacronutrientCard(name: 'Жиры', value: '45г', total: '70г', percentage: 0.64, color: Colors.blue.shade400)),
      ],
    );
  }

  Widget _buildMealsSection(ThemeData theme) {
    return Column(
      children: [
         Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Приемы пищи', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
              TextButton(
                onPressed: () {},
                child: Text('История', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _MealCard(name: 'Завтрак', recommended: '450 - 600', calories: '320', icon: Symbols.wb_sunny, iconBg: Color(0xFFFFF4E6), iconColor: Colors.orange, consumed: true),
          const SizedBox(height: 12),
          const _MealCard(name: 'Обед', recommended: '600 - 800', calories: '520', icon: Symbols.lunch_dining, iconBg: Color(0xFFE6F9F0), iconColor: AppColors.primary, consumed: true),
          const SizedBox(height: 12),
          const _MealCard(name: 'Ужин', recommended: '450 - 600', calories: '0', icon: Symbols.nights_stay, iconBg: Color(0xFFEEF2FF), iconColor: Colors.indigo),
          const SizedBox(height: 12),
          const _MealCard(name: 'Перекус', recommended: '150 - 250', calories: '0', icon: Symbols.cookie, iconBg: Color(0xFFFCE7F3), iconColor: Colors.pink),
      ],
    );
  }

  Widget _buildBottomNavigationBar(ThemeData theme) {
    return Container(
      height: 90,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor?.withOpacity(0.9),
        borderRadius: AppStyles.defaultBorderRadius,
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: AppStyles.defaultBorderRadius,
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {},
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(icon: Icon(Symbols.menu_book, weight: 300), activeIcon: Icon(Symbols.menu_book, fill: 1, weight: 600), label: 'Дневник'),
            BottomNavigationBarItem(icon: Icon(Symbols.receipt_long, weight: 300), activeIcon: Icon(Symbols.receipt_long, fill: 1, weight: 600), label: 'Рецепты'),
            BottomNavigationBarItem(icon: Icon(Symbols.analytics, weight: 300), activeIcon: Icon(Symbols.analytics, fill: 1, weight: 600), label: 'Анализ'),
            BottomNavigationBarItem(icon: Icon(Symbols.person, weight: 300), activeIcon: Icon(Symbols.person, fill: 1, weight: 600), label: 'Профиль'),
          ],
        ),
      ),
    );
  }

}

// --- Local Widgets for HomeScreen ---

class _CircularProgress extends StatelessWidget {
  final double progress;
  final double strokeWidth;

  const _CircularProgress({required this.progress, this.strokeWidth = 12});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CircularProgressPainter(
        progress: progress,
        strokeWidth: strokeWidth,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        progressColor: AppColors.primary,
      ),
      // By adding an empty Container as a child, we force the CustomPaint
      // to expand to the size of its parent (the 240x240 SizedBox).
      child: Container(),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress; 
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({required this.progress, required this.strokeWidth, required this.backgroundColor, required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return; // Do not paint if radius is not positive

    final backgroundPaint = Paint()..color = backgroundColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()..color = progressColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MacronutrientCard extends StatelessWidget {
  final String name, value, total;
  final double percentage;
  final Color color;
  
  const _MacronutrientCard({required this.name, required this.value, required this.total, required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.mediumBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                Text('${(percentage * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppStyles.smallBorderRadius,
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' / $total', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String name, recommended, calories;
  final IconData icon;
  final Color iconBg, iconColor;
  final bool consumed;

  const _MealCard({required this.name, required this.recommended, required this.calories, required this.icon, required this.iconBg, required this.iconColor, this.consumed = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotEaten = calories == '0';
    return Opacity(
      opacity: isNotEaten ? 0.7 : 1.0,
      child: Card(
         shape: RoundedRectangleBorder(
          borderRadius: AppStyles.cardRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isNotEaten ? (theme.brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800) : iconBg,
                  borderRadius: AppStyles.mediumBorderRadius
                ),
                child: Icon(icon, color: isNotEaten ? (theme.brightness == Brightness.light ? Colors.grey.shade400 : Colors.grey.shade600) : iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('Реком: $recommended ккал', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (!isNotEaten)
                Text('$calories ккал', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
              const SizedBox(width: 12),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))]
                ),
                child: const Icon(Symbols.add, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
