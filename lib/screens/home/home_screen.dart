import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;

import '../../models/daily_log.dart';
import '../../models/user_profile.dart';
import '../../services/daily_log_service.dart';
import '../../services/profile_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../meal_detail/meal_detail_screen.dart';
import '../../models/food_item.dart';
import '../profile/edit_goals_screen.dart'; // Изменено

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DailyLogService _logService = DailyLogService();
  final ProfileService _profileService = ProfileService();

  late Future<UserProfile> _userProfileFuture;
  DailyLog? _currentDailyLog;
  bool _isLoadingLog = true;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _isCalendarVisible = false;
  Set<DateTime> _loggedDates = {};

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _profileService.loadProfile();
    _loadLogForSelectedDate();
    _loadLoggedDates();
  }

  Future<void> _loadLoggedDates() async {
    final dates = await _logService.getLoggedDates();
    if (mounted) {
      setState(() {
        _loggedDates = dates;
      });
    }
  }

  Future<void> _loadLogForSelectedDate() async {
    setState(() {
      _isLoadingLog = true;
    });
    try {
      final log = await _logService.getLogForDate(_selectedDay);
      if (mounted) {
        setState(() {
          _currentDailyLog = log;
          _isLoadingLog = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentDailyLog = DailyLog.empty(_selectedDay);
          _isLoadingLog = false;
        });
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _loadLogForSelectedDate();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isCalendarVisible = false;
          });
        }
      });
    }
  }

  void _toggleCalendarVisibility() {
    setState(() {
      _isCalendarVisible = !_isCalendarVisible;
    });
  }

  void _reloadProfile() {
    if (mounted) {
      setState(() {
        _userProfileFuture = _profileService.loadProfile();
      });
    }
  }

  Future<void> _navigateToEditGoals(UserProfile profile) async { // Изменено
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditGoalsScreen(profile: profile), // Изменено
      ),
    );

    if (result == true) {
      _reloadProfile();
      _loadLogForSelectedDate(); // Also reload log data in case goals changed
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) return 'Сегодня';
    if (selected == yesterday) return 'Вчера';
    return DateFormat.yMMMMd('ru').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<UserProfile>(
      future: _userProfileFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
            appBar: AppBar(), 
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ошибка')),
            body: Center(child: Text('Ошибка загрузки профиля: ${userSnapshot.error}')),
          );
        }

        final userProfile = userSnapshot.data!;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: InkWell(
              onTap: _toggleCalendarVisibility,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.calendar_month, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(_formatDate(_selectedDay), style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                    const SizedBox(width: 8),
                    Icon(
                      _isCalendarVisible ? Symbols.arrow_drop_up : Symbols.arrow_drop_down,
                      color: theme.textTheme.bodySmall?.color,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Symbols.edit_note, size: 28),
                onPressed: () => _navigateToEditGoals(userProfile), // Изменено
                tooltip: 'Редактировать цели', // Изменено
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              _isLoadingLog
                  ? const Center(child: CircularProgressIndicator())
                  : _currentDailyLog == null
                      ? const Center(child: Text('Нет данных для этой даты.'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                          child: Column(
                            children: [
                              _CaloriesCard(dailyLog: _currentDailyLog!, profile: userProfile),
                              const SizedBox(height: 16),
                              _Macronutrients(dailyLog: _currentDailyLog!, profile: userProfile),
                              const SizedBox(height: 24),
                              _MealsSection(dailyLog: _currentDailyLog!, profile: userProfile, onDataChanged: _loadLogForSelectedDate),
                            ],
                          ),
                        ),
              _buildCalendarOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarOverlay() {
    return IgnorePointer(
      ignoring: !_isCalendarVisible,
      child: AnimatedOpacity(
        opacity: _isCalendarVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleCalendarVisibility,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                  child: Container(
                    color: Colors.black.withAlpha(38),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              top: _isCalendarVisible ? 0 : -400,
              left: 16,
              right: 16,
              child: _buildCalendarWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Card(
      elevation: 10,
      shadowColor: Colors.black.withAlpha(76),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.largeBorderRadius),
      child: TableCalendar(
        locale: 'ru_RU',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        eventLoader: (day) {
          final normalizedDay = DateTime.utc(day.year, day.month, day.day);
          return _loggedDates.any((d) => isSameDay(d, normalizedDay)) ? ['logged'] : [];
        },
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(Symbols.chevron_left, color: AppColors.primary),
          rightChevronIcon: Icon(Symbols.chevron_right, color: AppColors.primary),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Color.fromARGB(76, 51, 102, 255),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            return const SizedBox.shrink();
          },
          defaultBuilder: (context, day, focusedDay) {
            final normalizedDay = DateTime.utc(day.year, day.month, day.day);
            if (_loggedDates.any((d) => isSameDay(d, normalizedDay))) {
              return Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(76),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle().copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }
            return null;
          },
          selectedBuilder: (context, day, focusedDay) {
            return Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(76),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle().copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGETS ---

class _CaloriesCard extends StatelessWidget {
  final DailyLog dailyLog;
  final UserProfile profile;
  const _CaloriesCard({required this.dailyLog, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumedCals = dailyLog.totalNutrients.calories;
    final remainingCals = profile.calorieGoal - consumedCals + dailyLog.activityCalories;
    final progress = (profile.calorieGoal > 0) ? (consumedCals / profile.calorieGoal) : 0.0;

    return Card(
       shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppStyles.largeBorderRadius,
          border: Border.all(color: AppColors.primary.withAlpha(26))
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
                    _CircularProgress(progress: progress, strokeWidth: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(remainingCals.toStringAsFixed(0), style: theme.textTheme.displayLarge?.copyWith(fontSize: 52, color: theme.colorScheme.onSurface)),
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
                    _buildStatItem(theme, Symbols.restaurant, consumedCals.toStringAsFixed(0), 'ККал', color: AppColors.primary),
                    SizedBox(height: 40, child: VerticalDivider(color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.fitness_center, dailyLog.activityCalories.toString(), 'Актив', color: Colors.orange.shade400),
                    SizedBox(height: 40, child: VerticalDivider(color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.flag, profile.calorieGoal.toString(), 'Цель', color: Colors.blue.shade400),
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
}

class _Macronutrients extends StatelessWidget {
  final DailyLog dailyLog;
  final UserProfile profile;
  const _Macronutrients({required this.dailyLog, required this.profile});

  @override
  Widget build(BuildContext context) {
    final nutrients = dailyLog.totalNutrients;
    return Row(
      children: [
        Expanded(child: _MacronutrientCard(name: 'Углеводы', value: '${nutrients.carbs.toStringAsFixed(0)}г', total: '${profile.carbsGoal}г', percentage: profile.carbsGoal > 0 ? nutrients.carbs / profile.carbsGoal : 0, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _MacronutrientCard(name: 'Белки', value: '${nutrients.protein.toStringAsFixed(0)}г', total: '${profile.proteinGoal}г', percentage: profile.proteinGoal > 0 ? nutrients.protein / profile.proteinGoal : 0, color: Colors.orange)),
        const SizedBox(width: 12),
        Expanded(child: _MacronutrientCard(name: 'Жиры', value: '${nutrients.fat.toStringAsFixed(0)}г', total: '${profile.fatGoal}г', percentage: profile.fatGoal > 0 ? nutrients.fat / profile.fatGoal : 0, color: Colors.blue)),
      ],
    );
  }
}

class _MealsSection extends StatelessWidget {
  final DailyLog dailyLog;
  final UserProfile profile;
  final VoidCallback onDataChanged;

  const _MealsSection({required this.dailyLog, required this.profile, required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
         Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Приемы пищи', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
              TextButton(
                onPressed: () {
                  // TODO: Implement meal history navigation
                },
                child: const Text('История', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildMealCards(context, dailyLog, onDataChanged),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Вода', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
            ],
          ),
           const SizedBox(height: 16),
          _WaterCard(
            waterIntake: dailyLog.waterIntake, 
            waterGoal: profile.waterGoal, 
            onAdd: () async {
              // TODO: Implement water adding and saving logic
              // Example: 
              // final service = DailyLogService();
              // await service.addWater(dailyLog.date, 250); // Add 250ml
              // onDataChanged(); // Reload data
            }
          ),
         
      ],
    );
  }

  List<Widget> _buildMealCards(BuildContext context, DailyLog log, VoidCallback onDataChanged) {
    const mealOrder = ['Завтрак', 'Обед', 'Ужин', 'Перекусы'];
    const mealDetails = {
      'Завтрак': {'icon': Symbols.wb_sunny, 'iconBg': Color(0xFFFFF4E6), 'iconColor': Colors.orange, 'rec': '450 - 600'},
      'Обед': {'icon': Symbols.lunch_dining, 'iconBg': Color(0xFFE6F9F0), 'iconColor': AppColors.primary, 'rec': '600 - 800'},
      'Ужин': {'icon': Symbols.nights_stay, 'iconBg': Color(0xFFEEF2FF), 'iconColor': Colors.indigo, 'rec': '450 - 600'},
      'Перекусы': {'icon': Symbols.cookie, 'iconBg': Color(0xFFFCE7F3), 'iconColor': Colors.pink, 'rec': '150 - 250'},
    };

    return mealOrder.map((mealName) {
      final items = log.meals[mealName] ?? [];
      final calories = items.fold<double>(0, (sum, item) => sum + item.nutrients.calories);
      final details = mealDetails[mealName]!;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _MealCard(
          mealName: mealName,
          recommended: details['rec'] as String,
          calories: calories.toStringAsFixed(0),
          icon: details['icon'] as IconData,
          iconBg: details['iconBg'] as Color,
          iconColor: details['iconColor'] as Color,
          items: items,
          onDataChanged: onDataChanged,
        ),
      );
    }).toList();
  }
}

class _WaterCard extends StatelessWidget {
  final int waterIntake; // в мл
  final int waterGoal; // в мл
  final VoidCallback onAdd;

  const _WaterCard({required this.waterIntake, required this.waterGoal, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const iconColor = Colors.blue;
    final liters = waterIntake / 1000;
    final goalLiters = waterGoal / 1000;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: AppStyles.mediumBorderRadius
              ),
              child: const Icon(Symbols.water_drop, color: iconColor, size: 28, fill: 1),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Вода', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text('Цель: ${goalLiters.toStringAsFixed(1)} л', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text('${liters.toStringAsFixed(2)} л', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(width: 12),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor,
                   boxShadow: [BoxShadow(color: iconColor.withAlpha(100), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))]
                ),
                child: const Icon(Symbols.add, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        backgroundColor: AppColors.primary.withAlpha(26),
        progressColor: AppColors.primary,
      ),
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
    if (radius <= 0) return; 

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
                backgroundColor: color.withAlpha(38),
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
  final String mealName, recommended, calories;
  final IconData icon;
  final Color iconBg, iconColor;
  final List<FoodItem> items;
  final VoidCallback onDataChanged;

  const _MealCard({
    required this.mealName, 
    required this.recommended, 
    required this.calories, 
    required this.icon, 
    required this.iconBg, 
    required this.iconColor,
    required this.items,
    required this.onDataChanged
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotEaten = calories == '0';
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MealDetailScreen(mealName: mealName, items: items)),
        );
        if (result == true) {
          onDataChanged();
        }
      },
      borderRadius: AppStyles.cardRadius,
      child: Opacity(
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
                      Text(mealName, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text('Реком: $recommended ккал', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (!isNotEaten)
                  Text('$calories ккал', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () async {
                     final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MealDetailScreen(mealName: mealName, items: items)),
                      );
                      if (result == true) {
                        onDataChanged();
                      }
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(77), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 5))]
                    ),
                    child: const Icon(Symbols.add, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
