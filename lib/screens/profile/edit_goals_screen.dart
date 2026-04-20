import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class EditGoalsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditGoalsScreen({super.key, required this.profile});

  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late TextEditingController _calorieGoalController;
  late TextEditingController _waterGoalController;
  late TextEditingController _stepsGoalController;
  late TextEditingController _proteinGoalController;
  late TextEditingController _carbsGoalController;
  late TextEditingController _fatGoalController;

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

      await _profileService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Дневные цели обновлены!', style: TextStyle(fontSize: 18)),
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
        title: const Text('Дневные цели'),
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
                          'Здесь настраиваются дневные нормы:\n'
                          'калории, вода, шаги и БЖУ.\n'
                          'Именно эти значения используются в дневнике\n'
                          'для контроля прогресса каждый день.',
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
              _buildTextFormField(
                controller: _calorieGoalController,
                label: 'Калории (ккал)',
                icon: Symbols.local_fire_department,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по калориям'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _waterGoalController,
                label: 'Вода (мл)',
                icon: Symbols.water_drop,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по воде'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _stepsGoalController,
                label: 'Шаги',
                icon: Symbols.directions_walk,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по шагам'
                    : null,
              ),
              const Divider(height: 32),
              _buildTextFormField(
                controller: _proteinGoalController,
                label: 'Белки (г)',
                icon: Symbols.egg,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по белкам'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _carbsGoalController,
                label: 'Углеводы (г)',
                icon: Symbols.bakery_dining,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по углеводам'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _fatGoalController,
                label: 'Жиры (г)',
                icon: Symbols.oil_barrel,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? 'Введите цель по жирам'
                    : null,
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
