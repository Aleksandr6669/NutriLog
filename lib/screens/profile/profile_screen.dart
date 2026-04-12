import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileData;

  @override
  void initState() {
    super.initState();
    _profileData = _loadProfileData();
  }

  Future<Map<String, dynamic>> _loadProfileData() async {
    final String response = await rootBundle.loadString('assets/data/profile.json');
    final data = await json.decode(response);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            return _buildProfileContent(context, data);
          } else {
            return const Center(child: Text('Нет данных для отображения'));
          }
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final waterGoalLiters = (data['waterGoal'] as int) / 1000.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(theme, data['userAvatarUrl'], data['userName'], data['userEmail']),
          const SizedBox(height: 24),
          _buildSectionCard(
            theme: theme,
            title: 'Физические параметры',
            icon: Symbols.accessibility_new,
            children: [
              _buildInfoRow(theme, 'Возраст', '${data['userAge']} лет'),
              _buildInfoRow(theme, 'Рост', '${data['userHeight']} см'),
              _buildInfoRow(theme, 'Вес', '${data['userWeight']} кг'),
              _buildInfoRow(theme, 'Цель по весу', '${data['weightGoal']} кг'),
              _buildInfoRow(theme, 'Пол', data['userGender']),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: 'Дневные цели',
            icon: Symbols.track_changes,
            children: [
              _buildInfoRow(theme, 'Калории', '${data['calorieGoal']} ккал'),
              _buildInfoRow(theme, 'Вода', '${waterGoalLiters.toStringAsFixed(1)} л'),
              _buildInfoRow(theme, 'Активность', '${data['activityGoal']} ккал'),
              _buildInfoRow(theme, 'Шаги', '${data['stepsGoal']} шагов'),
              const Divider(height: 16),
              _buildInfoRow(theme, 'Белки', '${data['proteinGoal']} г'),
              _buildInfoRow(theme, 'Углеводы', '${data['carbsGoal']} г'),
              _buildInfoRow(theme, 'Жиры', '${data['fatGoal']} г'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsCard(theme),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Symbols.logout),
              label: const Text('Выйти'),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, String avatarUrl, String name, String email) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(avatarUrl),
            backgroundColor: theme.colorScheme.surfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Symbols.edit, size: 20),
                  tooltip: 'Редактировать',
                )
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Уведомления'),
              value: true, 
              onChanged: (value) {},
              secondary: const Icon(Symbols.notifications),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
