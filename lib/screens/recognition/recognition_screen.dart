
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class RecognitionScreen extends StatelessWidget {
  const RecognitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildImageHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildRecognitionResult(context),
                const SizedBox(height: 16),
                _buildNutritionInfo(context),
                const SizedBox(height: 24),
                _buildPortionWeight(context),
                const SizedBox(height: 24),
                _buildFavoriteToggle(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return Stack(
      children: [
        Image.network(
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDx-Yp3h42eG0B3_A6gJ5g_4-idqZby2EwsvyG9u3g3_Jv-j9-h8aG3h_xG-yJqWk8Z_lI-u7pB_Q8B-p8cZ-gX_F8eI9Z-eA9b8cI-fG_H_A_D-e_fG-h_A_D_e_fG-h_A_D_e_fG-h_A_D_e_fG-h_A_D_e_fG-h_A',
          fit: BoxFit.cover,
          width: double.infinity,
          height: 400,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: const Icon(Symbols.photo_camera, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildRecognitionResult(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ИИ ОПРЕДЕЛИЛ', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Салат с лососем и авокадо', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Icon(Icons.check_circle, color: Colors.green),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: 'Боул с лососем и авокадо'),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: const Icon(Icons.edit, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildNutritionCard(context, 'ККАЛ', '452'),
        _buildNutritionCard(context, 'БЕЛКИ', '24г'),
        _buildNutritionCard(context, 'ЖИРЫ', '18г'),
        _buildNutritionCard(context, 'УГЛ.', '48г'),
      ],
    );
  }

  Widget _buildNutritionCard(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPortionWeight(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Symbols.scale, color: Colors.green),
      title: const Text('Вес порции'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('350г', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: () {},
    );
  }

  Widget _buildFavoriteToggle(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.favorite_border, color: Colors.pink),
      title: const Text('Добавить в избранное'),
      trailing: Switch(value: false, onChanged: (value) {}),
      onTap: () {},
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
        label: const Text('Сохранить в дневник', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
