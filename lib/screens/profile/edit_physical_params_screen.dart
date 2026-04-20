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
  State<EditPhysicalParamsScreen> createState() =>
      _EditPhysicalParamsScreenState();
}

class _EditPhysicalParamsScreenState extends State<EditPhysicalParamsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late Gender _gender;
  late DateTime _birthDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _gender = widget.profile.gender;
    _birthDate = widget.profile.birthDate;
    _heightController =
        TextEditingController(text: widget.profile.height.toString());
    _weightController =
        TextEditingController(text: widget.profile.weight.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        name: _nameController.text,
        gender: _gender,
        birthDate: _birthDate,
        height: int.parse(_heightController.text),
        weight: double.parse(_weightController.text),
      );

      await _profileService.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Физические параметры обновлены!',
                style: TextStyle(fontSize: 18)),
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
                          'Здесь указываются базовые физические параметры:\n'
                          'пол, возраст, рост и текущий вес.\n'
                          'Эти данные нужны для точного расчета\n'
                          'норм и персональных рекомендаций.',
                          style: theme.textTheme.bodyMedium?.copyWith(
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
                controller: _nameController,
                label: 'Имя',
                icon: Symbols.person,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите ваше имя' : null,
              ),
              const SizedBox(height: 24),
              _buildGenderSelector(theme),
              const SizedBox(height: 24),
              _buildBirthDatePicker(theme),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _heightController,
                label: 'Рост (см)',
                icon: Symbols.height,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите ваш рост' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _weightController,
                label: 'Текущий вес (кг)',
                icon: Symbols.weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))
                ],
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите ваш вес' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker(ThemeData theme) {
    final formatted =
        '${_birthDate.day.toString().padLeft(2, '0')}.${_birthDate.month.toString().padLeft(2, '0')}.${_birthDate.year}';
    final age = _calcAge(_birthDate);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
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
      },
      child: InputDecorator(
        decoration: AppStyles.inputDecoration('Дата рождения', Symbols.cake),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatted,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$age лет',
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
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
        Text('Пол',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.hintColor, fontWeight: FontWeight.bold)),
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

  Widget _genderOption(
      ThemeData theme, String text, IconData icon, Gender value) {
    final isSelected = _gender == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gender = value),
        borderRadius: AppStyles.buttonRadius,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.1)
                : (theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200),
            borderRadius: AppStyles.buttonRadius,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (theme.brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade400),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color:
                      isSelected ? AppColors.primary : theme.iconTheme.color),
              const SizedBox(width: 8),
              Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
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
}
