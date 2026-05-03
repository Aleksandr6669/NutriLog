import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class EditGoalsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditGoalsScreen({super.key, required this.profile});

  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _geminiRecipeService = GeminiRecipeService();

  late TextEditingController _calorieGoalController;
  late TextEditingController _waterGoalController;
  late TextEditingController _stepsGoalController;
  late TextEditingController _proteinGoalController;
  late TextEditingController _carbsGoalController;
  late TextEditingController _fatGoalController;
  bool _isAiFilling = false;

  @override
  void initState() {
    super.initState();
    _calorieGoalController =
        TextEditingController(text: widget.profile.calorieGoal.toString());
    _waterGoalController =
        TextEditingController(text: widget.profile.waterGoal.toString());
    _stepsGoalController =
        TextEditingController(text: widget.profile.stepsGoal.toString());
    _proteinGoalController =
        TextEditingController(text: widget.profile.proteinGoal.toString());
    _carbsGoalController =
        TextEditingController(text: widget.profile.carbsGoal.toString());
    _fatGoalController =
        TextEditingController(text: widget.profile.fatGoal.toString());
  }

  @override
  void dispose() {
    _calorieGoalController.dispose();
    _waterGoalController.dispose();
    _stepsGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    _fatGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        calorieGoal: int.parse(_calorieGoalController.text),
        waterGoal: int.parse(_waterGoalController.text),
        stepsGoal: int.parse(_stepsGoalController.text),
        proteinGoal: int.parse(_proteinGoalController.text),
        carbsGoal: int.parse(_carbsGoalController.text),
        fatGoal: int.parse(_fatGoalController.text),
      );

      await context.read<ProfileProvider>().updateProfile(updatedProfile);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  Future<void> _fillGoalsWithAi() async {
    setState(() => _isAiFilling = true);

    try {
      final draft = await _geminiRecipeService.generateDailyGoals(
        profile: widget.profile,
      );

      if (!mounted) return;

      setState(() {
        _calorieGoalController.text = draft.calorieGoal.toString();
        _waterGoalController.text = draft.waterGoal.toString();
        _stepsGoalController.text = draft.stepsGoal.toString();
        _proteinGoalController.text = draft.proteinGoal.toString();
        _carbsGoalController.text = draft.carbsGoal.toString();
        _fatGoalController.text = draft.fatGoal.toString();
      });

      // SnackBar при автозаполнении убран по требованию
    } on GeminiRecipeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 0, left: 16, right: 16),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.aiGoalsFailed),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 0, left: 16, right: 16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAiFilling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(l10n.dailyGoalsTitle),
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
                          l10n.dailyGoalsInfoText,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAiFilling ? null : _fillGoalsWithAi,
                  icon: _isAiFilling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.auto_awesome),
                  label: Text(
                    _isAiFilling
                        ? l10n.aiCalculatingGoals
                        : l10n.aiCalculateGoals,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  l10n.aiGoalsNotice,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _calorieGoalController,
                label: l10n.caloriesKcal,
                icon: Symbols.local_fire_department,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? l10n.enterCalorieGoal
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _waterGoalController,
                label: l10n.waterMl,
                icon: Symbols.water_drop,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterWaterGoal : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _stepsGoalController,
                label: l10n.steps,
                icon: Symbols.directions_walk,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterStepsGoal : null,
              ),
              const Divider(height: 32),
              _buildTextFormField(
                controller: _proteinGoalController,
                label: l10n.proteinG,
                icon: Symbols.egg,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? l10n.enterProteinGoal
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _carbsGoalController,
                label: l10n.carbsG,
                icon: Symbols.bakery_dining,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterCarbsGoal : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _fatGoalController,
                label: l10n.fatG,
                icon: Symbols.oil_barrel,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value == null || value.isEmpty ? l10n.enterFatGoal : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: AppStyles.inputDecoration(label, icon),
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
  }
}
