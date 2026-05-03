import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;

import '../../models/daily_log.dart';
import '../../models/user_profile.dart';
import '../../models/recipe.dart';
import '../../models/food_item.dart';
import '../../services/daily_log_service.dart';
import '../../services/health_steps_service.dart';
import '../../services/home_widget_service.dart';
import '../../services/profile_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import '../recipes/recipes_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/daily_log_provider.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HealthStepsService _healthStepsService = HealthStepsService();

  bool _isHealthConnected = false;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  bool _isCalendarVisible = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _waterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _refreshHealthConnectionState();
    _loadLogForSelectedDate();
    _checkScrollRequest();
  }

  void _checkScrollRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final state = GoRouterState.of(context);
        if (state.uri.queryParameters['scrollTo'] == 'water') {
          _scrollToWater();
        }
      } catch (_) {}
    });
  }

  void _scrollToWater() {
    final context = _waterKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshHealthConnectionState() async {
    final connected = await _healthStepsService.isConnected();
    if (!mounted) return;
    setState(() {
      _isHealthConnected = connected;
    });
  }

  Future<void> _loadLogForSelectedDate() async {
    context.read<DailyLogProvider>().setSelectedDate(_selectedDay);
  }

  Future<void> _showManualStepsInput() async {
    final theme = Theme.of(context);
    final currentSteps =
        context.read<DailyLogProvider>().currentLog?.steps ?? 0;
    final controller = TextEditingController(
      text: currentSteps.toString(),
    );

    final manualSteps = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.of(context)!.manualStepsInput,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)!.enterStepsCount,
                          hintText: '8500',
                          errorText: errorText,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) {
                          final parsed = int.tryParse(controller.text.trim());
                          if (parsed == null || parsed < 0) {
                            setSheetState(() {
                              errorText = AppLocalizations.of(context)!
                                  .enterCorrectNumber;
                            });
                            return;
                          }
                          Navigator.of(context).pop(parsed);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final parsed =
                                    int.tryParse(controller.text.trim());
                                if (parsed == null || parsed < 0) {
                                  setSheetState(() {
                                    errorText = AppLocalizations.of(context)!
                                        .enterCorrectNumber;
                                  });
                                  return;
                                }
                                Navigator.of(context).pop(parsed);
                              },
                              child: Text(AppLocalizations.of(context)!.save),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (manualSteps == null || !mounted) return;
    await context.read<DailyLogProvider>().updateSteps(manualSteps);
  }

  bool _isLoggedDay(DateTime day) {
    return context
        .read<DailyLogProvider>()
        .loggedDates
        .any((d) => isSameDay(d, day));
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      context.read<DailyLogProvider>().setSelectedDate(selectedDay);
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
    HapticFeedback.lightImpact();
    setState(() {
      _isCalendarVisible = !_isCalendarVisible;
    });
  }

  Future<void> _navigateToEditGoals(UserProfile profile) async {
    final result = await context.push<bool>(
      '/profile/daily_goals',
      extra: {'profile': profile},
    );

    if (result == true && mounted) {
      context.read<ProfileProvider>().refreshProfile();
      context.read<DailyLogProvider>().refreshCurrentLog();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected = DateTime(date.year, date.month, date.day);

    final l10n = AppLocalizations.of(context)!;
    if (selected == today) return l10n.today;
    if (selected == yesterday) return l10n.yesterday;
    return DateFormat.yMMMMd(Localizations.localeOf(context).languageCode)
        .format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final userProfile = profileProvider.profile;

        if (profileProvider.isLoading || userProfile == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            forceMaterialTransparency: true,
            flexibleSpace: const GlassAppBarBackground(),
            titleSpacing: 16,
            title: InkWell(
              onTap: _toggleCalendarVisibility,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.calendar_month,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(_formatDate(_selectedDay),
                        style:
                            theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                    const SizedBox(width: 8),
                    Icon(
                      _isCalendarVisible
                          ? Symbols.arrow_drop_up
                          : Symbols.arrow_drop_down,
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
                onPressed: () => _navigateToEditGoals(userProfile),
                tooltip: l10n.editGoals,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Consumer<DailyLogProvider>(
            builder: (context, logProvider, child) {
              final isLoading = logProvider.isLoading;
              final dailyLog = logProvider.currentLog;

              return Stack(
                children: [
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : dailyLog == null
                          ? Center(
                              child: Text(
                                  AppLocalizations.of(context)!.noDataForDate))
                          : SingleChildScrollView(
                              controller: _scrollController,
                              padding: glassBodyPadding(
                                context,
                                top: -4,
                                bottom: 120,
                              ),
                              child: Column(
                                children: [
                                  _CaloriesCard(
                                      dailyLog: dailyLog, profile: userProfile),
                                  const SizedBox(height: 16),
                                  _Macronutrients(
                                      dailyLog: dailyLog, profile: userProfile),
                                  const SizedBox(height: 24),
                                  _MealsSection(
                                    dailyLog: dailyLog,
                                    profile: userProfile,
                                    onDataChanged: () => logProvider
                                        .loadLogForDate(_selectedDay),
                                    selectedDate: _selectedDay,
                                    showManualStepsInput: !_isHealthConnected,
                                    onManualStepsInput: _showManualStepsInput,
                                    waterKey: _waterKey,
                                  ),
                                ],
                              ),
                            ),
                  _buildCalendarOverlay(),
                ],
              );
            },
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
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              top: _isCalendarVisible
                  ? glassAppBarTotalHeight(context) - 12
                  : -400,
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppStyles.largeBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppStyles.largeBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: TableCalendar(
              locale: Localizations.localeOf(context).languageCode,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              eventLoader: (day) => _isLoggedDay(day) ? ['logged'] : [],
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon:
                    Icon(Symbols.chevron_left, color: AppColors.primary),
                rightChevronIcon:
                    Icon(Symbols.chevron_right, color: AppColors.primary),
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
                  if (!_isLoggedDay(day)) return null;

                  return Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(90),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
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
              ),
            ),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final consumedCals = dailyLog.totalNutrients.calories;
    final effectiveConsumed =
        math.max(0.0, consumedCals - dailyLog.activityCalories);
    final remainingCals = profile.calorieGoal - effectiveConsumed;
    final ratio =
        profile.calorieGoal > 0 ? effectiveConsumed / profile.calorieGoal : 0.0;
    final progress = ratio.clamp(0.0, 1.0);
    final progressColor = _goalAwareCalorieColor(ratio, profile.goalType);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppStyles.largeBorderRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: AppStyles.largeBorderRadius,
            border: Border.all(color: AppColors.primary.withAlpha(26))),
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
                    _CircularProgress(
                      progress: progress,
                      strokeWidth: 12,
                      progressColor: progressColor,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(remainingCals.toStringAsFixed(0),
                            style: theme.textTheme.displayLarge?.copyWith(
                                fontSize: 52,
                                color: theme.colorScheme.onSurface)),
                        Text('${l10n.remaining} ${l10n.kcal}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.8,
                                color: theme.textTheme.bodySmall?.color)),
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
                    _buildStatItem(theme, Symbols.restaurant,
                        consumedCals.toStringAsFixed(0), l10n.kcal,
                        color: AppColors.primary),
                    SizedBox(
                        height: 40,
                        child: VerticalDivider(
                            color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.fitness_center,
                        dailyLog.activityCalories.toString(), l10n.activity,
                        color: Colors.orange.shade400),
                    SizedBox(
                        height: 40,
                        child: VerticalDivider(
                            color: theme.dividerColor, thickness: 1)),
                    _buildStatItem(theme, Symbols.flag,
                        profile.calorieGoal.toString(), l10n.goal,
                        color: Colors.blue.shade400),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, IconData icon, String value, String label,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontSize: 18, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.textTheme.bodySmall?.color)),
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
    final l10n = AppLocalizations.of(context)!;
    final nutrients = dailyLog.totalNutrients;
    return Row(
      children: [
        Expanded(
            child: _MacronutrientCard(
                name: l10n.carbs,
                value: '${nutrients.carbs.toStringAsFixed(0)}${l10n.grams}',
                total: '${profile.carbsGoal}${l10n.grams}',
                percentage: profile.carbsGoal > 0
                    ? nutrients.carbs / profile.carbsGoal
                    : 0,
                color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
            child: _MacronutrientCard(
                name: l10n.protein,
                value: '${nutrients.protein.toStringAsFixed(0)}${l10n.grams}',
                total: '${profile.proteinGoal}${l10n.grams}',
                percentage: profile.proteinGoal > 0
                    ? nutrients.protein / profile.proteinGoal
                    : 0,
                color: Colors.orange)),
        const SizedBox(width: 12),
        Expanded(
            child: _MacronutrientCard(
                name: l10n.fat,
                value: '${nutrients.fat.toStringAsFixed(0)}${l10n.grams}',
                total: '${profile.fatGoal}${l10n.grams}',
                percentage:
                    profile.fatGoal > 0 ? nutrients.fat / profile.fatGoal : 0,
                color: Colors.blue)),
      ],
    );
  }
}

class _MealsSection extends StatelessWidget {
  final DailyLog dailyLog;
  final UserProfile profile;
  final Future<void> Function() onDataChanged;
  final DateTime selectedDate;
  final bool showManualStepsInput;
  final Future<void> Function() onManualStepsInput;
  final GlobalKey? waterKey;

  const _MealsSection({
    required this.dailyLog,
    required this.profile,
    required this.onDataChanged,
    required this.selectedDate,
    required this.showManualStepsInput,
    required this.onManualStepsInput,
    this.waterKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.meals,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onSurface)),
            TextButton(
              onPressed: () {
                // TODO: Implement meal history navigation
              },
              child: Text(l10n.history,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._buildMealCards(context, dailyLog, onDataChanged, selectedDate),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.water,
                key: waterKey,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 16),
        _WaterCard(
            waterIntake: dailyLog.waterIntake,
            waterGoal: profile.waterGoal,
            onAdd: () async {
              HapticFeedback.lightImpact();
              final service = DailyLogService();
              final profileService = ProfileService();
              final homeWidgetSyncService = HomeWidgetSyncService();
              await service.addWater(selectedDate, amount: 250);
              final log = await service.getLogForDate(selectedDate);
              final profile = await profileService.loadProfile();
              await homeWidgetSyncService.syncDailyData(
                  log: log, profile: profile);
              await onDataChanged();
            },
            onRemove: () async {
              HapticFeedback.lightImpact();
              final service = DailyLogService();
              final profileService = ProfileService();
              final homeWidgetSyncService = HomeWidgetSyncService();
              await service.removeWater(selectedDate, amount: 250);
              final log = await service.getLogForDate(selectedDate);
              final profile = await profileService.loadProfile();
              await homeWidgetSyncService.syncDailyData(
                  log: log, profile: profile);
              await onDataChanged();
            }),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.physicalCondition,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: 16),
        _ActivityWeightRow(
          dailyLog: dailyLog,
          profile: profile,
          selectedDate: selectedDate,
          onDataChanged: onDataChanged,
          showManualStepsInput: showManualStepsInput,
          onManualStepsInput: onManualStepsInput,
        ),
      ],
    );
  }

  List<Widget> _buildMealCards(
    BuildContext context,
    DailyLog log,
    Future<void> Function() onDataChanged,
    DateTime selectedDate,
  ) {
    const mealOrder = ['Завтрак', 'Обед', 'Ужин', 'Перекусы'];
    final l10n = AppLocalizations.of(context)!;
    final mealDisplayNames = {
      'Завтрак': l10n.breakfast,
      'Обед': l10n.lunch,
      'Ужин': l10n.dinner,
      'Перекусы': l10n.snacks,
    };
    const mealDetails = {
      'Завтрак': {
        'icon': Symbols.wb_sunny,
        'iconBg': Color(0xFFFFF4E6),
        'iconColor': Colors.orange,
      },
      'Обед': {
        'icon': Symbols.lunch_dining,
        'iconBg': Color(0xFFE6F9F0),
        'iconColor': AppColors.primary,
      },
      'Ужин': {
        'icon': Symbols.nights_stay,
        'iconBg': Color(0xFFEEF2FF),
        'iconColor': Colors.indigo,
      },
      'Перекусы': {
        'icon': Symbols.cookie,
        'iconBg': Color(0xFFFCE7F3),
        'iconColor': Colors.pink,
      },
    };

    return mealOrder.map((mealName) {
      final items = log.meals[mealName] ?? [];
      final calories =
          items.fold<double>(0, (sum, item) => sum + item.nutrients.calories);
      final details = mealDetails[mealName]!;
      final recommendation = _mealRecommendationByGoal(profile, mealName);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: _MealCard(
          mealName: mealName,
          recommended: '${recommendation.minKcal} - ${recommendation.maxKcal}',
          calories: calories.toStringAsFixed(0),
          icon: details['icon'] as IconData,
          iconBg: details['iconBg'] as Color,
          iconColor: details['iconColor'] as Color,
          items: items,
          onDataChanged: onDataChanged,
          selectedDate: selectedDate,
        ),
      );
    }).toList();
  }
}

