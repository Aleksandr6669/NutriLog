import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class EditGeneralGoalsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditGeneralGoalsScreen({super.key, required this.profile});

  @override
  State<EditGeneralGoalsScreen> createState() => _EditGeneralGoalsScreenState();
}

class _EditGeneralGoalsScreenState extends State<EditGeneralGoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late TextEditingController _weightGoalController;
  late GoalType _goalType;

  @override
  void initState() {
    super.initState();
    _weightGoalController = TextEditingController(
      text: widget.profile.weightGoal.toString(),
    );
    _goalType = widget.profile.goalType;
  }

  @override
  void dispose() {
    _weightGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        weightGoal: double.parse(_weightGoalController.text),
        goalType: _goalType,
      );

      await _profileService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Общие цели обновлены!', style: TextStyle(fontSize: 18)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 0, left: 16, right: 16),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Общие цели'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _saveProfile,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _weightGoalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите цель по весу';
                  }
                  return null;
                },
                decoration: AppStyles.inputDecoration(
                    'Цель по весу (кг)', Symbols.flag),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildGoalTypeSelector(context),
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
              _goalTypeHint(goal),
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

  String _goalTypeHint(GoalType goal) {
    switch (goal) {
      case GoalType.loseWeight:
        return 'Мягкое снижение веса за счет умеренного дефицита калорий, контроля порций и стабильного режима питания без резких ограничений.';
      case GoalType.gainWeight:
        return 'Постепенный набор веса через аккуратный профицит калорий, регулярные приемы пищи и отслеживание динамики каждую неделю.';
      case GoalType.gainMuscle:
        return 'Рост мышечной массы с фокусом на белок, силовые тренировки и восстановление, чтобы прогресс был заметным и устойчивым.';
      case GoalType.healthyEating:
        return 'Сбалансированный рацион на каждый день: больше цельных продуктов, разнообразие нутриентов и комфортный ритм без перегибов.';
      case GoalType.energetic:
        return 'Больше энергии на весь день за счет регулярного питания, качественного сна, достаточной воды и более ровного уровня активности.';
    }
  }
}
