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
import 'package:nutri_log/services/firebase_auth_service.dart';

class EditPhysicalParamsScreen extends StatefulWidget {
  final UserProfile profile;

  const EditPhysicalParamsScreen({super.key, required this.profile});

  @override
  State<EditPhysicalParamsScreen> createState() =>
      _EditPhysicalParamsScreenState();
}

class _EditPhysicalParamsScreenState extends State<EditPhysicalParamsScreen> {
  final _formKey = GlobalKey<FormState>();

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
        TextEditingController(text: widget.profile.height == 0 ? '' : widget.profile.height.toString());
    _weightController =
        TextEditingController(text: widget.profile.weight == 0 ? '' : widget.profile.weight.toString());
  }

  Widget _buildNameField(BuildContext context, AppLocalizations l10n) {
    final isAuthorized = FirebaseAuthService.instance.isSignedIn;
    return TextFormField(
      controller: _nameController,
      readOnly: isAuthorized,
      validator: (value) =>
          value == null || value.isEmpty ? l10n.enterYourName : null,
      decoration: AppStyles.inputDecoration(l10n.name, Symbols.person).copyWith(
        suffixIcon: isAuthorized ? const Icon(Symbols.lock, size: 20) : null,
      ),
      style: const TextStyle(fontWeight: FontWeight.w500),
    );
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
        height: int.tryParse(_heightController.text) ?? 0,
        weight: double.tryParse(_weightController.text) ?? 0,
      );
      await context.read<ProfileProvider>().updateProfile(updatedProfile);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(l10n.physicalParams),
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
                          l10n.physicalParamsInfoText,
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
              _buildNameField(context, l10n),
              const SizedBox(height: 16),
              _buildGenderSelector(theme),
              const SizedBox(height: 16),
              _buildBirthDatePicker(theme),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) => value == null || value.isEmpty
                    ? l10n.enterYourHeight
                    : null,
                decoration:
                    AppStyles.inputDecoration(l10n.heightCm, Symbols.height),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))
                ],
                validator: (value) => value == null || value.isEmpty
                    ? l10n.enterYourWeight
                    : null,
                decoration: AppStyles.inputDecoration(
                    l10n.currentWeightKg, Symbols.weight),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final formatted =
        '${_birthDate.day.toString().padLeft(2, '0')}.${_birthDate.month.toString().padLeft(2, '0')}.${_birthDate.year}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthDate,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          locale: Localizations.localeOf(context),
        );
        if (picked != null) {
          setState(() => _birthDate = picked);
        }
      },
      borderRadius: AppStyles.defaultBorderRadius,
      child: InputDecorator(
        decoration:
            AppStyles.inputDecoration(l10n.birthDate, Symbols.calendar_today),
        child: Text(
          formatted,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
      ),
    );
  }



  Widget _buildGenderSelector(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Symbols.person_search, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              l10n.gender,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _genderOption(theme, l10n.male, Symbols.male, Gender.male),
            const SizedBox(width: 16),
            _genderOption(theme, l10n.female, Symbols.female, Gender.female),
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
        borderRadius: AppStyles.cardRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: AppStyles.cardRadius,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primary : Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
