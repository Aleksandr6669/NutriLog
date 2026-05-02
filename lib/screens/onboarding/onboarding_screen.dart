import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function()? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _totalSteps = 3;

  final _profileService = ProfileService();
  final _geminiRecipeService = GeminiRecipeService();
  final _pageController = PageController();

  final _physicalFormKey = GlobalKey<FormState>();
  final _generalFormKey = GlobalKey<FormState>();
  final _dailyGoalsFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  final _weightGoalController = TextEditingController();
  final _activityTypesController = TextEditingController();
  final _aiContextController = TextEditingController();

  final _calorieGoalController = TextEditingController();
  final _proteinGoalController = TextEditingController();
  final _fatGoalController = TextEditingController();
  final _carbsGoalController = TextEditingController();
  final _waterGoalController = TextEditingController();
  final _stepsGoalController = TextEditingController();

  Gender _gender = Gender.female;
  GoalType _goalType = GoalType.healthyEating;
  ActivityFrequency _activityFrequency = ActivityFrequency.light;
  DateTime _birthDate = DateTime(1997, 6, 15);

  int _currentStep = 0;
  bool _saving = false;
  bool _isAiFillingDailyGoals = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _weightGoalController.dispose();
    _activityTypesController.dispose();
    _aiContextController.dispose();
    _calorieGoalController.dispose();
    _proteinGoalController.dispose();
    _fatGoalController.dispose();
    _carbsGoalController.dispose();
    _waterGoalController.dispose();
    _stepsGoalController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) return;
    if (_currentStep >= _totalSteps - 1) return;

    final nextStep = _currentStep + 1;
    setState(() => _currentStep = nextStep);
    await _pageController.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _prevStep() async {
    if (_currentStep <= 0) return;
    final prevStep = _currentStep - 1;
    setState(() => _currentStep = prevStep);
    await _pageController.animateToPage(
      prevStep,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _physicalFormKey.currentState?.validate() ?? false;
      case 1:
        return _generalFormKey.currentState?.validate() ?? false;
      case 2:
        return _dailyGoalsFormKey.currentState?.validate() ?? false;
      default:
        return false;
    }
  }

  Future<void> _save() async {
    if (!_validateCurrentStep()) return;
    setState(() => _saving = true);

    try {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        height: int.parse(_heightController.text.trim()),
        weight: _parseDouble(_weightController.text.trim()),
        weightGoal: _parseDouble(_weightGoalController.text.trim()),
        goalType: _goalType,
        activityFrequency: _activityFrequency,
        activityTypes: _activityTypesController.text.trim(),
        aiContext: _aiContextController.text.trim(),
        calorieGoal: int.parse(_calorieGoalController.text.trim()),
        proteinGoal: int.parse(_proteinGoalController.text.trim()),
        fatGoal: int.parse(_fatGoalController.text.trim()),
        carbsGoal: int.parse(_carbsGoalController.text.trim()),
        waterGoal: int.parse(_waterGoalController.text.trim()),
        stepsGoal: int.parse(_stepsGoalController.text.trim()),
        weightHistory: const [],
      );

      await _profileService.saveProfile(profile);
      if (!mounted) return;

      if (widget.onCompleted != null) {
        await widget.onCompleted!.call();
      } else {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fillDailyGoalsWithAi() async {
    if (_isAiFillingDailyGoals) return;

    // Не опираемся на состояние off-screen Form: проверяем обязательные поля напрямую.
    final hasValidBaseProfileData = _hasValidBaseProfileData();
    if (!hasValidBaseProfileData) {
      // SnackBar убран по требованию
      return;
    }

    setState(() => _isAiFillingDailyGoals = true);
    try {
      final profileDraft = UserProfile(
        name: _nameController.text.trim().isEmpty
            ? 'Гость'
            : _nameController.text.trim(),
        gender: _gender,
        birthDate: _birthDate,
        height: int.parse(_heightController.text.trim()),
        weight: _parseDouble(_weightController.text.trim()),
        weightGoal: _parseDouble(_weightGoalController.text.trim()),
        goalType: _goalType,
        activityFrequency: _activityFrequency,
        activityTypes: _activityTypesController.text.trim(),
        aiContext: _aiContextController.text.trim(),
        calorieGoal: int.tryParse(_calorieGoalController.text.trim()) ?? 1800,
        proteinGoal: int.tryParse(_proteinGoalController.text.trim()) ?? 120,
        fatGoal: int.tryParse(_fatGoalController.text.trim()) ?? 60,
        carbsGoal: int.tryParse(_carbsGoalController.text.trim()) ?? 195,
        waterGoal: int.tryParse(_waterGoalController.text.trim()) ?? 2000,
        stepsGoal: int.tryParse(_stepsGoalController.text.trim()) ?? 10000,
        weightHistory: const [],
      );

      final draft = await _geminiRecipeService.generateDailyGoals(
        profile: profileDraft,
      );

      if (!mounted) return;
      setState(() {
        _calorieGoalController.text = draft.calorieGoal.toString();
        _proteinGoalController.text = draft.proteinGoal.toString();
        _fatGoalController.text = draft.fatGoal.toString();
        _carbsGoalController.text = draft.carbsGoal.toString();
        _waterGoalController.text = draft.waterGoal.toString();
        _stepsGoalController.text = draft.stepsGoal.toString();
      });

      // SnackBar убран по требованию
    } on GeminiRecipeException {
      if (!mounted) return;
      // SnackBar убран по требованию
    } catch (_) {
      if (!mounted) return;
      // SnackBar убран по требованию
    } finally {
      if (mounted) setState(() => _isAiFillingDailyGoals = false);
    }
  }

  String? _requiredValidator(String? value,
      {String message = 'Обязательное поле'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _positiveIntValidator(String? value, String emptyMessage) {
    if (value == null || value.trim().isEmpty) return emptyMessage;
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return 'Введите число больше 0';
    return null;
  }

  String? _positiveDoubleValidator(String? value, String emptyMessage) {
    if (value == null || value.trim().isEmpty) return emptyMessage;
    final parsed = _tryParseDouble(value.trim());
    if (parsed == null || parsed <= 0) return 'Введите число больше 0';
    return null;
  }

  double _parseDouble(String value) => double.parse(value.replaceAll(',', '.'));

  double? _tryParseDouble(String value) =>
      double.tryParse(value.replaceAll(',', '.'));

  bool _hasValidBaseProfileData() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;

    final height = int.tryParse(_heightController.text.trim());
    final weight = _tryParseDouble(_weightController.text.trim());
    final weightGoal = _tryParseDouble(_weightGoalController.text.trim());
    if (height == null || height <= 0) return false;
    if (weight == null || weight <= 0) return false;
    if (weightGoal == null || weightGoal <= 0) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final stepTitle = switch (_currentStep) {
      0 => 'Физические параметры',
      1 => 'Общие цели',
      _ => 'Дневные цели',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Первичная настройка ${_currentStep + 1}/$_totalSteps'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stepTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / _totalSteps,
                      minHeight: 8,
                      color: AppColors.primary,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPhysicalStep(context),
                  _buildGeneralGoalsStep(context),
                  _buildDailyGoalsStep(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _prevStep,
                        icon: const Icon(Symbols.arrow_back),
                        label: const Text('Назад'),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : (_currentStep == _totalSteps - 1
                              ? _save
                              : _nextStep),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _currentStep == _totalSteps - 1
                                  ? Symbols.check_circle
                                  : Symbols.arrow_forward,
                            ),
                      label: Text(
                        _currentStep == _totalSteps - 1
                            ? 'Сохранить и продолжить'
                            : 'Далее',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalStep(BuildContext context) {
    final theme = Theme.of(context);
    final birthDateText =
        '${_birthDate.day.toString().padLeft(2, '0')}.${_birthDate.month.toString().padLeft(2, '0')}.${_birthDate.year}';

    return Form(
      key: _physicalFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _buildInfoCard(
            theme,
            'Здесь указываются базовые физические параметры: пол, возраст, рост и текущий вес. Эти данные нужны для персональных расчетов.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            validator: (v) =>
                _requiredValidator(v, message: 'Введите ваше имя'),
            decoration: AppStyles.inputDecoration('Имя', Symbols.person),
          ),
          const SizedBox(height: 16),
          _buildGenderSelector(theme),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickBirthDate,
            child: InputDecorator(
              decoration:
                  AppStyles.inputDecoration('Дата рождения', Symbols.cake),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    birthDateText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_calcAge(_birthDate)} лет',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => _positiveIntValidator(v, 'Введите ваш рост'),
            decoration: AppStyles.inputDecoration('Рост (см)', Symbols.height),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,1}')),
            ],
            validator: (v) => _positiveDoubleValidator(v, 'Введите ваш вес'),
            decoration:
                AppStyles.inputDecoration('Текущий вес (кг)', Symbols.weight),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralGoalsStep(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _generalFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _buildInfoCard(
            theme,
            'Задайте стратегию прогресса: целевой вес, тип цели и ваш спортивный режим. Эти данные передаются нейросети для более точных дневных норм.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightGoalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,1}')),
            ],
            validator: (v) =>
                _positiveDoubleValidator(v, 'Введите цель по весу'),
            decoration:
                AppStyles.inputDecoration('Цель по весу (кг)', Symbols.flag),
          ),
          const SizedBox(height: 16),
          _buildGoalTypeSelector(theme),
          const SizedBox(height: 16),
          _buildActivityFrequencySelector(theme),
          const SizedBox(height: 16),
          TextFormField(
            controller: _activityTypesController,
            maxLines: 2,
            decoration: AppStyles.inputDecoration(
              'Каким спортом/активностью занимаетесь',
              Symbols.fitness_center,
            ).copyWith(
              hintText: 'Можно оставить пустым',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aiContextController,
            maxLines: 3,
            decoration: AppStyles.inputDecoration(
              'Дополнительно для нейросети',
              Symbols.psychology,
            ).copyWith(
              hintText:
                  'Например: сидячая работа, ранние тренировки, ограничения в еде. Можно оставить пустым.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalsStep(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _dailyGoalsFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          _buildInfoCard(
            theme,
            'Здесь задаются дневные нормы: калории, вода, шаги и БЖУ. Затем их можно скорректировать в профиле.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAiFillingDailyGoals ? null : _fillDailyGoalsWithAi,
              icon: _isAiFillingDailyGoals
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.auto_awesome),
              label: Text(
                _isAiFillingDailyGoals
                    ? 'Нейросеть рассчитывает цели...'
                    : 'Рассчитать дневные цели нейросетью',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.28),
              ),
            ),
            child: const Text(
              'Нейросеть рассчитывает цели по вашим параметрам. Рекомендуется проверить значения перед сохранением.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          _buildDailyGoalField(
            controller: _calorieGoalController,
            label: 'Калории (ккал)',
            icon: Symbols.local_fire_department,
            emptyMessage: 'Введите цель по калориям',
          ),
          const SizedBox(height: 16),
          _buildDailyGoalField(
            controller: _waterGoalController,
            label: 'Вода (мл)',
            icon: Symbols.water_drop,
            emptyMessage: 'Введите цель по воде',
          ),
          const SizedBox(height: 16),
          _buildDailyGoalField(
            controller: _stepsGoalController,
            label: 'Шаги',
            icon: Symbols.directions_walk,
            emptyMessage: 'Введите цель по шагам',
          ),
          const Divider(height: 32),
          _buildDailyGoalField(
            controller: _proteinGoalController,
            label: 'Белки (г)',
            icon: Symbols.egg,
            emptyMessage: 'Введите цель по белкам',
          ),
          const SizedBox(height: 16),
          _buildDailyGoalField(
            controller: _carbsGoalController,
            label: 'Углеводы (г)',
            icon: Symbols.bakery_dining,
            emptyMessage: 'Введите цель по углеводам',
          ),
          const SizedBox(height: 16),
          _buildDailyGoalField(
            controller: _fatGoalController,
            label: 'Жиры (г)',
            icon: Symbols.oil_barrel,
            emptyMessage: 'Введите цель по жирам',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Symbols.info, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String emptyMessage,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) => _positiveIntValidator(v, emptyMessage),
      decoration: AppStyles.inputDecoration(label, icon),
    );
  }

  Widget _buildGenderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Пол',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildChoiceChip(
              theme: theme,
              title: 'Мужской',
              icon: Symbols.male,
              selected: _gender == Gender.male,
              onTap: () => setState(() => _gender = Gender.male),
            ),
            const SizedBox(width: 12),
            _buildChoiceChip(
              theme: theme,
              title: 'Женский',
              icon: Symbols.female,
              selected: _gender == Gender.female,
              onTap: () => setState(() => _gender = Gender.female),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalTypeSelector(ThemeData theme) {
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
        ...GoalType.values.map(
          (goal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSelectionCard(
              theme: theme,
              selected: _goalType == goal,
              icon: _goalTypeIcon(goal),
              title: goal.ruLabel,
              subtitle: goal.ruHint,
              onTap: () => setState(() => _goalType = goal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFrequencySelector(ThemeData theme) {
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
        ...ActivityFrequency.values.map(
          (frequency) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSelectionCard(
              theme: theme,
              selected: _activityFrequency == frequency,
              icon: _activityFrequencyIcon(frequency),
              title: frequency.ruLabel,
              subtitle: frequency.ruHint,
              onTap: () => setState(() => _activityFrequency = frequency),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required ThemeData theme,
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final backgroundColor = selected
        ? AppColors.primary.withValues(alpha: 0.14)
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade50);
    final borderColor = selected
        ? AppColors.primary
        : (theme.brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300);
    final titleColor =
        selected ? AppColors.primary : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
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
                Icon(icon, color: titleColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
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
              subtitle,
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

  Widget _buildChoiceChip({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.buttonRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.1)
                : (theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200),
            borderRadius: AppStyles.buttonRadius,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (theme.brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade400),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : theme.iconTheme.color,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
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

  IconData _activityFrequencyIcon(ActivityFrequency frequency) {
    switch (frequency) {
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

  int _calcAge(DateTime birthDate) {
    final today = DateTime.now();
    int years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years;
  }
}
