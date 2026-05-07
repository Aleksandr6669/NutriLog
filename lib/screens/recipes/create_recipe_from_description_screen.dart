import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class CreateRecipeFromDescriptionScreen extends StatefulWidget {
  const CreateRecipeFromDescriptionScreen({super.key});

  @override
  State<CreateRecipeFromDescriptionScreen> createState() =>
      _CreateRecipeFromDescriptionScreenState();
}

class _CreateRecipeFromDescriptionScreenState
    extends State<CreateRecipeFromDescriptionScreen> {
  final _descriptionController = TextEditingController();
  final _geminiService = GeminiRecipeService();
  bool _isGenerating = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  void _showAiErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Recipe _buildDraftRecipe(GeminiRecipeDraft draft) {
    return Recipe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      description: draft.description,
      clarification: draft.clarification,
      nutrients: draft.nutrients,
      ingredients: draft.ingredients,
      icon: draft.icon,
      isUserRecipe: true,
      instructions: const [],
    );
  }

  String _buildDetailedClarification(
    GeminiRecipeDraft draft,
    String userDescription,
  ) {
    final userText = userDescription.trim();
    final parts = <String>[];
    if (draft.clarification.trim().isNotEmpty) {
      parts.add(draft.clarification.trim());
    }
    if (userText.isNotEmpty) {
      parts.add('Дополнение пользователя: $userText');
    }
    return parts.join('\n\n').trim();
  }

  Future<void> _generateAndOpenEditor() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showAiErrorSnackBar(l10n.recipeCreateFromDescriptionEmptyError);
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await _geminiService.generateRecipeFromDescription(
        description: description,
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EditRecipeScreen(
            initialDraft: _buildDraftRecipe(draft),
            initialClarification:
                _buildDetailedClarification(draft, description),
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on GeminiRecipeException catch (e) {
      if (!mounted) return;
      _showAiErrorSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showAiErrorSnackBar(l10n.recipeCreateFromDescriptionFailure);
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(
          l10n.recipeFromDescriptionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: glassBodyPadding(
          context,
          left: 16,
          top: 8,
          right: 16,
          bottom: 110,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionCard(),
            const SizedBox(height: 16),
            _buildDescriptionCard(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndOpenEditor,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.auto_awesome),
                label: Text(
                  _isGenerating
                      ? l10n.recipeGenerating
                      : l10n.recipeGenerateAndOpenEditor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recipeInstructionsTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(l10n.recipeInstructionsStep1),
            Text(l10n.recipeInstructionsStep2),
            Text(l10n.recipeInstructionsStep3),
            Text(l10n.recipeInstructionsStep4),
            const SizedBox(height: 8),
            Text(
              l10n.recipeAiWarning,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recipeDescriptionCardTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 6,
              maxLines: 10,
              decoration: AppStyles.underlineInputDecoration(
                label: l10n.recipeDescriptionExample,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
