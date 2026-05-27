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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.entry?.description ?? '');
    _caloriesController =
        TextEditingController(text: widget.entry?.calories.toString() ?? '');
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
      
      _nameController.text = draft.name;
      _descriptionController.text = draft.description;
      _caloriesController.text = draft.calories.toString();
      
      setState(() {
        _isAiEstimating = false;
        _isAiEstimateError = false;
        _aiEstimateStatus = l10n.activityAiEstimated(draft.calories);
      });
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

    // Premium HSL-inspired gradient backgrounds for light/dark modes
    final aiCardBg = isDark
        ? [
            const Color(0xFF1E3326).withValues(alpha: 0.8),
            const Color(0xFF0F2218).withValues(alpha: 0.8)
          ]
        : [
            const Color(0xFFE8F5E9).withValues(alpha: 0.8),
            const Color(0xFFE0F2F1).withValues(alpha: 0.8)
          ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SMART AI ASSISTANT CARD (LOGICAL STEP 1)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: aiCardBg,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppStyles.cardRadius,
                  border: Border.all(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
                                    color: isDark ? Colors.white : AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Опишите активность в свободной форме для авторасчета",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.activityDescriptionLabel,
                          hintText: l10n.activityDescriptionHint,
                          alignLabelWithHint: true,
                          fillColor: isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.8),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: AppStyles.mediumBorderRadius,
                            borderSide: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppStyles.mediumBorderRadius,
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
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
                              backgroundColor: isAiAvailable
                                  ? AppColors.primary
                                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                              foregroundColor: isAiAvailable
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppStyles.mediumBorderRadius,
                              ),
                              elevation: isAiAvailable ? 2 : 0,
                            ),
                            icon: _isAiEstimating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Icon(
                                    isAiAvailable
                                        ? Symbols.auto_awesome
                                        : Symbols.lock,
                                    size: 18,
                                  ),
                            label: Text(
                              _isAiEstimating
                                  ? l10n.activityAiEstimating
                                  : l10n.activityAiEstimateButton,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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
                            color: (_isAiEstimateError ? Colors.red : Colors.green)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (_isAiEstimateError ? Colors.red : Colors.green)
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
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _aiEstimateStatus!,
                                  style: TextStyle(
                                    color: _isAiEstimateError
                                        ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                                        : (isDark ? Colors.green.shade300 : Colors.green.shade700),
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

              // 2. MANUAL WORKOUT DETAILS CARD (LOGICAL STEP 2)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                  side: BorderSide(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                  ),
                ),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.activityNameLabel,
                          prefixIcon: const Icon(Symbols.fitness_center, color: AppColors.primary),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.burnedCaloriesLabel,
                          suffixText: l10n.kcal,
                          prefixIcon: const Icon(Symbols.local_fire_department, color: Colors.orange),
                        ),
                        validator: (value) {
                          final calories = int.tryParse(value?.trim() ?? '');
                          if (calories == null || calories <= 0) {
                            return l10n.enterCorrectCalories;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. ICON SELECTION SECTION (LOGICAL STEP 3)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                  side: BorderSide(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                  ),
                ),
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
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: ActivityEntry.iconOptions.entries.map((e) {
                          final isSelected = _selectedIconName == e.key;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedIconName = e.key;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange.withValues(alpha: 0.14)
                                    : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange
                                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.orange.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                e.value,
                                color: isSelected
                                    ? Colors.orange
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                size: 24,
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
