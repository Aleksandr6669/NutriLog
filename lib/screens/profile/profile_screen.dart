import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Symbols.settings), onPressed: () {}),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 32),
          _buildStatsCards(context),
          const SizedBox(height: 24),
          _buildActivityLevel(context),
          const SizedBox(height: 32),
          _buildSettingsSection(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(Symbols.person, size: 60, color: Colors.white),
            ),
            Positioned(
              bottom: 0,
              right: 80,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.primaryColor,
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        Text('Александр Иванов', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Пользователь PRO', style: textTheme.bodyMedium?.copyWith(color: theme.primaryColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, Symbols.scale, 'ВЕС', '75.0', 'ЦЕЛЬ: 70.0 КГ')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(context, Symbols.local_fire_department, 'КАЛОРИИ', '2,150', 'ДНЕВНАЯ НОРМА')),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, IconData icon, String label, String value, String subValue) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.primaryColor, size: 28),
          const SizedBox(height: 16),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subValue, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActivityLevel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Symbols.directions_run, color: Colors.green, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Уровень активности', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Высокая активность', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('НАСТРОЙКИ', style: TextStyle(color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _buildSettingsItem(context, 'Личные данные', Symbols.person),
        const Divider(),
        _buildSettingsItem(context, 'Уведомления', Symbols.notifications),
        const Divider(),
        _buildSettingsItem(context, 'Приватность', Symbols.lock),
        const Divider(),
        _buildSettingsItem(context, 'Выйти', Symbols.logout, color: Colors.red),
      ],
    );
  }

  Widget _buildSettingsItem(BuildContext context, String title, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.textTheme.bodyLarge?.color;
    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(title, style: TextStyle(color: itemColor, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
      onTap: () {},
    );
  }
}
