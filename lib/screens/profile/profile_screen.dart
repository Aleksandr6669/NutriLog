import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

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
          title: Text(AppLocalizations.of(context)!.chooseAvatar,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final l10n = AppLocalizations.of(context)!;
    final waterGoalLiters = profile.waterGoal / 1000.0;
    final weightGoal =
        profile.weightGoal.truncateToDouble() == profile.weightGoal
            ? profile.weightGoal.toInt().toString()
            : profile.weightGoal.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: glassBodyPadding(
        context,
        top: -8,
        bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 24),
          _buildSectionCard(
            theme: theme,
            title: l10n.physicalParams,
            icon: Symbols.accessibility_new,
            onEdit: () async {
              final result = await context.push('/profile/physical', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, l10n.birthDate,
                  '${profile.birthDate.day.toString().padLeft(2, '0')}.${profile.birthDate.month.toString().padLeft(2, '0')}.${profile.birthDate.year}'),
              _buildInfoRow(theme, l10n.age, '${profile.age} ${l10n.yearsOld}'),
              _buildInfoRow(theme, l10n.height, '${profile.height} см'),
              _buildInfoRow(theme, l10n.weight, '${profile.weight} кг'),
              _buildInfoRow(theme, l10n.gender, profile.gender.localizedLabel(context)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: l10n.generalGoals,
            icon: Symbols.flag,
            onEdit: () async {
              final result = await context.push('/profile/general_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, l10n.weightGoalTitle, '$weightGoal кг'),
              _buildInfoRow(theme, l10n.goalTypeTitle, profile.goalType.localizedLabel(context)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            theme: theme,
            title: l10n.dailyGoalsTitle,
            icon: Symbols.track_changes,
            onEdit: () async {
              final result = await context.push('/profile/daily_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, l10n.calories, '${profile.calorieGoal} ${l10n.kcal}'),
              _buildInfoRow(
                  theme, 'Вода', '${waterGoalLiters.toStringAsFixed(1)} л'),
              _buildInfoRow(theme, l10n.steps, '${profile.stepsGoal} ${l10n.steps}'),
              const Divider(height: 16),
              _buildInfoRow(theme, l10n.protein, '${profile.proteinGoal} г'),
              _buildInfoRow(theme, l10n.carbs, '${profile.carbsGoal} г'),
              _buildInfoRow(theme, l10n.fat, '${profile.fatGoal} г'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSimpleSettingsMenuCard(context, theme),
        ],
      ),
    );
  }

  Widget _buildSimpleSettingsMenuCard(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: ListTile(
        leading: const Icon(Symbols.settings),
        title: Text(l10n.settings),
        subtitle: const Text('Подключения и сообщения'),
        trailing: const Icon(Symbols.chevron_right),
        onTap: () => context.push('/profile/connections'),
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
