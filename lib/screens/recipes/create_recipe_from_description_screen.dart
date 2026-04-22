import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/screens/recipes/edit_recipe_screen.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/styles/app_styles.dart';

class CreateRecipeFromDescriptionScreen extends StatefulWidget {
  const CreateRecipeFromDescriptionScreen({super.key});

  @override
  State<CreateRecipeFromDescriptionScreen> createState() =>
      _CreateRecipeFromDescriptionScreenState();
}

class _CreateRecipeFromDescriptionScreenState
    extends State<CreateRecipeFromDescriptionScreen> {
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
  final _geminiService = GeminiRecipeService();
  IconData _selectedIcon = Symbols.restaurant;
  bool _isGenerating = false;

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
                          ? Colors.green.withValues(alpha: 0.18)
                          : Colors.grey.shade200,
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.green : Colors.grey.shade700,
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
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите описание блюда.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final draft = await _geminiService.generateRecipeFromDescription(
        description: description,
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
        const SnackBar(content: Text('Не удалось создать рецепт по описанию.')),
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
          'Рецепт по описанию',
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
            Text('1. Подробно опишите блюдо и ингредиенты.'),
            Text('2. Нажмите кнопку генерации рецепта.'),
            Text('3. Откроется экран редактирования с заполненными полями.'),
            Text('4. Проверьте и при необходимости исправьте детали.'),
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
            const Text(
              'Описание блюда',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 6,
              maxLines: 10,
              decoration: AppStyles.underlineInputDecoration(
                label:
                    'Например: Куриная паста в сливочном соусе с чесноком и пармезаном. На 2 порции.',
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
