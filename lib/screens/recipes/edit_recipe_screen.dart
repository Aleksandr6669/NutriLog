import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import '../../widgets/icon_picker_dialog.dart'; 

class EditRecipeScreen extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeScreen({super.key, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers for all fields
  late TextEditingController _nameController, _descriptionController, _caloriesController, 
      _proteinController, _carbsController, _sugarController, _fiberController, 
      _fatController, _saturatedFatController, _polyunsaturatedFatController, 
      _monounsaturatedFatController, _transFatController, _cholesterolController, 
      _sodiumController, _potassiumController, _vitaminAController, _vitaminCController, 
      _vitaminDController, _calciumController, _ironController;

  late IconData _selectedIcon;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _nameController = TextEditingController(text: r.name);
    _descriptionController = TextEditingController(text: r.description);
    _selectedIcon = r.icon;

    final n = r.nutrients;
    _caloriesController = TextEditingController(text: n.calories.toString());
    _proteinController = TextEditingController(text: n.protein.toString());
    _carbsController = TextEditingController(text: n.carbs.toString());
    _sugarController = TextEditingController(text: n.sugar.toString());
    _fiberController = TextEditingController(text: n.fiber.toString());
    _fatController = TextEditingController(text: n.fat.toString());
    _saturatedFatController = TextEditingController(text: n.saturatedFat.toString());
    _polyunsaturatedFatController = TextEditingController(text: n.polyunsaturatedFat.toString());
    _monounsaturatedFatController = TextEditingController(text: n.monounsaturatedFat.toString());
    _transFatController = TextEditingController(text: n.transFat.toString());
    _cholesterolController = TextEditingController(text: n.cholesterol.toString());
    _sodiumController = TextEditingController(text: n.sodium.toString());
    _potassiumController = TextEditingController(text: n.potassium.toString());
    _vitaminAController = TextEditingController(text: n.vitaminA.toString());
    _vitaminCController = TextEditingController(text: n.vitaminC.toString());
    _vitaminDController = TextEditingController(text: n.vitaminD.toString());
    _calciumController = TextEditingController(text: n.calcium.toString());
    _ironController = TextEditingController(text: n.iron.toString());
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose(); _descriptionController.dispose(); _caloriesController.dispose(); 
    _proteinController.dispose(); _carbsController.dispose(); _sugarController.dispose(); 
    _fiberController.dispose(); _fatController.dispose(); _saturatedFatController.dispose();
    _polyunsaturatedFatController.dispose(); _monounsaturatedFatController.dispose();
    _transFatController.dispose(); _cholesterolController.dispose(); _sodiumController.dispose(); 
    _potassiumController.dispose(); _vitaminAController.dispose(); _vitaminCController.dispose();
    _vitaminDController.dispose(); _calciumController.dispose(); _ironController.dispose();
    super.dispose();
  }

  double _parseDouble(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      final updatedNutrients = NutritionalInfo(
        calories: _parseDouble(_caloriesController.text),
        protein: _parseDouble(_proteinController.text),
        carbs: _parseDouble(_carbsController.text),
        sugar: _parseDouble(_sugarController.text),
        fiber: _parseDouble(_fiberController.text),
        fat: _parseDouble(_fatController.text),
        saturatedFat: _parseDouble(_saturatedFatController.text),
        polyunsaturatedFat: _parseDouble(_polyunsaturatedFatController.text),
        monounsaturatedFat: _parseDouble(_monounsaturatedFatController.text),
        transFat: _parseDouble(_transFatController.text),
        cholesterol: _parseDouble(_cholesterolController.text),
        sodium: _parseDouble(_sodiumController.text),
        potassium: _parseDouble(_potassiumController.text),
        vitaminA: _parseDouble(_vitaminAController.text),
        vitaminC: _parseDouble(_vitaminCController.text),
        vitaminD: _parseDouble(_vitaminDController.text),
        calcium: _parseDouble(_calciumController.text),
        iron: _parseDouble(_ironController.text),
      );

      final updatedRecipe = Recipe(
        name: _nameController.text,
        description: _descriptionController.text,
        icon: _selectedIcon,
        nutrients: updatedNutrients,
      );

      Navigator.of(context).pop(updatedRecipe);
    }
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => IconPickerDialog(
        onIconSelected: (icon) {
          setState(() => _selectedIcon = icon);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменить рецепт'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _saveChanges,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: _buildIconSelector(),
              ),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Название'),
              const SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Описание', maxLines: 3),
              const SizedBox(height: 24),

              _buildNutritionCard(
                title: 'Основное',
                children: [
                  _buildTextField(_caloriesController, 'Калории (ккал)', isNumeric: true),
                ]
              ),
              
              _buildNutritionCard(
                title: 'Макронутриенты',
                children: [
                  _buildTextField(_proteinController, 'Белки (г)', isNumeric: true),
                  _buildTextField(_carbsController, 'Углеводы (г)', isNumeric: true, topPadding: 16),
                  _buildTextField(_sugarController, '   в т.ч. Сахар (г)', isSub: true, isNumeric: true, topPadding: 8),
                  _buildTextField(_fiberController, '   в т.ч. Клетчатка (г)', isSub: true, isNumeric: true, topPadding: 8),
                  _buildTextField(_fatController, 'Жиры (г)', isNumeric: true, topPadding: 16),
                  _buildTextField(_saturatedFatController, '   Насыщенные (г)', isSub: true, isNumeric: true, topPadding: 8),
                  _buildTextField(_polyunsaturatedFatController, '   Полиненасыщенные (г)', isSub: true, isNumeric: true, topPadding: 8),
                  _buildTextField(_monounsaturatedFatController, '   Мононенасыщенные (г)', isSub: true, isNumeric: true, topPadding: 8),
                  _buildTextField(_transFatController, '   Трансжиры (г)', isSub: true, isNumeric: true, topPadding: 8),
                ]
              ),

               _buildNutritionCard(
                title: 'Минералы',
                children: [
                   _buildTextField(_cholesterolController, 'Холестерин (мг)', isNumeric: true),
                   _buildTextField(_sodiumController, 'Натрий (мг)', isNumeric: true, topPadding: 16),
                   _buildTextField(_potassiumController, 'Калий (мг)', isNumeric: true, topPadding: 16),
                ]
              ),

              _buildNutritionCard(
                title: 'Витамины и Минералы',
                children: [
                  _buildTextField(_vitaminAController, 'Витамин A (мкг)', isNumeric: true),
                  _buildTextField(_vitaminCController, 'Витамин C (мг)', isNumeric: true, topPadding: 16),
                  _buildTextField(_vitaminDController, 'Витамин D (мкг)', isNumeric: true, topPadding: 16),
                  _buildTextField(_calciumController, 'Кальций (мг)', isNumeric: true, topPadding: 16),
                  _buildTextField(_ironController, 'Железо (мг)', isNumeric: true, topPadding: 16),
                ]
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildIconSelector() {
    return Column(
      children: [
         Text('Иконка рецепта', style: Theme.of(context).textTheme.titleSmall),
         const SizedBox(height: 12),
         InkWell(
           onTap: _showIconPicker,
           borderRadius: BorderRadius.circular(50),
           child: Container(
             width: 80, height: 80,
             decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.primary.withAlpha(26), // 10% opacity
               shape: BoxShape.circle
             ),
             child: Icon(_selectedIcon, size: 40, color: Theme.of(context).colorScheme.primary),
           ),
         )
      ],
    );
  }

  Widget _buildNutritionCard({required String title, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, bool isNumeric = false, bool isSub = false, double topPadding = 0}) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, left: isSub ? 16.0 : 0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
          filled: false,
        ),
        maxLines: maxLines,
        keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        validator: (value) {
          if ((label == 'Название' || label == 'Калории (ккал)') && (value == null || value.isEmpty)) {
             return 'Это поле не может быть пустым';
          }
          if (value != null && value.isNotEmpty && isNumeric && double.tryParse(value.replaceAll(',', '.')) == null) {
            return 'Введите корректное число';
          }
          return null;
        },
      ),
    );
  }
}
