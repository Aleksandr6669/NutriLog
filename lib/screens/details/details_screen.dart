import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/fatsecret_food.dart';
import '../../providers/diary_provider.dart';

class DetailsScreen extends StatelessWidget {
  final FatsecretFood foodItem;
  const DetailsScreen({super.key, required this.foodItem});

  void _showAddFoodDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Добавить в прием пищи'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Завтрак'),
                onTap: () {
                  Provider.of<DiaryProvider>(context, listen: false).addFood('Завтрак', foodItem);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Продукт добавлен в завтрак')),
                  );
                },
              ),
              ListTile(
                title: const Text('Обед'),
                onTap: () {
                  Provider.of<DiaryProvider>(context, listen: false).addFood('Обед', foodItem);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Продукт добавлен в обед')),
                  );
                },
              ),
              ListTile(
                title: const Text('Ужин'),
                onTap: () {
                  Provider.of<DiaryProvider>(context, listen: false).addFood('Ужин', foodItem);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Продукт добавлен в ужин')),
                  );
                },
              ),
              ListTile(
                title: const Text('Перекус'),
                onTap: () {
                  Provider.of<DiaryProvider>(context, listen: false).addFood('Перекус', foodItem);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Продукт добавлен в перекус')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final serving = foodItem.servings?.first;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildImageHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              children: [
                _buildTitle(context, serving),
                const SizedBox(height: 24),
                if (serving != null) _buildMacronutrients(context, serving),
                const SizedBox(height: 32),
                _buildVitaminsAndMinerals(context),
                const SizedBox(height: 32),
                if (serving != null) _buildNutritionalValue(context, serving),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
      // Placeholder image as the API doesn't provide direct image URLs for all foods
      child: Container(
        color: Colors.grey.shade300,
        height: 350,
        width: double.infinity,
        child: const Icon(Symbols.restaurant, size: 100, color: Colors.grey),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, FatsecretFoodServing? serving) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('${serving?.calories?.toInt() ?? 'N/A'}', style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Text(foodItem.foodName, style: textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('1 порция (${serving?.servingDescription ?? 'N/A'})', style: textTheme.bodyMedium?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildMacronutrients(BuildContext context, FatsecretFoodServing serving) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Макронутриенты', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMacroItem(context, 'Белки', '${serving.protein?.toInt() ?? 0}г', 0.4, const Color(0xFF5B92E5)),
            _buildMacroItem(context, 'Жиры', '${serving.fat?.toInt() ?? 0}г', 0.6, const Color(0xFFF5A623)),
            _buildMacroItem(context, 'Углев.', '${serving.carbohydrate?.toInt() ?? 0}г', 0.3, const Color(0xFFF3646E)),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroItem(BuildContext context, String label, String value, double progress, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 12),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildVitaminsAndMinerals(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Витамины и минералы', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildChip(context, 'Клетчатка', Symbols.grass, Colors.green),
            _buildChip(context, 'Сахар', Symbols.local_cafe, Colors.brown),
            _buildChip(context, 'Витамин C', Symbols.bolt, Colors.orange),
            _buildChip(context, 'Калий', Symbols.circle, Colors.purple.shade300),
            _buildChip(context, 'Магний', Symbols.medication, Colors.red.shade300),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      side: BorderSide(color: color.withOpacity(0.2)),
    );
  }

  Widget _buildNutritionalValue(BuildContext context, FatsecretFoodServing serving) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Пищевая ценность', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildValueRow(context, 'Холестерин', 'N/A'),
        const Divider(thickness: 0.5),
        _buildValueRow(context, 'Натрий', 'N/A'),
        const Divider(thickness: 0.5),
        _buildValueRow(context, 'Насыщенные жиры', 'N/A'),
      ],
    );
  }

  Widget _buildValueRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))
        ]
      ),
      child: ElevatedButton.icon(
        icon: const Icon(Symbols.add_shopping_cart, color: Colors.white),
        label: Text('Добавить в дневник', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showAddFoodDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
