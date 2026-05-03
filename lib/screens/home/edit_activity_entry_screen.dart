import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/daily_log.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(isEdit ? l10n.editActivity : l10n.newActivity),
        actions: [
          IconButton(
            icon: const Icon(Symbols.save),
            onPressed: _save,
            tooltip: l10n.save,
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
                          l10n.activityIcon,
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
                        decoration: InputDecoration(
                          labelText: l10n.activityNameLabel,
                          prefixIcon: const Icon(Symbols.fitness_center),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.enterActivityName;
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
                        decoration: InputDecoration(
                          labelText: l10n.burnedCaloriesLabel,
                          suffixText: l10n.kcal,
                          prefixIcon: const Icon(Symbols.local_fire_department),
                        ),
                        validator: (value) {
                          final calories = int.tryParse(value?.trim() ?? '');
                          if (calories == null || calories <= 0) {
                            return l10n.enterCorrectCalories;
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
