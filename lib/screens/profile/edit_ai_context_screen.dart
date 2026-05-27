import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class EditAiContextScreen extends StatefulWidget {
  final UserProfile profile;

  const EditAiContextScreen({super.key, required this.profile});

  @override
  State<EditAiContextScreen> createState() => _EditAiContextScreenState();
}

class _EditAiContextScreenState extends State<EditAiContextScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aiContextController;

  @override
  void initState() {
    super.initState();
    _aiContextController = TextEditingController(
      text: widget.profile.aiContext,
    );
  }

  @override
  void dispose() {
    _aiContextController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = widget.profile.copyWith(
        aiContext: _aiContextController.text.trim(),
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
        title: Text(l10n.additionalForAi),
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
                        Symbols.auto_awesome,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.additionalForAiHint,
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
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: AppStyles.cardRadius,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Symbols.psychology,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.additionalForAi,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _aiContextController,
                        maxLines: 8,
                        minLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Примеры предпочтений: "Не ем рыбу", "Интервальное голодание с 12:00 до 20:00", "Тренируюсь утром натощак", "Сладкоежка, добавь полезные перекусы".',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w500),
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
