import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/screens/profile/edit_goals_screen.dart';
import 'package:nutri_log/screens/profile/edit_physical_params_screen.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  late Future<UserProfile> _profileFuture;
  static const String _avatarPrefix = 'icon:';
  static const String _defaultAvatarKey = 'person';
  static const Map<String, IconData> _avatarIcons = {
    'person': Symbols.person,
    'account': Symbols.account_circle,
    'face': Symbols.face,
    'face2': Symbols.face_2,
    'face3': Symbols.face_3,
    'face4': Symbols.face_4,
    'boy': Symbols.boy,
    'girl': Symbols.girl,
    'man': Symbols.man,
    'woman': Symbols.woman,
    'people': Symbols.emoji_people,
  };

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

  String _avatarKeyFromProfile(UserProfile profile) {
    final value = profile.avatarImagePath;
    if (value == null || value.isEmpty) return _defaultAvatarKey;
    return value.startsWith(_avatarPrefix) ? value.substring(_avatarPrefix.length) : _defaultAvatarKey;
  }

  IconData _avatarIconFromProfile(UserProfile profile) {
    final key = _avatarKeyFromProfile(profile);
    return _avatarIcons[key] ?? _avatarIcons[_defaultAvatarKey]!;
  }

  Future<void> _pickAvatarIcon(UserProfile profile) async {
    final currentKey = _avatarKeyFromProfile(profile);
    final selectedKey = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canvasColor =
            theme.brightness == Brightness.dark ? AppColors.cardDark : AppColors.cardLight;
        final unselectedBg = theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade100;
        final unselectedIcon = theme.brightness == Brightness.dark
            ? Colors.grey.shade300
            : Colors.grey.shade700;
        return AlertDialog(
          backgroundColor: canvasColor,
          title: const Text('Выберите аватар', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _avatarIcons.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final entry = _avatarIcons.entries.elementAt(index);
                final isSelected = entry.key == currentKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.pop(context, entry.key),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : unselectedBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      entry.value,
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

    if (selectedKey == null || selectedKey == currentKey) return;

    final updatedProfile = profile.copyWith(avatarImagePath: '$_avatarPrefix$selectedKey');
    await _profileService.saveProfile(updatedProfile);
    _loadProfile();
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
    final avatarIcon = _avatarIconFromProfile(profile);

    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickAvatarIcon(profile),
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Icon(avatarIcon, size: 56, color: AppColors.primary),
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
