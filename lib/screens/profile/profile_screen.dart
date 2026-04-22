import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/screens/profile/edit_general_goals_screen.dart';
import 'package:nutri_log/screens/profile/edit_goals_screen.dart';
import 'package:nutri_log/screens/profile/edit_physical_params_screen.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import 'package:nutri_log/services/health_steps_service.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final DailyLogService _dailyLogService = DailyLogService();
  final HealthStepsService _healthStepsService = HealthStepsService();
  late Future<UserProfile> _profileFuture;
  bool _isHealthConnected = false;
  bool _isConnectingHealth = false;
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
    _loadProfile();
    _loadHealthConnectionState();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _isEditingName) {
        _saveNameFromController();
      }
    });
  }

  Future<void> _loadHealthConnectionState() async {
    final connected = await _healthStepsService.isConnected();
    if (!mounted) return;
    setState(() {
      _isHealthConnected = connected;
    });
  }

  Future<void> _connectHealth() async {
    if (_isConnectingHealth) return;
    setState(() => _isConnectingHealth = true);

    try {
      final connected = await _healthStepsService.connect();
      if (!mounted) return;

      setState(() {
        _isHealthConnected = connected;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Источник здоровья подключен. Шаги будут синхронизироваться автоматически.'
                : 'Не удалось подключить источник здоровья.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnectingHealth = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await _dailyLogService.syncProfileWeightFromLogs();
    if (!mounted) return;
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
      await _loadProfile();
    }
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
    await _profileService.saveProfile(updatedProfile);
    _loadProfile();
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
    final weightGoal =
        profile.weightGoal.truncateToDouble() == profile.weightGoal
            ? profile.weightGoal.toInt().toString()
            : profile.weightGoal.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: glassBodyPadding(
        context,
        top: 16,
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
            onEdit: () =>
                _navigateTo(EditPhysicalParamsScreen(profile: profile)),
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
            onEdit: () => _navigateTo(EditGeneralGoalsScreen(profile: profile)),
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
            onEdit: () => _navigateTo(EditGoalsScreen(profile: profile)),
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
          Center(
            child: ElevatedButton.icon(
              onPressed: _isConnectingHealth ? null : _connectHealth,
              icon: _isConnectingHealth
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isHealthConnected ? Symbols.check_circle : Symbols.link,
                    ),
              label: Text(
                _isHealthConnected
                    ? 'Источник здоровья подключен'
                    : 'Подключить источник здоровья',
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
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

  void _startEditingName(UserProfile profile) {
    _nameController.text = profile.name;
    setState(() => _isEditingName = true);
    Future.microtask(() => _nameFocusNode.requestFocus());
  }

  Future<void> _saveNameFromController() async {
    final newName = _nameController.text.trim();
    setState(() => _isEditingName = false);
    if (newName.isEmpty) return;
    final profile = await _profileFuture;
    if (newName == profile.name) return;
    final updated = profile.copyWith(name: newName);
    await _profileService.saveProfile(updated);
    _loadProfile();
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
