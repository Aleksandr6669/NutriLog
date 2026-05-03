import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class IconPickerDialog extends StatelessWidget {
  final Function(IconData) onIconSelected;

  const IconPickerDialog({super.key, required this.onIconSelected});

  // A curated list of food-related icons
  static const List<IconData> icons = [
    Symbols.restaurant_rounded,
    Symbols.lunch_dining_rounded,
    Symbols.breakfast_dining_rounded,
    Symbols.ramen_dining_rounded,
    Symbols.bakery_dining_rounded,
    Symbols.tapas_rounded,
    Symbols.icecream_rounded,
    Symbols.local_pizza_rounded,
    Symbols.fastfood_rounded,
    Symbols.local_cafe_rounded,
    Symbols.local_bar_rounded,
    Symbols.liquor_rounded,
    Symbols.egg_rounded,
    Symbols.egg_alt_rounded,
    Symbols.soup_kitchen_rounded,
    Symbols.food_bank_rounded,
    Symbols.set_meal_rounded,
    Symbols.rice_bowl_rounded,
    Symbols.kebab_dining_rounded,
    Symbols.dinner_dining_rounded,
    Symbols.brunch_dining_rounded,
    Symbols.flatware_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.chooseIcon),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                onIconSelected(icons[index]);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(8),
              child: Icon(icons[index],
                  size: 32, color: Theme.of(context).colorScheme.primary),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
