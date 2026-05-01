import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/services/app_startup_service.dart';
import 'package:nutri_log/screens/onboarding/whats_new_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DailyLogService _dailyLogService = DailyLogService();
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
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
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _isEditingName) {
        _saveNameFromController();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _refreshProfile() {
    context.read<ProfileProvider>().refreshProfile();
  }


  String _avatarKeyFromProfile(UserProfile profile) {
    final value = profile.avatarImagePath;
    if (value == null || value.isEmpty) return _defaultAvatarKey;
    return value.startsWith(_avatarPrefix)
        ? value.substring(_avatarPrefix.length)
        : _defaultAvatarKey;
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
          title: const Text('Выберите аватар',
              style: TextStyle(fontWeight: FontWeight.bold)),
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

    final updatedProfile =
        profile.copyWith(avatarImagePath: '$_avatarPrefix$selectedKey');
    await context.read<ProfileProvider>().updateProfile(updatedProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('Профиль'),
        centerTitle: true,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          final profile = profileProvider.profile;
          if (profileProvider.isLoading || profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildProfileContent(context, profile);
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final waterGoalLiters = profile.waterGoal / 1000.0;
    final weightGoal =
        profile.weightGoal.truncateToDouble() == profile.weightGoal
            ? profile.weightGoal.toInt().toString()
            : profile.weightGoal.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: glassBodyPadding(
        context,
        top: 0,
        bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 24),
          _buildSectionCard(
            theme: theme,
            title: 'Физические параметры',
            icon: Symbols.accessibility_new,
            onEdit: () async {
              final result = await context.push('/profile/physical', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, 'Дата рождения',
                  '${profile.birthDate.day.toString().padLeft(2, '0')}.${profile.birthDate.month.toString().padLeft(2, '0')}.${profile.birthDate.year}'),
              _buildInfoRow(theme, 'Возраст', '${profile.age} лет'),
              _buildInfoRow(theme, 'Рост', '${profile.height} см'),
              _buildInfoRow(theme, 'Вес', '${profile.weight} кг'),
              _buildInfoRow(theme, 'Пол', profile.gender.ruLabel),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: 'Общие цели',
            icon: Symbols.flag,
            onEdit: () async {
              final result = await context.push('/profile/general_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, 'Цель по весу', '$weightGoal кг'),
              _buildInfoRow(theme, 'Тип цели', profile.goalType.ruLabel),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: 'Дневные цели',
            icon: Symbols.track_changes,
            onEdit: () async {
              final result = await context.push('/profile/daily_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, 'Калории', '${profile.calorieGoal} ккал'),
              _buildInfoRow(
                  theme, 'Вода', '${waterGoalLiters.toStringAsFixed(1)} л'),
              _buildInfoRow(theme, 'Шаги', '${profile.stepsGoal} шагов'),
              const Divider(height: 16),
              _buildInfoRow(theme, 'Белки', '${profile.proteinGoal} г'),
              _buildInfoRow(theme, 'Углеводы', '${profile.carbsGoal} г'),
              _buildInfoRow(theme, 'Жиры', '${profile.fatGoal} г'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSimpleSettingsMenuCard(theme),
        ],
      ),
    );
  }

  Widget _buildSimpleSettingsMenuCard(ThemeData theme) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Symbols.settings),
            title: const Text('Настройки'),
            subtitle: const Text('Подключения и сообщения'),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () => context.push('/profile/connections'),
          ),
        ),
        const SizedBox(height: 24),
        _buildVersionInfo(theme),
      ],
    );
  }

  Widget _buildVersionInfo(ThemeData theme) {
    final startupService = AppStartupService();
    return FutureBuilder<StartupState>(
      future: startupService.loadState(),
      builder: (context, snapshot) {
        final version = snapshot.data?.currentVersion ?? '...';
        return Column(
          children: [
            Text(
              'Версия $version',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final state = await startupService.loadState();
                if (!mounted) return;
                
                // Show WhatsNewScreen as a full-screen dialog or navigate to it
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WhatsNewScreen(
                      version: state.currentVersion,
                      text: "• Улучшена производительность приложения.\n"
                            "• Исправлены мелкие баги и улучшена стабильность.\n"
                            "• Добавлены уведомления по воде и приемам пищи.\n"
                            "• Добавлены уведомления напоминания взвеситься.\n"
                            "• Улучшена интеграция с нейросетью.\n"
                            "• Добавлены виджеты для андроида.\n"
                            "• Добавлена поддержка новых устройств и экранов.",
                    ),
                  ),
                );
              },
              child: Text(
                'Что нового?',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startEditingName(UserProfile profile) {
    _nameController.text = profile.name;
    setState(() => _isEditingName = true);
    Future.microtask(() => _nameFocusNode.requestFocus());
  }

  Future<void> _saveNameFromController() async {
    final newName = _nameController.text.trim();
    setState(() => _isEditingName = false);
    if (newName.isEmpty) return;
    
    final provider = context.read<ProfileProvider>();
    final currentProfile = provider.profile;
    if (currentProfile == null || newName == currentProfile.name) return;
    
    final updated = currentProfile.copyWith(name: newName);
    await provider.updateProfile(updated);
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
          _isEditingName
              ? SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    enableInteractiveSelection: false,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    textCapitalization: TextCapitalization.words,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _saveNameFromController(),
                  ),
                )
              : GestureDetector(
                  onTap: () => _startEditingName(profile),
                  child: Text(profile.name,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
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
          Text(value,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
