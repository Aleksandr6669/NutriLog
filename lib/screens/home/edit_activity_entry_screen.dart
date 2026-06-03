import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_log/models/daily_log.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class EditActivityEntryScreen extends StatefulWidget {
  final ActivityEntry? entry;

  const EditActivityEntryScreen({super.key, this.entry});

  @override
  State<EditActivityEntryScreen> createState() =>
      _EditActivityEntryScreenState();
}

class _EditActivityEntryScreenState extends State<EditActivityEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _geminiService = GeminiRecipeService();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _caloriesController;
  late String _selectedIconName;
  bool _isAiEstimating = false;
  String? _aiEstimateStatus;
  bool _isAiEstimateError = false;

  static const Map<String, String> _iconLabelsRu = {
    'fitness_center': 'Зал',
    'directions_run': 'Бег',
    'directions_walk': 'Ходьба',
    'directions_bike': 'Велосипед',
    'pool': 'Бассейн',
    'sports_soccer': 'Футбол',
    'sports_basketball': 'Баскетбол',
    'sports_volleyball': 'Волейбол',
    'sports_tennis': 'Теннис',
    'sports_martial_arts': 'Борьба',
    'self_improvement': 'Йога',
    'hiking': 'Поход',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.entry?.description ?? '');
    _caloriesController = TextEditingController(
      text: (widget.entry == null || widget.entry!.calories == 0)
          ? ''
          : widget.entry!.calories.toString(),
    );
    _selectedIconName = widget.entry?.iconName ?? ActivityEntry.defaultIconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;

    Navigator.of(context).pop(
      ActivityEntry(
        id: widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        description: description,
        calories: calories,
        iconName: _selectedIconName,
      ),
    );
  }

  String _inferIconFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('бег') || lower.contains('run')) return 'directions_run';
    if (lower.contains('ходьб') ||
        lower.contains('шаг') ||
        lower.contains('walk')) return 'directions_walk';
    if (lower.contains('вело') ||
        lower.contains('байк') ||
        lower.contains('bike')) return 'directions_bike';
    if (lower.contains('плав') ||
        lower.contains('бассейн') ||
        lower.contains('swim') ||
        lower.contains('pool')) return 'pool';
    if (lower.contains('футб') ||
        lower.contains('soccer') ||
        lower.contains('football')) return 'sports_soccer';
    if (lower.contains('баскет') || lower.contains('basketball'))
      return 'sports_basketball';
    if (lower.contains('волей') || lower.contains('volleyball'))
      return 'sports_volleyball';
    if (lower.contains('теннис') || lower.contains('tennis'))
      return 'sports_tennis';
    if (lower.contains('борьб') ||
        lower.contains('бокс') ||
        lower.contains('каратэ') ||
        lower.contains('martial')) return 'sports_martial_arts';
    if (lower.contains('йог') ||
        lower.contains('пилатес') ||
        lower.contains('stretch') ||
        lower.contains('yoga')) return 'self_improvement';
    if (lower.contains('поход') ||
        lower.contains('горы') ||
        lower.contains('hike') ||
        lower.contains('hiking')) return 'hiking';
    return 'fitness_center';
  }

  Future<void> _estimateCaloriesWithAi() async {
    final l10n = AppLocalizations.of(context)!;
    final source = _descriptionController.text.trim();

    if (source.isEmpty) {
      setState(() {
        _aiEstimateStatus = l10n.activityAiNeedContext;
        _isAiEstimateError = true;
      });
      return;
    }

    setState(() {
      _isAiEstimating = true;
      _isAiEstimateError = false;
      _aiEstimateStatus = l10n.activityAiEstimating;
    });

    try {
      final draft = await _geminiService.estimateActivityDraftFromDescription(
        description: source,
        locale: Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;

      // Option 2: Direct insertion, immediately populates the manual fields and automatically selects matching sport icon
      setState(() {
        _nameController.text = draft.name;
        _descriptionController.text = draft.description;
        _caloriesController.text = draft.calories.toString();
        _selectedIconName = _inferIconFromName(draft.name);

        _isAiEstimating = false;
        _isAiEstimateError = false;
        _aiEstimateStatus = l10n.activityAiEstimated(draft.calories);
      });
      HapticFeedback.mediumImpact();
    } on GeminiRecipeException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiEstimating = false;
        _isAiEstimateError = true;
        _aiEstimateStatus = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAiEstimating = false;
        _isAiEstimateError = true;
        _aiEstimateStatus = l10n.activityAiEstimateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(isEdit ? l10n.editActivity : l10n.newActivity),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _save,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: glassBodyPadding(context, top: 16, bottom: 40),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SMART AI ASSISTANT CARD (Matches App Style Cards + Form Inputs)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Symbols.auto_awesome,
                              color: AppColors.primary,
                              size: 20,
                              fill: 1.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Умный ввод ИИ",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Опишите активность в свободной форме для авторасчета",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: AppStyles.inputDecoration(
                          l10n.activityDescriptionLabel,
                        ).copyWith(
                          hintText: l10n.activityDescriptionHint,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Builder(builder: (context) {
                        final profile =
                            context.watch<ProfileProvider>().profile;
                        final isAiAvailable =
                            profile?.isAiFeatureAvailable ?? false;

                        return SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (!isAiAvailable) {
                                context.push('/subscription',
                                    extra: SubscriptionTier.standard);
                                return;
                              }
                              if (!_isAiEstimating) {
                                _estimateCaloriesWithAi();
                              }
                            },
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.mediumBorderRadius,
                              ),
                            ),
                            icon: _isAiEstimating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    isAiAvailable
                                        ? Symbols.auto_awesome
                                        : Symbols.lock,
                                    size: 18,
                                    fill: 1.0,
                                  ),
                            label: Text(
                              _isAiEstimating
                                  ? l10n.activityAiEstimating
                                  : l10n.activityAiEstimateButton,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                      if (_aiEstimateStatus != null) ...[
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_isAiEstimateError ? Colors.red : Colors.green)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (_isAiEstimateError
                                      ? Colors.red
                                      : Colors.green)
                                  .withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isAiEstimateError
                                    ? Symbols.error
                                    : Symbols.check_circle,
                                color: _isAiEstimateError
                                    ? Colors.red
                                    : Colors.green,
                                size: 20,
                                fill: 1.0,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _aiEstimateStatus!,
                                  style: TextStyle(
                                    color: _isAiEstimateError
                                        ? (isDark
                                            ? Colors.red.shade300
                                            : Colors.red.shade700)
                                        : (isDark
                                            ? Colors.green.shade300
                                            : Colors.green.shade700),
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. MANUAL WORKOUT DETAILS CARD (Matches App Style Cards + Form Inputs)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Детали тренировки",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: AppStyles.inputDecoration(
                          l10n.activityNameLabel,
                          Symbols.fitness_center,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.enterActivityName;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: AppStyles.inputDecoration(
                          l10n.burnedCaloriesLabel,
                          Symbols.local_fire_department,
                        ).copyWith(
                          suffixText: l10n.kcal,
                        ),
                        validator: (value) {
                          final calories = int.tryParse(value?.trim() ?? '');
                          if (calories == null || calories <= 0) {
                            return l10n.enterCorrectCalories;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Symbols.info,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ru'
                                    ? 'Внесение точного количества сожженных калорий помогает ИИ правильно балансировать ваш дневной рацион.'
                                    : (Localizations.localeOf(context)
                                                .languageCode ==
                                            'uk'
                                        ? 'Внесення точної кількості спалених калорій допомагає ШІ правильно балансувати ваш денний раціон.'
                                        : 'Entering accurate calories burned helps AI balance your daily diet and energy intake properly.'),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. ICON SELECTION SECTION (With crystal clear text labels under sport icons)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.activityIcon,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: ActivityEntry.iconOptions.entries.map((e) {
                          final isSelected = _selectedIconName == e.key;
                          final label = _iconLabelsRu[e.key] ?? 'Спорт';

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedIconName = e.key;
                              });
                            },
                            child: SizedBox(
                              width: 60,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.08 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.15)
                                            : (isDark
                                                ? Colors.grey.shade900
                                                : Colors.grey.shade100),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade300),
                                          width: isSelected ? 2.2 : 1.0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        e.value,
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade700),
                                        size: 24,
                                        fill: isSelected ? 1.0 : 0.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
