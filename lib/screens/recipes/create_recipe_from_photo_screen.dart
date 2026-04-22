import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class CreateRecipeFromPhotoScreen extends StatefulWidget {
  const CreateRecipeFromPhotoScreen({super.key});

  @override
  State<CreateRecipeFromPhotoScreen> createState() =>
      _CreateRecipeFromPhotoScreenState();
}

class _CreateRecipeFromPhotoScreenState
    extends State<CreateRecipeFromPhotoScreen> {
  static const List<IconData> _iconOptions = [
    Symbols.restaurant,
    Symbols.lunch_dining,
    Symbols.local_bar,
    Symbols.cake,
    Symbols.fastfood,
    Symbols.breakfast_dining,
    Symbols.ramen_dining,
    Symbols.icecream,
    Symbols.local_pizza,
    Symbols.set_meal,
    Symbols.dinner_dining,
    Symbols.blender,
    Symbols.soup_kitchen,
    Symbols.coffee,
    Symbols.wine_bar,
    Symbols.bakery_dining,
    Symbols.egg,
    Symbols.cooking,
    Symbols.kebab_dining,
    Symbols.takeout_dining,
    Symbols.rice_bowl,
    Symbols.cookie,
    Symbols.donut_large,
    Symbols.nutrition,
  ];

  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _geminiService = GeminiRecipeService();

  Uint8List? _imageBytes;
  String _imageMimeType = 'image/jpeg';
  IconData _selectedIcon = Symbols.restaurant;
  bool _isGenerating = false;

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
      icon: _selectedIcon,
      isUserRecipe: true,
      instructions: const [],
    );
  }

  Future<void> _showIconPicker() async {
    final selected = await showModalBottomSheet<IconData>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выберите иконку блюда',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final icon = _iconOptions[index];
                  final isSelected = icon == _selectedIcon;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(icon),
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: isSelected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : Colors.grey.shade200,
                      child: Icon(
                        icon,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedIcon = selected);
  }

  Future<void> _generateAndOpenEditor() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте фото блюда.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await _geminiService.generateRecipeFromPhoto(
        imageBytes: _imageBytes!,
        imageMimeType: _imageMimeType,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              EditRecipeScreen(initialDraft: _buildDraftRecipe(draft)),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on GeminiRecipeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать рецепт по фото.')),
      );
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
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: const Text(
          'Рецепт по фото',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionCard(),
            const SizedBox(height: 16),
            _buildPhotoCard(),
            const SizedBox(height: 16),
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            _buildIconCard(),
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
                      ? 'Генерируем рецепт...'
                      : 'Сгенерировать и открыть редактор',
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
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Инструкция',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. Сделайте фото блюда или выберите из галереи.'),
            Text('2. При желании добавьте краткое описание.'),
            Text('3. Нажмите кнопку генерации.'),
            Text('4. Откроется экран редактирования с заполненными полями.'),
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
            const Text('Фото блюда',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    ? const Center(
                        child: Text('Фото пока не добавлено'),
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
                    label: const Text('Камера'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Symbols.photo_library),
                    label: const Text('Галерея'),
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
                const Text('Описание (необязательно)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('Опционально',
                    style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.8))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: AppStyles.underlineInputDecoration(
                label: 'Например: паста с курицей и сливочным соусом',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Иконка блюда',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _showIconPicker,
              icon: Icon(_selectedIcon),
              label: const Text('Выбрать'),
            ),
          ],
        ),
      ),
    );
  }
}
