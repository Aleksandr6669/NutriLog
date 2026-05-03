import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class EditGeneralGoalsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditGeneralGoalsScreen({super.key, required this.profile});

  @override
  State<EditGeneralGoalsScreen> createState() => _EditGeneralGoalsScreenState();
}

class _EditGeneralGoalsScreenState extends State<EditGeneralGoalsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _weightGoalController;
  late TextEditingController _activityTypesController;
  late TextEditingController _aiContextController;
  late GoalType _goalType;
  late ActivityFrequency _activityFrequency;

  @override
  void initState() {
    super.initState();
    _weightGoalController = TextEditingController(
      text: widget.profile.weightGoal.toString(),
    );
    _activityTypesController = TextEditingController(
      text: widget.profile.activityTypes,
    );
    _aiContextController = TextEditingController(
      text: widget.profile.aiContext,
    );
    _goalType = widget.profile.goalType;
    _activityFrequency = widget.profile.activityFrequency;
  }

  @override
  void dispose() {
    _weightGoalController.dispose();
    _activityTypesController.dispose();
    _aiContextController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        weightGoal: double.tryParse(_weightGoalController.text) ?? 0,
        goalType: _goalType,
        activityFrequency: _activityFrequency,
        activityTypes: _activityTypesController.text.trim(),
        aiContext: _aiContextController.text.trim(),
      );
      await context.read<ProfileProvider>().updateProfile(updatedProfile);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(l10n.generalGoals),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _saveProfile,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: glassBodyPadding(context, top: 16, bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Symbols.info,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.generalGoalsInfoText,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightGoalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.enterWeightGoal;
                  }
                  return null;
                },
                decoration:
                    AppStyles.inputDecoration(l10n.weightGoalKg, Symbols.flag),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildGoalTypeSelector(context),
              const SizedBox(height: 16),
              _buildActivityFrequencySelector(context),
              const SizedBox(height: 16),
              TextFormField(
                controller: _activityTypesController,
                decoration: AppStyles.inputDecoration(
                  l10n.sportsActivities,
                  Symbols.fitness_center,
                ).copyWith(
                  hintText: l10n.canBeLeftEmpty,
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aiContextController,
                maxLines: 3,
                decoration: AppStyles.inputDecoration(
                  l10n.additionalForAi,
                  Symbols.psychology,
                ).copyWith(
                  hintText: l10n.additionalForAiHint,
                ),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalTypeSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.track_changes, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Тип цели',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: GoalType.values
              .map((goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildGoalTypeCard(theme, goal),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActivityFrequencySelector(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.fitness_center, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Частота активности',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: ActivityFrequency.values
              .map((activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildActivityCard(theme, activity),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGoalTypeCard(ThemeData theme, GoalType goal) {
    final isSelected = _goalType == goal;
    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.14)
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade50);
    final borderColor = isSelected
        ? AppColors.primary
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300);
    final titleColor =
        isSelected ? AppColors.primary : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _goalType = goal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_goalTypeIcon(goal), color: titleColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    goal.ruLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              goal.ruHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ThemeData theme, ActivityFrequency activity) {
    final isSelected = _activityFrequency == activity;
    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.14)
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade50);
    final borderColor = isSelected
        ? AppColors.primary
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300);
    final titleColor =
        isSelected ? AppColors.primary : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _activityFrequency = activity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_activityIcon(activity), color: titleColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    activity.ruLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              activity.ruHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _goalTypeIcon(GoalType goal) {
    switch (goal) {
      case GoalType.loseWeight:
        return Symbols.trending_down;
      case GoalType.gainWeight:
        return Symbols.trending_up;
      case GoalType.gainMuscle:
        return Symbols.fitness_center;
      case GoalType.healthyEating:
        return Symbols.eco;
      case GoalType.energetic:
        return Symbols.bolt;
    }
  }

  IconData _activityIcon(ActivityFrequency activity) {
    switch (activity) {
      case ActivityFrequency.sedentary:
        return Symbols.airline_seat_recline_normal;
      case ActivityFrequency.light:
        return Symbols.directions_walk;
      case ActivityFrequency.moderate:
        return Symbols.directions_run;
      case ActivityFrequency.active:
        return Symbols.fitness_center;
      case ActivityFrequency.veryActive:
        return Symbols.military_tech;
    }
  }
}
