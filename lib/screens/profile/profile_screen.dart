import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/screens/profile/edit_goals_screen.dart';
import 'package:nutri_log/screens/profile/edit_physical_params_screen.dart';
import 'package:nutri_log/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    setState(() {
      _profileFuture = _profileService.loadProfile();
    });
  }

  Future<void> _navigateTo(Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (result == true) {
      _loadProfile();
    }
  }

  Future<void> _pickImage(UserProfile profile) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final updatedProfile = profile.copyWith(avatarImagePath: image.path);
      await _profileService.saveProfile(updatedProfile);
      _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: FutureBuilder<UserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final profile = snapshot.data!;
            return _buildProfileContent(context, profile);
          } else {
            return const Center(child: Text('Нет данных для отображения'));
          }
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final waterGoalLiters = profile.waterGoal / 1000.0;
    final weightGoal = profile.weightGoal.truncateToDouble() == profile.weightGoal
        ? profile.weightGoal.toInt().toString()
        : profile.weightGoal.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 24),
          _buildSectionCard(
            theme: theme,
            title: 'Физические параметры',
            icon: Symbols.accessibility_new,
            onEdit: () => _navigateTo(EditPhysicalParamsScreen(profile: profile)),
            children: [
              _buildInfoRow(theme, 'Возраст', '${profile.age} лет'),
              _buildInfoRow(theme, 'Рост', '${profile.height} см'),
              _buildInfoRow(theme, 'Вес', '${profile.weight} кг'),
              _buildInfoRow(theme, 'Пол', profile.gender.toString().split('.').last),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: 'Дневные цели',
            icon: Symbols.track_changes,
            onEdit: () => _navigateTo(EditGoalsScreen(profile: profile)),
            children: [
              _buildInfoRow(theme, 'Цель по весу', '$weightGoal кг'),
               const Divider(height: 16),
              _buildInfoRow(theme, 'Калории', '${profile.calorieGoal} ккал'),
              _buildInfoRow(theme, 'Вода', '${waterGoalLiters.toStringAsFixed(1)} л'),
              _buildInfoRow(theme, 'Шаги', '${profile.stepsGoal} шагов'),
              const Divider(height: 16),
              _buildInfoRow(theme, 'Белки', '${profile.proteinGoal} г'),
              _buildInfoRow(theme, 'Углеводы', '${profile.carbsGoal} г'),
              _buildInfoRow(theme, 'Жиры', '${profile.fatGoal} г'),
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

  Widget _buildProfileHeader(ThemeData theme, UserProfile profile) {
    ImageProvider<Object> backgroundImage;
    if (profile.avatarImagePath != null && profile.avatarImagePath!.isNotEmpty) {
      backgroundImage = FileImage(File(profile.avatarImagePath!));
    } else {
      backgroundImage = const NetworkImage('https://i.pravatar.cc/150?u=a042581f4e29026704d');
    }

    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickImage(profile),
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 50,
              backgroundImage: backgroundImage,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 16),
          Text(profile.name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required VoidCallback onEdit,
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
                  onPressed: onEdit,
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
