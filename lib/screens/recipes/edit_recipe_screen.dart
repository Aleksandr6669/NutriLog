import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe? recipe;

  const EditRecipeScreen({super.key, this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipeService = RecipeService();

  // Main info
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  IconData _selectedIcon = Symbols.restaurant;

  // Nutrient controllers
  final Map<String, TextEditingController> _nutrientControllers = {};

  final List<String> _nutrientKeys = [
    'calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'saturated_fat', 
    'polyunsaturated_fat', 'monounsaturated_fat', 'trans_fat', 'cholesterol', 
    'sodium', 'potassium', 'vitamin_a', 'vitamin_c', 'vitamin_d', 'calcium', 'iron'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.recipe?.name ?? '');
    _descriptionController = TextEditingController(text: widget.recipe?.description ?? '');
    _selectedIcon = widget.recipe?.icon ?? Symbols.restaurant;

    // Initialize all nutrient controllers
    for (var key in _nutrientKeys) {
      _nutrientControllers[key] = TextEditingController(
        text: widget.recipe?.nutrients[key]?.toString() ?? '0.0'
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var controller in _nutrientControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showIconPicker() {
    final icons = [
      Symbols.restaurant, Symbols.lunch_dining, Symbols.local_bar, 
      Symbols.cake, Symbols.fastfood, Symbols.breakfast_dining, 
      Symbols.ramen_dining, Symbols.icecream, Symbols.local_pizza, 
      Symbols.set_meal, Symbols.dinner_dining, Symbols.blender, 
      Symbols.soup_kitchen, Symbols.coffee, Symbols.wine_bar,
      Symbols.liquor, Symbols.bakery_dining, Symbols.egg,
      Symbols.egg_alt, Symbols.cooking, Symbols.kebab_dining,
      Symbols.takeout_dining, Symbols.rice_bowl,
      Symbols.cookie, Symbols.donut_large,
      Symbols.local_cafe, Symbols.local_drink, Symbols.tapas,
      Symbols.flatware, Symbols.outdoor_grill, Symbols.kitchen,
      Symbols.microwave, Symbols.skillet,
      Symbols.nutrition, Symbols.eco,
      Symbols.restaurant_menu
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canvasColor = theme.brightness == Brightness.dark ? AppColors.cardDark : AppColors.cardLight;
        final unselectedBg = theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100;
        final unselectedIcon = theme.brightness == Brightness.dark ? Colors.grey.shade300 : Colors.grey.shade700;
        return AlertDialog(
          backgroundColor: canvasColor,
          title: const Text('Выберите иконку', style: TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: icons.length,
              itemBuilder: (context, index) {
                final icon = icons[index];
                final isSelected = _selectedIcon == icon;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.16) : unselectedBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? AppColors.primary : unselectedIcon,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveRecipe() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, double> nutrients = {};
      for (var key in _nutrientKeys) {
        nutrients[key] = double.tryParse(_nutrientControllers[key]!.text) ?? 0.0;
      }

      final recipe = Recipe(
        id: widget.recipe?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isUserRecipe: true,
        // Ingredients and instructions are not in this design, so we save them as empty.
        ingredients: widget.recipe?.ingredients ?? [],
        instructions: widget.recipe?.instructions ?? [],
      );

      if (widget.recipe == null) {
        await _recipeService.addRecipe(recipe);
      } else {
        await _recipeService.updateRecipe(recipe);
      }

      if (mounted) {
        Navigator.pop(context, true);
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(widget.recipe == null ? 'Новый рецепт' : 'Редактировать рецепт', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save, weight: 600),
            onPressed: _saveRecipe,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              _buildMainInfoCard(),
              const SizedBox(height: 20),
              _buildNutrientsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      elevation: 0.5, shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Основная информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: _showIconPicker,
                borderRadius: BorderRadius.circular(50),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(_selectedIcon, size: 48, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: AppStyles.underlineInputDecoration(label: 'Название рецепта'),
              validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: AppStyles.underlineInputDecoration(label: 'Краткое описание'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard() {
    return Card(
      elevation: 0.5, shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пищевая ценность (на порцию)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _nutrientRow([ ('calories', 'Калории', 'ккал')]),
            const SizedBox(height: 8),
            _nutrientRow([('protein', 'Белки', 'г'), ('carbs', 'Углеводы', 'г'), ('fat', 'Жиры', 'г')]),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Дополнительно', style: TextStyle(fontWeight: FontWeight.w500)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _nutrientRow([('fiber', 'Клетчатка', 'г'), ('sugar', 'Сахар', 'г')]),
                const SizedBox(height: 8),
                 _nutrientRow([('saturated_fat', 'Насыщенные жиры', 'г')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('polyunsaturated_fat', 'Полиненасыщенные жиры', 'г')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('monounsaturated_fat', 'Мононенасыщенные жиры', 'г')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('trans_fat', 'Трансжиры', 'г')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('cholesterol', 'Холестерин', 'мг'), ('sodium', 'Натрий', 'мг')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('potassium', 'Калий', 'мг')]),
                 const SizedBox(height: 24),
                 const Text('Витамины и минералы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 _nutrientRow([('vitamin_a', 'Витамин A', 'мкг'), ('vitamin_c', 'Витамин C', 'мг'), ('vitamin_d', 'Витамин D', 'мкг')]),
                 const SizedBox(height: 8),
                 _nutrientRow([('calcium', 'Кальций', 'мг'), ('iron', 'Железо', 'мг')]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(List<(String, String, String)> fields) {
    return Row(
      children: fields.map((field) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _nutrientTextFormField(_nutrientControllers[field.$1]!, field.$2, field.$3),
          ),
        );
      }).toList(),
    );
  }

  Widget _nutrientTextFormField(TextEditingController controller, String label, String suffix) {
    return TextFormField(
      controller: controller,
      decoration: AppStyles.underlineInputDecoration(label: label, suffix: suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      validator: (value) {
        if (double.tryParse(value ?? '') == null) return 'Число';
        return null;
      },
    );
  }
}
