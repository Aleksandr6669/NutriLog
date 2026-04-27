import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/recipe.dart';
import 'package:nutri_log/services/gemini_recipe_service.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class EditRecipeScreen extends StatefulWidget {
  final Recipe? recipe;
  final Recipe? initialDraft;

  const EditRecipeScreen({super.key, this.recipe, this.initialDraft});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  static const List<String> unitOptions = [
    'г', // граммы
    'мг', // миллиграммы
    'кг', // килограммы
    'шт', // штуки
    'пачка', // пачка
    'упак', // упаковка
    'л', // литры
    'мл', // миллилитры
    'ч.л.', // чайная ложка
    'ст.л.', // столовая ложка
    'стакан', // стакан
  ];

  final _formKey = GlobalKey<FormState>();
  final _recipeService = RecipeService();
  final _geminiRecipeService = GeminiRecipeService();

  // Main info
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  IconData _selectedIcon = Symbols.restaurant;

  // Nutrient controllers
  final Map<String, TextEditingController> _nutrientControllers = {};
  final List<_IngredientFormItem> _ingredientItems = [];
  bool _autoCalculateCalories = true;
  bool _isSyncingCalories = false;
  bool _isAiCalculating = false;
  String? _aiStatus;
  bool _isAiError = false;
  int _aiRequestId = 0;

  final List<String> _nutrientKeys = [
    'calories',
    'protein',
    'carbs',
    'fat',
    'fiber',
    'sugar',
    'saturated_fat',
    'polyunsaturated_fat',
    'monounsaturated_fat',
    'trans_fat',
    'cholesterol',
    'sodium',
    'potassium',
    'vitamin_a',
    'vitamin_c',
    'vitamin_d',
    'calcium',
    'iron'
  ];

  @override
  void initState() {
    super.initState();
    final sourceRecipe = widget.recipe ?? widget.initialDraft;

    _nameController = TextEditingController(text: sourceRecipe?.name ?? '');
    _descriptionController =
        TextEditingController(text: sourceRecipe?.description ?? '');
    _selectedIcon = sourceRecipe?.icon ?? Symbols.restaurant;

    // Initialize all nutrient controllers
    for (var key in _nutrientKeys) {
      _nutrientControllers[key] = TextEditingController(
          text: sourceRecipe?.nutrients[key]?.toString() ?? '0.0');
    }

    final loadedIngredients = sourceRecipe?.ingredients ?? const [];
    if (loadedIngredients.isNotEmpty) {
      for (final ingredient in loadedIngredients) {
        _ingredientItems.add(
          _IngredientFormItem(
            name: ingredient.name,
            quantity:
                ingredient.quantity <= 0 ? '' : ingredient.quantity.toString(),
            unit: ingredient.unit,
          ),
        );
      }
    }

    _autoCalculateCalories = _shouldEnableAutoCalories();
    _nutrientControllers['protein']?.addListener(_onMacroChanged);
    _nutrientControllers['carbs']?.addListener(_onMacroChanged);
    _nutrientControllers['fat']?.addListener(_onMacroChanged);

    if (_autoCalculateCalories) {
      _applyAutoCalories();
    }
  }

  bool _shouldEnableAutoCalories() {
    final sourceRecipe = widget.recipe ?? widget.initialDraft;
    if (sourceRecipe == null) return true;

    final recipeNutrients = sourceRecipe.nutrients;
    final protein = recipeNutrients['protein'] ?? 0;
    final carbs = recipeNutrients['carbs'] ?? 0;
    final fat = recipeNutrients['fat'] ?? 0;
    final calories = recipeNutrients['calories'] ?? 0;
    final calculated = protein * 4 + carbs * 4 + fat * 9;
    return (calories - calculated).abs() < 0.2;
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  String _formatNumber(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded.truncateToDouble() == rounded) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  void _onMacroChanged() {
    if (!_autoCalculateCalories || _isSyncingCalories) return;
    _applyAutoCalories();
  }

  void _applyAutoCalories() {
    final protein = _parseAmount(_nutrientControllers['protein']?.text ?? '0');
    final carbs = _parseAmount(_nutrientControllers['carbs']?.text ?? '0');
    final fat = _parseAmount(_nutrientControllers['fat']?.text ?? '0');
    final calories = protein * 4 + carbs * 4 + fat * 9;

    _isSyncingCalories = true;
    _nutrientControllers['calories']?.text = _formatNumber(calories);
    _isSyncingCalories = false;
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientItems.add(_IngredientFormItem());
    });
  }

  void _removeIngredientRow(int index) {
    final item = _ingredientItems.removeAt(index);
    item.dispose();
    setState(() {});
  }

  Future<void> _recalculateNutrientsWithAi() async {
    final ingredients = _ingredientItems
        .map(
          (item) => RecipeIngredient(
            name: item.nameController.text.trim(),
            quantity: _parseAmount(item.quantityController.text),
            unit: item.unit.trim(),
          ),
        )
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) {
      if (mounted) {
        setState(() {
          _aiStatus = 'Добавьте ингредиенты для AI-подсчета';
          _isAiError = true;
          _isAiCalculating = false;
        });
      }
      return;
    }

    final requestId = ++_aiRequestId;
    if (mounted) {
      setState(() {
        _isAiCalculating = true;
        _aiStatus = 'Идет расчет пищевой ценности...';
        _isAiError = false;
      });
    }

    try {
      final nutrients = await _geminiRecipeService.estimateNutrients(
        recipeName: _nameController.text,
        recipeDescription: _descriptionController.text,
        ingredients: ingredients,
      );

      if (!mounted || requestId != _aiRequestId) return;

      _isSyncingCalories = true;
      for (final key in _nutrientKeys) {
        _nutrientControllers[key]?.text = _formatNumber(nutrients[key] ?? 0);
      }
      _isSyncingCalories = false;

      setState(() {
        _isAiCalculating = false;
        _aiStatus = 'Поля обновлены';
        _isAiError = false;
      });
    } on GeminiRecipeException catch (e) {
      if (!mounted || requestId != _aiRequestId) return;
      setState(() {
        _isAiCalculating = false;
        _aiStatus = e.message;
        _isAiError = true;
      });
    } catch (_) {
      if (!mounted || requestId != _aiRequestId) return;
      setState(() {
        _isAiCalculating = false;
        _aiStatus = 'Не удалось получить расчет';
        _isAiError = true;
      });
    }
  }

  @override
  void dispose() {
    _nutrientControllers['protein']?.removeListener(_onMacroChanged);
    _nutrientControllers['carbs']?.removeListener(_onMacroChanged);
    _nutrientControllers['fat']?.removeListener(_onMacroChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    for (var controller in _nutrientControllers.values) {
      controller.dispose();
    }
    for (final ingredientItem in _ingredientItems) {
      ingredientItem.dispose();
    }
    super.dispose();
  }

  void _showIconPicker() {
    final icons = [
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
      Symbols.liquor,
      Symbols.bakery_dining,
      Symbols.egg,
      Symbols.egg_alt,
      Symbols.cooking,
      Symbols.kebab_dining,
      Symbols.takeout_dining,
      Symbols.rice_bowl,
      Symbols.cookie,
      Symbols.donut_large,
      Symbols.local_cafe,
      Symbols.local_drink,
      Symbols.tapas,
      Symbols.flatware,
      Symbols.outdoor_grill,
      Symbols.kitchen,
      Symbols.microwave,
      Symbols.skillet,
      Symbols.nutrition,
      Symbols.eco,
      Symbols.restaurant_menu
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canvasColor = theme.brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight;
        final unselectedBg = theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100;
        final unselectedIcon = theme.brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade700;
        return AlertDialog(
          backgroundColor: canvasColor,
          title: const Text('Выберите иконку',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : unselectedBg,
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
        nutrients[key] = _parseAmount(_nutrientControllers[key]!.text);
      }

      final ingredients = _ingredientItems
          .map(
            (item) => RecipeIngredient(
              name: item.nameController.text.trim(),
              quantity: _parseAmount(item.quantityController.text),
              unit: item.unit.trim(),
            ),
          )
          .where((ingredient) => ingredient.name.isNotEmpty)
          .toList();

      final recipe = Recipe(
        id: widget.recipe?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        nutrients: nutrients,
        icon: _selectedIcon,
        isUserRecipe: true,
        ingredients: ingredients,
        instructions:
            (widget.recipe ?? widget.initialDraft)?.instructions ?? [],
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

  Future<void> _deleteRecipe() async {
    if (widget.recipe == null) return;
    await _recipeService.deleteRecipe(widget.recipe!.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        title: Text(
            widget.recipe == null ? 'Новый рецепт' : 'Редактировать рецепт',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
          padding: glassBodyPadding(
            context,
            left: 16,
            top: 8,
            right: 16,
            bottom: 8,
          ),
          child: Column(
            children: [
              _buildMainInfoCard(),
              const SizedBox(height: 20),
              _buildIngredientsCard(),
              const SizedBox(height: 20),
              _buildNutrientsCard(),
              if (widget.recipe != null) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _deleteRecipe,
                    icon: const Icon(Symbols.delete),
                    label: const Text('Удалить рецепт'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Основная информация',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: _showIconPicker,
                borderRadius: BorderRadius.circular(50),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child:
                      Icon(_selectedIcon, size: 48, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration:
                  AppStyles.underlineInputDecoration(label: 'Название рецепта'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration:
                  AppStyles.underlineInputDecoration(label: 'Краткое описание'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Пищевая ценность (на порцию)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_aiStatus != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (_isAiError ? Colors.red : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_isAiError ? Colors.red : AppColors.primary)
                        .withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAiError ? Symbols.error : Symbols.info,
                      size: 18,
                      color:
                          _isAiError ? Colors.red.shade700 : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _aiStatus!,
                        style: TextStyle(
                          color: _isAiError
                              ? Colors.red.shade700
                              : Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isAiCalculating ? null : _recalculateNutrientsWithAi,
                icon: const Icon(Symbols.calculate),
                label: const Text('Рассчитать пищевую ценность'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Нейросеть может ошибаться примерно на 10%. Проверьте значения перед сохранением.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _nutrientRow([('calories', 'Калории', 'ккал')],
                      isReadOnly: _autoCalculateCalories),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Авто БЖУ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: _autoCalculateCalories,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (value) {
                        setState(() => _autoCalculateCalories = value);
                        if (value) _applyAutoCalories();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('БЖУ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('protein', 'Белки', 'г'),
              ('carbs', 'Углеводы', 'г'),
              ('fat', 'Жиры', 'г')
            ]),
            const SizedBox(height: 14),
            const Text('Детализация',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('sugar', 'в т.ч. Сахар', 'г'),
              ('fiber', 'в т.ч. Клетчатка', 'г')
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('saturated_fat', 'Насыщенные', 'г'),
              ('polyunsaturated_fat', 'Полиненасыщенные', 'г')
            ]),
            const SizedBox(height: 8),
            _nutrientRow([
              ('monounsaturated_fat', 'Мононенасыщенные', 'г'),
              ('trans_fat', 'Трансжиры', 'г')
            ]),
            const SizedBox(height: 8),
            _nutrientRow([('cholesterol', 'Холестерин', 'мг')]),
            const SizedBox(height: 14),
            const Text('Минералы',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow(
                [('sodium', 'Натрий', 'мг'), ('potassium', 'Калий', 'мг')]),
            const SizedBox(height: 8),
            _nutrientRow(
                [('calcium', 'Кальций', 'мг'), ('iron', 'Железо', 'мг')]),
            const SizedBox(height: 14),
            const Text('Витамины',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _nutrientRow([
              ('vitamin_a', 'Витамин A', 'мкг'),
              ('vitamin_c', 'Витамин C', 'мг'),
              ('vitamin_d', 'Витамин D', 'мкг')
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Состав',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Добавить ингредиент',
                  onPressed: _addIngredientRow,
                  icon: const Icon(Symbols.add_circle),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_ingredientItems.length, (index) {
              final item = _ingredientItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: item.nameController,
                        style: const TextStyle(fontSize: 13),
                        decoration: AppStyles.underlineInputDecoration(
                            label: 'Ингредиент'),
                        minLines: 1,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.quantityController,
                        style: const TextStyle(fontSize: 13),
                        decoration:
                            AppStyles.underlineInputDecoration(label: 'Кол-во'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[\.,]?\d*'))
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            item.unit.isEmpty ? unitOptions.first : item.unit,
                        items: unitOptions
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => item.unit = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Ед.',
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Удалить',
                      onPressed: () => _removeIngredientRow(index),
                      icon: const Icon(
                        Symbols.remove_circle,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Text(
              'Примеры: Морковь 120 г, Яйца 2 шт, Масло 1 ст.л.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutrientRow(List<(String, String, String)> fields,
      {bool isReadOnly = false}) {
    return Row(
      children: fields.map((field) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _nutrientTextFormField(
              _nutrientControllers[field.$1]!,
              field.$2,
              field.$3,
              readOnly: isReadOnly && field.$1 == 'calories',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _nutrientTextFormField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration:
          AppStyles.underlineInputDecoration(label: label, suffix: suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d*'))
      ],
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Число';
        return null;
      },
    );
  }
}

class _IngredientFormItem {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  String unit;

  _IngredientFormItem({
    String name = '',
    String quantity = '',
    String unit = '',
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity),
        unit = unit.isEmpty ? 'г' : unit;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
