import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/screens/profile/subscription_plans_screen.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';
import 'package:nutri_log/services/firebase_auth_service.dart';
import 'package:nutri_log/services/avatar_cache_service.dart';
import 'package:nutri_log/services/local_first_sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  String? _cachedPhotoBase64;
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
    // Загружаем фото и имя сразу при инициализации
    _loadGooglePhotoAndNameImmediately();
    // Синхронизируем данные с облаком при открытии экрана
    _syncDataOnOpen();
    // Слушаем изменения в авторизации на случай логина/выхода
    FirebaseAuthService.instance.authStateChanges().listen((_) {
      if (mounted) {
        _loadGooglePhotoAndNameImmediately();
      }
    });
  }

  Future<void> _syncDataOnOpen() async {
    if (!FirebaseAuthService.instance.isSignedIn) return;
    await LocalFirstSyncService.instance.syncNow();
    if (mounted) {
      context.read<ProfileProvider>().refreshProfile();
    }
  }

  Future<void> _loadGooglePhotoAndNameImmediately() async {
    final authService = FirebaseAuthService.instance;
    final googleUser = authService.currentUser;
    if (googleUser == null) {
      // При выходе очищаем кеш фото
      if (mounted && _cachedPhotoBase64 != null) {
        setState(() => _cachedPhotoBase64 = null);
      }
      return;
    }

    // Синхронизируем имя
    if (googleUser.displayName != null && googleUser.displayName!.isNotEmpty) {
      final provider = context.read<ProfileProvider>();
      final currentProfile = provider.profile;
      if (currentProfile != null &&
          currentProfile.name != googleUser.displayName) {
        final updated = currentProfile.copyWith(name: googleUser.displayName);
        await provider.updateProfile(updated);
      }
    }

    // Загружаем и кешируем фото сразу — сначала пытаемся получить из кеша,
    // потом загружаем с сервера, если нет кеша
    if (googleUser.photoURL != null && googleUser.photoURL!.isNotEmpty) {
      final cachedFirst =
          await AvatarCacheService.getCachedPhoto(googleUser.uid);
      if (cachedFirst != null && mounted) {
        setState(() => _cachedPhotoBase64 = cachedFirst);
      }
      // Асинхронно обновляем кеш с сервера
      await AvatarCacheService.cacheGooglePhoto(
          googleUser.photoURL, googleUser.uid);
      final updated = await AvatarCacheService.getCachedPhoto(googleUser.uid);
      if (mounted) {
        setState(() => _cachedPhotoBase64 = updated);
      }
    }
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
    if (!mounted) return;

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
        title: Text(AppLocalizations.of(context)!.profile),
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
            context: context,
            theme: theme,
            title: l10n.physicalParams,
            icon: Symbols.accessibility_new,
            onEdit: () async {
              final result = await context
                  .push('/profile/physical', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, l10n.birthDate,
                  '${profile.birthDate.day.toString().padLeft(2, '0')}.${profile.birthDate.month.toString().padLeft(2, '0')}.${profile.birthDate.year}'),
              _buildInfoRow(theme, l10n.age, '${profile.age} ${l10n.yearsOld}'),
              _buildInfoRow(
                  theme, l10n.height, '${profile.height} ${l10n.cmUnit}'),
              _buildInfoRow(
                  theme, l10n.weight, '${profile.weight} ${l10n.weightUnit}'),
              _buildInfoRow(
                  theme, l10n.gender, profile.gender.localizedLabel(context)),
              if (profile.healthConditions.isNotEmpty) ...[
                const Divider(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.healthConditionsTitle,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.hintColor)),
                    const SizedBox(height: 4),
                    Text(profile.healthConditions,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            theme: theme,
            title: l10n.generalGoals,
            icon: Symbols.flag,
            onEdit: () async {
              final result = await context
                  .push('/profile/general_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(theme, l10n.weightGoalTitle,
                  '$weightGoal ${l10n.weightUnit}'),
              _buildInfoRow(theme, l10n.goalTypeTitle,
                  profile.goalType.localizedLabel(context)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            theme: theme,
            title: l10n.dailyGoalsTitle,
            icon: Symbols.track_changes,
            onEdit: () async {
              final result = await context
                  .push('/profile/daily_goals', extra: {'profile': profile});
              if (result == true) _refreshProfile();
            },
            children: [
              _buildInfoRow(
                  theme, l10n.calories, '${profile.calorieGoal} ${l10n.kcal}'),
              _buildInfoRow(theme, l10n.water,
                  '${waterGoalLiters.toStringAsFixed(1)} ${l10n.liters}'),
              _buildInfoRow(
                  theme, l10n.steps, '${profile.stepsGoal} ${l10n.steps}'),
              const Divider(height: 16),
              _buildInfoRow(
                  theme, l10n.protein, '${profile.proteinGoal} ${l10n.grams}'),
              _buildInfoRow(
                  theme, l10n.carbs, '${profile.carbsGoal} ${l10n.grams}'),
              _buildInfoRow(
                  theme, l10n.fat, '${profile.fatGoal} ${l10n.grams}'),
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
        subtitle: Text(l10n.connectionsAndMessages),
        trailing: const Icon(Symbols.chevron_right),
        onTap: () => context.push('/profile/connections'),
      ),
    );
  }

  void _startEditingName(UserProfile profile) {
    // Не разрешаем редактирование имени если пользователь авторизован
    if (FirebaseAuthService.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.nameFromGoogleAccount),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
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
    final l10n = AppLocalizations.of(context)!;
    final avatarIcon = _avatarIconFromProfile(profile);
    final isAuthorized = FirebaseAuthService.instance.isSignedIn;
    final hasPhoto = _cachedPhotoBase64 != null && isAuthorized;

    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: isAuthorized ? null : () => _pickAvatarIcon(profile),
            borderRadius: BorderRadius.circular(50),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: hasPhoto
                  ? MemoryImage(AvatarCacheService.decodeBase64Photo(
                      _cachedPhotoBase64!)!)
                  : null,
              child: !hasPhoto
                  ? Icon(avatarIcon, size: 56, color: AppColors.primary)
                  : null,
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
              : Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: isAuthorized
                              ? null
                              : () => _startEditingName(profile),
                          child: Opacity(
                            opacity: isAuthorized ? 0.7 : 1.0,
                            child: Text(profile.name,
                                style: theme.textTheme.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (isAuthorized)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Symbols.lock,
                              size: 20,
                              color: theme.textTheme.headlineMedium?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                            builder: (context) => const SubscriptionPlansScreen()),
                      ),
                      child: Column(
                        children: [
                          _buildTierBadge(context, theme, profile),
                          if (profile.tier == SubscriptionTier.free)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                l10n.changePlanHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required VoidCallback onEdit,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
                  tooltip: l10n.edit,
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



  Widget _buildTierBadge(
      BuildContext context, ThemeData theme, UserProfile profile) {
    final l10n = AppLocalizations.of(context)!;
    String label = '';
    IconData icon = Symbols.person;
    Color color = Colors.grey;

    switch (profile.tier) {
      case SubscriptionTier.free:
        label = l10n.tierFree;
        icon = Symbols.person;
        color = Colors.grey;
        break;
      case SubscriptionTier.standard:
        label = l10n.tierStandard;
        icon = Symbols.star;
        color = Colors.blue;
        break;
      case SubscriptionTier.premium:
        label = l10n.tierPremium;
        icon = Symbols.workspace_premium;
        color = Colors.amber.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (profile.subscriptionUntil != null) ...[
            const SizedBox(width: 6),
            Container(width: 1, height: 10, color: color.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Text(
              DateFormat.yMd(Localizations.localeOf(context).languageCode)
                  .format(profile.subscriptionUntil!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