class _WaterCard extends StatelessWidget {
  final int waterIntake; // в мл
  final int waterGoal; // в мл
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _WaterCard(
      {required this.waterIntake,
      required this.waterGoal,
      required this.onAdd,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                  borderRadius: AppStyles.mediumBorderRadius),
              child: const Icon(Symbols.water_drop,
                  color: iconColor, size: 28, fill: 1),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.water,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(l10n.waterGoalText(goalLiters.toStringAsFixed(1)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(l10n.litersValue(liters.toStringAsFixed(2)),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(width: 12),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withAlpha(30),
                    border: Border.all(color: Colors.blue.withAlpha(60))),
                child: const Icon(Symbols.remove, color: Colors.blue, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor,
                    boxShadow: [
                      BoxShadow(
                          color: iconColor.withAlpha(100),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 5))
                    ]),
                child: const Icon(Symbols.add, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityWeightRow extends StatelessWidget {
  final DailyLog dailyLog;
  final UserProfile profile;
  final DateTime selectedDate;
  final Future<void> Function() onDataChanged;
  final bool showManualStepsInput;
  final Future<void> Function() onManualStepsInput;

  const _ActivityWeightRow({
    required this.dailyLog,
    required this.profile,
    required this.selectedDate,
    required this.onDataChanged,
    required this.showManualStepsInput,
    required this.onManualStepsInput,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionInfoCard(
                title: l10n.activityLogTitle,
                value: '${dailyLog.activityCalories} ${l10n.kcal}',
                icon: Symbols.fitness_center,
                iconColor: Colors.orange,
                onTap: () async {
                  final result = await context.push<bool>(
                    '/activity',
                    extra: {
                      'date': selectedDate,
                      'initialActivities': dailyLog.activities,
                    },
                  );
                  if (result == true) {
                    await onDataChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionInfoCard(
                title: l10n.weight,
                value: dailyLog.weight == null
                    ? l10n.notSet
                    : '${dailyLog.weight!.toStringAsFixed(1)} ${l10n.weightUnit}',
                icon: Symbols.monitor_weight,
                iconColor: Colors.indigo,
                onTap: () async {
                  final result = await context.push<bool>(
                    '/weight',
                    extra: {'date': selectedDate},
                  );
                  if (result == true) {
                    await onDataChanged();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StepsInfoCard(
          steps: dailyLog.steps,
          showManualInput: showManualStepsInput,
          onManualInput: onManualStepsInput,
        ),
      ],
    );
  }
}

class _StepsInfoCard extends StatelessWidget {
  final int steps;
  final bool showManualInput;
  final Future<void> Function() onManualInput;

  const _StepsInfoCard({
    required this.steps,
    required this.showManualInput,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: AppStyles.mediumBorderRadius,
              ),
              child: const Icon(Symbols.footprint, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pedometerTitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(l10n.stepsCountValue(steps),
                      style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            if (showManualInput)
              TextButton.icon(
                onPressed: onManualInput,
                icon: const Icon(Symbols.edit, size: 18),
                label: Text(l10n.enterValue),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.cardRadius,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: AppStyles.mediumBorderRadius,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(value, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularProgress extends StatelessWidget {
  final double progress;
  final double strokeWidth;
  final Color? progressColor;

  const _CircularProgress({
    required this.progress,
    this.strokeWidth = 12,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CircularProgressPainter(
        progress: progress,
        strokeWidth: strokeWidth,
        backgroundColor: AppColors.primary.withAlpha(26),
        progressColor: progressColor ?? AppColors.primary,
      ),
      child: Container(),
    );
  }
}

class _MealRecommendation {
  final int minKcal;
  final int maxKcal;

  const _MealRecommendation({required this.minKcal, required this.maxKcal});
}

_MealRecommendation _mealRecommendationByGoal(
    UserProfile profile, String mealName) {
  final int dailyGoal = math.max(profile.calorieGoal, 1200);

  final Map<String, double> shares;
  switch (profile.goalType) {
    case GoalType.loseWeight:
      shares = const {
        'Завтрак': 0.25,
        'Обед': 0.38,
        'Ужин': 0.30,
        'Перекусы': 0.07,
      };
      break;
    case GoalType.gainWeight:
      shares = const {
        'Завтрак': 0.22,
        'Обед': 0.33,
        'Ужин': 0.25,
        'Перекусы': 0.20,
      };
      break;
    case GoalType.gainMuscle:
      shares = const {
        'Завтрак': 0.24,
        'Обед': 0.34,
        'Ужин': 0.26,
        'Перекусы': 0.16,
      };
      break;
    case GoalType.energetic:
      shares = const {
        'Завтрак': 0.27,
        'Обед': 0.35,
        'Ужин': 0.26,
        'Перекусы': 0.12,
      };
      break;
    case GoalType.healthyEating:
      shares = const {
        'Завтрак': 0.25,
        'Обед': 0.35,
        'Ужин': 0.28,
        'Перекусы': 0.12,
      };
      break;
  }

  final double share = shares[mealName] ?? 0.25;
  final int center = (dailyGoal * share).round();
  final double spread = switch (profile.goalType) {
    GoalType.loseWeight => 0.10,
    GoalType.gainMuscle => 0.11,
    GoalType.gainWeight => 0.12,
    GoalType.healthyEating => 0.12,
    GoalType.energetic => 0.14,
  };

  final int minKcal = math.max(60, (center * (1 - spread)).round());
  final int maxKcal = math.max(minKcal + 40, (center * (1 + spread)).round());
  return _MealRecommendation(minKcal: minKcal, maxKcal: maxKcal);
}

Color _goalAwareCalorieColor(double ratio, GoalType goalType) {
  final List<Color> redPalette = [
    Colors.red.shade300,
    Colors.red.shade400,
    Colors.red.shade500,
    Colors.red.shade600,
    Colors.red.shade700,
    Colors.red.shade800,
    Colors.red.shade900,
  ];

  final List<Color> successPalette = switch (goalType) {
    GoalType.loseWeight => [
        Colors.lightGreen.shade300,
        Colors.lightGreen.shade400,
        Colors.lightGreen.shade500,
        Colors.green.shade500,
        Colors.green.shade600,
        Colors.green.shade700,
        Colors.green.shade800,
      ],
    GoalType.gainWeight => [
        Colors.lightBlue.shade300,
        Colors.lightBlue.shade400,
        Colors.blue.shade400,
        Colors.blue.shade500,
        Colors.blue.shade600,
        Colors.blue.shade700,
        Colors.blue.shade800,
      ],
    GoalType.gainMuscle => [
        Colors.cyan.shade300,
        Colors.cyan.shade400,
        Colors.teal.shade400,
        Colors.teal.shade500,
        Colors.teal.shade600,
        Colors.teal.shade700,
        Colors.teal.shade800,
      ],
    GoalType.healthyEating => [
        Colors.lime.shade300,
        Colors.lime.shade400,
        Colors.lightGreen.shade500,
        Colors.green.shade500,
        Colors.green.shade600,
        Colors.green.shade700,
        Colors.green.shade800,
      ],
    GoalType.energetic => [
        Colors.amber.shade300,
        Colors.amber.shade400,
        Colors.amber.shade500,
        Colors.orange.shade500,
        Colors.orange.shade600,
        Colors.deepOrange.shade600,
        Colors.deepOrange.shade700,
      ],
  };

  // После цели считаем относительно 100% дневного плана.
  const target = 1.0;

  final bool isOnTrack = switch (goalType) {
    GoalType.loseWeight => ratio <= target,
    GoalType.gainWeight => ratio >= target,
    GoalType.gainMuscle => ratio >= target,
    GoalType.healthyEating => (ratio - target).abs() <= 0.08,
    GoalType.energetic => ratio >= 0.95,
  };

  final double strength = ((ratio - target).abs() / 0.45).clamp(0.0, 1.0);
  final int index = (strength * 6).round();

  return isOnTrack ? successPalette[index] : redPalette[index];
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter(
      {required this.progress,
      required this.strokeWidth,
      required this.backgroundColor,
      required this.progressColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MacronutrientCard extends StatelessWidget {
  final String name, value, total;
  final double percentage;
  final Color color;

  const _MacronutrientCard(
      {required this.name,
      required this.value,
      required this.total,
      required this.percentage,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue =
        percentage.isFinite ? percentage.clamp(0.0, 1.0) : 0.0;
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
                Text(name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                Text('${(percentage * 100).toInt()}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppStyles.smallBorderRadius,
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                backgroundColor: color.withAlpha(38),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: ' / $total',
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.normal)),
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
  final Future<void> Function() onDataChanged;
  final DateTime selectedDate;

  const _MealCard({
    required this.mealName,
    required this.recommended,
    required this.calories,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.items,
    required this.onDataChanged,
    required this.selectedDate,
  });

  Future<void> _addFromRecipes(BuildContext context) async {
    final selectedRecipes = await Navigator.of(context).push<List<Recipe>>(
      MaterialPageRoute(
        builder: (context) => const RecipesScreen(selectionMode: true),
      ),
    );

    if (selectedRecipes == null || selectedRecipes.isEmpty) return;

    final service = DailyLogService();
    await service.addRecipesToMeal(selectedDate, mealName, selectedRecipes);
    await onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isNotEaten = calories == '0';
    return InkWell(
      onTap: () async {
        final mealType = mealName == 'Завтрак'
            ? 'breakfast'
            : mealName == 'Обед'
                ? 'lunch'
                : mealName == 'Ужин'
                    ? 'dinner'
                    : 'snacks';

        final result = await context.push<bool>(
          '/meal/$mealType',
          extra: {
            'items': items,
            'date': selectedDate,
          },
        );
        if (result == true) {
          await onDataChanged();
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
                      color: isNotEaten
                          ? (theme.brightness == Brightness.light
                              ? Colors.grey.shade100
                              : Colors.grey.shade800)
                          : iconBg,
                      borderRadius: AppStyles.mediumBorderRadius),
                  child: Icon(icon,
                      color: isNotEaten
                          ? (theme.brightness == Brightness.light
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)
                          : iconColor,
                      size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          mealName == 'Завтрак'
                              ? l10n.breakfast
                              : mealName == 'Обед'
                                  ? l10n.lunch
                                  : mealName == 'Ужин'
                                      ? l10n.dinner
                                      : l10n.snacks,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text('Реком: $recommended ${l10n.kcal}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (!isNotEaten)
                  Text('$calories ${AppLocalizations.of(context)!.kcal}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _addFromRecipes(context),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withAlpha(77),
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: const Offset(0, 5))
                        ]),
                    child:
                        const Icon(Symbols.add, color: Colors.white, size: 28),
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
