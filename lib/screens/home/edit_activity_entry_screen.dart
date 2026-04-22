import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/daily_log.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class EditActivityEntryScreen extends StatefulWidget {
  final ActivityEntry? entry;

  const EditActivityEntryScreen({super.key, this.entry});

  @override
  State<EditActivityEntryScreen> createState() =>
      _EditActivityEntryScreenState();
}

class _EditActivityEntryScreenState extends State<EditActivityEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late String _selectedIconName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry?.name ?? '');
    _caloriesController =
        TextEditingController(text: widget.entry?.calories.toString() ?? '');
    _selectedIconName = widget.entry?.iconName ?? ActivityEntry.defaultIconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;

    Navigator.of(context).pop(
      ActivityEntry(
        id: widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        calories: calories,
        iconName: _selectedIconName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(isEdit ? 'Редактировать активность' : 'Новая активность'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _save,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: glassBodyPadding(context, top: 16, bottom: 16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Иконка активности',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ActivityEntry.iconOptions.entries.map((e) {
                          final isSelected = _selectedIconName == e.key;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedIconName = e.key;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(28)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 1.8 : 1,
                                ),
                              ),
                              child: Icon(
                                e.value,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Название активности',
                          prefixIcon: Icon(Symbols.fitness_center),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите название активности';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Сожженные калории',
                          suffixText: 'ккал',
                          prefixIcon: Icon(Symbols.local_fire_department),
                        ),
                        validator: (value) {
                          final calories = int.tryParse(value?.trim() ?? '');
                          if (calories == null || calories <= 0) {
                            return 'Введите корректные калории';
                          }
                          return null;
                        },
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
