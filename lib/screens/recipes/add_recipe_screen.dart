import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/recipe.dart';
import '../../models/food_item.dart';
import '../../widgets/icon_picker_dialog.dart';

class AddRecipeScreen extends StatefulWidget {
  // Добавляем опциональный параметр для редактирования
  final Recipe? recipeToEdit;

  const AddRecipeScreen({super.key, this.recipeToEdit});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isEditing;

  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  IconData _selectedIcon = IconPickerDialog.icons.first;

  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _saturatedFatController = TextEditingController();
  final _polyunsaturatedFatController = TextEditingController();
  final _monounsaturatedFatController = TextEditingController();
  final _transFatController = TextEditingController();
  final _cholesterolController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _potassiumController = TextEditingController();
  final _vitaminAController = TextEditingController();
  final _vitaminCController = TextEditingController();
  final _vitaminDController = TextEditingController();
  final _calciumController = TextEditingController();
  final _ironController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.recipeToEdit != null;

    if (_isEditing) {
      // Если редактируем, заполняем поля
      final recipe = widget.recipeToEdit!;
      _nameController.text = recipe.name;
      _descriptionController.text = recipe.description;
      _selectedIcon = recipe.icon;

      final nutrients = recipe.nutrients;
      _caloriesController.text = nutrients.calories.toString();
      _proteinController.text = nutrients.protein.toString();
      _carbsController.text = nutrients.carbs.toString();
      _fatController.text = nutrients.fat.toString();
      _fiberController.text = nutrients.fiber.toString() ?? '';
      _sugarController.text = nutrients.sugar.toString() ?? '';
      _saturatedFatController.text = nutrients.saturatedFat.toString() ?? '';
      _polyunsaturatedFatController.text = nutrients.polyunsaturatedFat.toString() ?? '';
      _monounsaturatedFatController.text = nutrients.monounsaturatedFat.toString() ?? '';
      _transFatController.text = nutrients.transFat.toString() ?? '';
      _cholesterolController.text = nutrients.cholesterol.toString() ?? '';
      _sodiumController.text = nutrients.sodium.toString() ?? '';
      _potassiumController.text = nutrients.potassium.toString() ?? '';
      _vitaminAController.text = nutrients.vitaminA.toString() ?? '';
      _vitaminCController.text = nutrients.vitaminC.toString() ?? '';
      _vitaminDController.text = nutrients.vitaminD.toString() ?? '';
      _calciumController.text = nutrients.calcium.toString() ?? '';
      _ironController.text = nutrients.iron.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    // ... dispose all other controllers
    super.dispose();
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => IconPickerDialog(
        onIconSelected: (icon) => setState(() => _selectedIcon = icon),
      ),
    );
  }

  // Helper to safely parse text to double
  double _parseDouble(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
  int _parseInt(String text) => int.tryParse(text.replaceAll(',', '.')) ?? 0;

  void _saveRecipe() {
    if (_formKey.currentState!.validate()) {
      final resultingRecipe = Recipe(
        name: _nameController.text,
        description: _descriptionController.text,
        icon: _selectedIcon,
        nutrients: NutritionalInfo(
          calories: _parseInt(_caloriesController.text),
          protein: _parseDouble(_proteinController.text),
          carbs: _parseDouble(_carbsController.text),
          fat: _parseDouble(_fatController.text),
          fiber: _parseDouble(_fiberController.text),
          sugar: _parseDouble(_sugarController.text),
          saturatedFat: _parseDouble(_saturatedFatController.text),
          polyunsaturatedFat: _parseDouble(_polyunsaturatedFatController.text),
          monounsaturatedFat: _parseDouble(_monounsaturatedFatController.text),
          transFat: _parseDouble(_transFatController.text),
          cholesterol: _parseDouble(_cholesterolController.text),
          sodium: _parseDouble(_sodiumController.text),
          potassium: _parseDouble(_potassiumController.text),
          vitaminA: _parseInt(_vitaminAController.text),
          vitaminC: _parseInt(_vitaminCController.text),
          vitaminD: _parseInt(_vitaminDController.text),
          calcium: _parseInt(_calciumController.text),
          iron: _parseInt(_ironController.text),
        ),
      );
      Navigator.of(context).pop(resultingRecipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактировать рецепт' : 'Новый рецепт'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _saveRecipe,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGeneralInfoCard(),
              const SizedBox(height: 24),
              _buildNutritionalInfoCard(),
            ],
          ),
        ),
      ),
    );
  }
  
    Widget _buildGeneralInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Основная информация', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Center(
              child: InkWell(
                onTap: _showIconPicker,
                borderRadius: BorderRadius.circular(50),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(_selectedIcon, size: 40, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название рецепта'),
              validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Краткое описание'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Пищевая ценность (на порцию)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildNutrientField(_caloriesController, 'Калории', 'ккал', isRequired: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildNutrientField(_proteinController, 'Белки', 'г')),
                const SizedBox(width: 12),
                Expanded(child: _buildNutrientField(_carbsController, 'Углеводы', 'г')),
                const SizedBox(width: 12),
                Expanded(child: _buildNutrientField(_fatController, 'Жиры', 'г')),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Дополнительно'),
              tilePadding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNutrientField(_fiberController, 'Клетчатка', 'г')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNutrientField(_sugarController, 'Сахар', 'г')),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNutrientField(_saturatedFatController, 'Насыщенные жиры', 'г'),
                const SizedBox(height: 12),
                 _buildNutrientField(_polyunsaturatedFatController, 'Полиненасыщенные жиры', 'г'),
                const SizedBox(height: 12),
                 _buildNutrientField(_monounsaturatedFatController, 'Мононенасыщенные жиры', 'г'),
                const SizedBox(height: 12),
                _buildNutrientField(_transFatController, 'Трансжиры', 'г'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNutrientField(_cholesterolController, 'Холестерин', 'мг')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNutrientField(_sodiumController, 'Натрий', 'мг')),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNutrientField(_potassiumController, 'Калий', 'мг'),
                const SizedBox(height: 12),
                Text('Витамины (% от суточной нормы)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNutrientField(_vitaminAController, 'Витамин A', '%')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNutrientField(_vitaminCController, 'Витамин C', '%')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNutrientField(_vitaminDController, 'Витамин D', '%')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildNutrientField(_calciumController, 'Кальций', '%')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNutrientField(_ironController, 'Железо', '%')),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientField(TextEditingController controller, String label, String suffix, {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isRequired ? 'Обязательное поле' : null;
        }
        if (num.tryParse(value.replaceAll(',', '.')) == null) {
          return 'Неверный формат';
        }
        return null;
      },
    );
  }
}
