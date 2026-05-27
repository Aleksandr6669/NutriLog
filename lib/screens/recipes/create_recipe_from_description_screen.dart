import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/models/user_profile.dart';
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
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isGenerating = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _preListeningText = '';

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'notListening' || status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _startListening() async {
    HapticFeedback.heavyImpact();
    if (!_speechEnabled) {
      // Re-init if failed before
      _initSpeech();
      return;
    }

    _preListeningText = _descriptionController.text.trim();
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          final newText = result.recognizedWords;
          if (newText.isNotEmpty) {
            _descriptionController.text = _preListeningText.isEmpty
                ? newText
                : '$_preListeningText $newText';
            // Move cursor to end
            _descriptionController.selection = TextSelection.fromPosition(
              TextPosition(offset: _descriptionController.text.length),
            );
          }
          if (result.finalResult) {
            _isListening = false;
          }
        });
      },
      localeId: Localizations.localeOf(context).toString(),
    );
  }

  void _stopListening() async {
    HapticFeedback.heavyImpact();
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

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
      id: 'recipe_${DateTime.now().microsecondsSinceEpoch}_${draft.name.hashCode}_${Random().nextInt(10000)}',
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
    final profile = context.read<ProfileProvider>().profile;
    if (profile == null || !profile.isAiFeatureAvailable) {
      context.push('/subscription', extra: SubscriptionTier.standard);
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showAiErrorSnackBar(l10n.recipeCreateFromDescriptionEmptyError);
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final profile = context.read<ProfileProvider>().profile;
      final draft = await _geminiService.generateRecipeFromDescription(
        description: description,
        locale: Localizations.localeOf(context).languageCode,
        healthConditions: profile?.healthConditions ?? '',
        aiContext: profile?.aiContext ?? '',
        profile: profile,
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
            Builder(builder: (context) {
              final profile = context.watch<ProfileProvider>().profile;
              final isAiAvailable = profile?.isAiFeatureAvailable ?? false;

              return Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: (_isGenerating ||
                                _isListening ||
                                _descriptionController.text.trim().isEmpty)
                            ? null
                            : _generateAndOpenEditor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (!isAiAvailable &&
                                  _descriptionController.text.trim().isNotEmpty)
                              ? Colors.grey.withValues(alpha: 0.08)
                              : AppColors.primary.withValues(alpha: 0.08),
                          foregroundColor: (!isAiAvailable &&
                                  _descriptionController.text.trim().isNotEmpty)
                              ? Colors.grey.shade600
                              : AppColors.primary,
                          elevation: 0,
                          side: BorderSide(
                            color: (!isAiAvailable &&
                                    _descriptionController.text
                                        .trim()
                                        .isNotEmpty)
                                ? Colors.grey.withValues(alpha: 0.25)
                                : AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(isAiAvailable
                                ? Symbols.auto_awesome
                                : Symbols.lock),
                        label: Text(
                          _isGenerating
                              ? l10n.recipeGenerating
                              : l10n.recipeGenerateAndOpenEditor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color:
                        _isListening ? Colors.red.shade500 : AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _isListening ? _stopListening : _startListening,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        child: Icon(
                          _isListening ? Symbols.stop : Symbols.mic,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
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
