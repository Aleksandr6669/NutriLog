import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class EditPhysicalParamsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditPhysicalParamsScreen({super.key, required this.profile});

  @override
  State<EditPhysicalParamsScreen> createState() => _EditPhysicalParamsScreenState();
}

class _EditPhysicalParamsScreenState extends State<EditPhysicalParamsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late Gender _gender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _gender = widget.profile.gender;
    _ageController = TextEditingController(text: widget.profile.age.toString());
    _heightController = TextEditingController(text: widget.profile.height.toString());
    _weightController = TextEditingController(text: widget.profile.weight.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        name: _nameController.text,
        gender: _gender,
        age: int.parse(_ageController.text),
        height: int.parse(_heightController.text),
        weight: double.parse(_weightController.text),
      );

      await _profileService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Физические параметры обновлены!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Физические параметры'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextFormField(
                controller: _nameController,
                label: 'Имя',
                icon: Symbols.person,
                validator: (value) => value == null || value.isEmpty ? 'Введите ваше имя' : null,
              ),
              const SizedBox(height: 24),
              _buildGenderSelector(theme),
              const SizedBox(height: 24),
              _buildTextFormField(
                controller: _ageController,
                label: 'Возраст',
                icon: Symbols.cake,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty ? 'Введите ваш возраст' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _heightController,
                label: 'Рост (см)',
                icon: Symbols.height,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty ? 'Введите ваш рост' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _weightController,
                label: 'Текущий вес (кг)',
                icon: Symbols.weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))],
                validator: (value) => value == null || value.isEmpty ? 'Введите ваш вес' : null,
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

  Widget _buildGenderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Пол', style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _genderOption(theme, 'Мужской', Symbols.male, Gender.male),
            const SizedBox(width: 16),
            _genderOption(theme, 'Женский', Symbols.female, Gender.female),
          ],
        ),
      ],
    );
  }

  Widget _genderOption(ThemeData theme, String text, IconData icon, Gender value) {
    final isSelected = _gender == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gender = value),
        borderRadius: AppStyles.buttonRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : theme.cardColor,
            borderRadius: AppStyles.buttonRadius,
            border: Border.all(
              color: isSelected ? AppColors.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : theme.iconTheme.color),
              const SizedBox(width: 8),
              Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
