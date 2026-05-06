import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class CreateRecipeFromPhotoScreen extends StatefulWidget {
  const CreateRecipeFromPhotoScreen({super.key});

  @override
  State<CreateRecipeFromPhotoScreen> createState() =>
      _CreateRecipeFromPhotoScreenState();
}

class _CreateRecipeFromPhotoScreenState
    extends State<CreateRecipeFromPhotoScreen> {
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _geminiService = GeminiRecipeService();

  Uint8List? _imageBytes;
  String _imageMimeType = 'image/jpeg';
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

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1920,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _imageMimeType = _detectMimeType(image.name);
    });
  }

  String _detectMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Recipe _buildDraftRecipe(GeminiRecipeDraft draft) {
    return Recipe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      description: draft.description,
      nutrients: draft.nutrients,
      ingredients: draft.ingredients,
      icon: draft.icon,
      isUserRecipe: true,
      instructions: const [],
    );
  }

  Future<void> _generateAndOpenEditor() async {
    if (_imageBytes == null) {
      _showAiErrorSnackBar(l10n.recipeAddPhotoFirstError);
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await _geminiService.generateRecipeFromPhoto(
        imageBytes: _imageBytes!,
        imageMimeType: _imageMimeType,
        description: _descriptionController.text.trim(),
        locale: Localizations.localeOf(context).languageCode,
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EditRecipeScreen(
            initialDraft: _buildDraftRecipe(draft),
            initialClarification: _descriptionController.text.trim(),
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
      _showAiErrorSnackBar(l10n.recipeCreateFromPhotoFailure);
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
          l10n.recipeFromPhotoTitle,
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
            _buildPhotoCard(),
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

  Widget _buildPhotoCard() {
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
              l10n.recipePhotoCardTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: AppStyles.mediumBorderRadius,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageBytes == null
                    ? Center(
                        child: Text(l10n.recipePhotoEmptyState),
                      )
                    : Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Symbols.photo_camera),
                    label: Text(l10n.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Symbols.photo_library),
                    label: Text(l10n.gallery),
                  ),
                ),
              ],
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
            Row(
              children: [
                Text(
                  l10n.recipeDescriptionOptionalTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.optional,
                  style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
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
