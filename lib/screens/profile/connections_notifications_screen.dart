import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/services/app_startup_service.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import 'package:nutri_log/services/cloud_data_service.dart';
import 'package:nutri_log/services/firebase_auth_service.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/services/avatar_cache_service.dart';
import 'package:nutri_log/screens/onboarding/whats_new_screen.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/locale_provider.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class ConnectionsNotificationsScreen extends StatefulWidget {
  const ConnectionsNotificationsScreen({super.key});

  @override
  State<ConnectionsNotificationsScreen> createState() =>
      _ConnectionsNotificationsScreenState();
}

class _ConnectionsNotificationsScreenState
    extends State<ConnectionsNotificationsScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final AppNotificationService _notificationService = AppNotificationService();
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  bool _loading = true;
  bool _authBusy = false;
  bool _connectionsExpanded = false;
  User? _user;
  DateTime? _lastSyncAt;
  late NotificationSettings _settings;
  String? _cachedPhotoBase64;
  // Данные о последней синхронизации
  int _syncedRecipesCount = 0;
  bool _syncedProfile = false;
  bool _syncedDiary = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _user = _authService.currentUser;
    if (_user != null) {
      _autoSyncInBackground();
      _loadCachedPhoto(_user!.uid);
    }
    _authService.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
        if (user == null) _cachedPhotoBase64 = null;
      });
      if (user != null) {
        _autoSyncInBackground();
        _loadCachedPhoto(user.uid);
      }
    });
  }

  String _getLanguageName(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    switch (locale.languageCode) {
      case 'ru':
        return l10n.languageRussian;
      case 'uk':
        return l10n.languageUkrainian;
      case 'en':
        return l10n.languageEnglish;
      default:
        return l10n.languageSystem;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                AppLocalizations.of(context)!.language,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(l10n.languageRussian),
              onTap: () {
                localeProvider.setLocale(const Locale('ru'));
                Navigator.pop(context);
              },
              trailing: Localizations.localeOf(context).languageCode == 'ru'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: Text(l10n.languageUkrainian),
              onTap: () {
                localeProvider.setLocale(const Locale('uk'));
                Navigator.pop(context);
              },
              trailing: Localizations.localeOf(context).languageCode == 'uk'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: Text(l10n.languageEnglish),
              onTap: () {
                localeProvider.setLocale(const Locale('en'));
                Navigator.pop(context);
              },
              trailing: Localizations.localeOf(context).languageCode == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    final lastSync = await CloudDataService.instance.getLastSyncAt();
    if (!mounted) return;

    setState(() {
      _settings = settings;
      _lastSyncAt = lastSync;
      _loading = false;
    });
  }

  Future<void> _saveNotificationSettings(NotificationSettings settings) async {
    final previous = _settings;

    try {
      await _notificationService.applySettings(settings);
      _settings = settings;
      if (mounted) setState(() {});
      await _settingsService.save(settings);
      if (!mounted) return;
      // Уведомление об успешном сохранении больше не показываем
    } on NotificationPermissionDeniedException catch (error) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } on NotificationScheduleException catch (error) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } catch (e) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(
        AppLocalizations.of(context)!.notificationSettingsError(e),
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _loadCachedPhoto(String uid) async {
    final photo = await AvatarCacheService.getCachedPhoto(uid);
    if (!mounted) return;
    setState(() => _cachedPhotoBase64 = photo);
    // Если ещё нет кеша — попробуем скачать из Google
    if (photo == null && _user?.photoURL != null) {
      await AvatarCacheService.cacheGooglePhoto(_user!.photoURL, uid);
      final downloaded = await AvatarCacheService.getCachedPhoto(uid);
      if (mounted) setState(() => _cachedPhotoBase64 = downloaded);
    }
  }

  Future<void> _syncCloudDataAfterSignIn() async {
    await ProfileService().syncWithCloud();
    if (mounted) setState(() => _syncedProfile = true);
    final recipes = await RecipeService().syncWithCloud();
    if (mounted) setState(() => _syncedRecipesCount = recipes);
    await DailyLogService().syncWithCloud();
    if (mounted) setState(() => _syncedDiary = true);
  }

  Future<void> _autoSyncInBackground() async {
    try {
      await _syncCloudDataAfterSignIn();
      await CloudDataService.instance.markSyncNow();
      final lastSync = await CloudDataService.instance.getLastSyncAt();
      if (!mounted) return;
      setState(() {
        _lastSyncAt = lastSync;
      });
    } catch (_) {
      // Автосинк фоновый, без шумных ошибок в UI.
    }
  }

  String _formatLastSync(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_lastSyncAt == null) return l10n.lastCloudSyncNever;

    final locale = Localizations.localeOf(context).languageCode;
    final date = DateFormat.yMd(locale).add_Hm().format(_lastSyncAt!);
    return l10n.lastCloudSyncAt(date);
  }

  Future<void> _handleSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _authBusy = true);
    try {
      // Только вход — ошибки тут реальные (отменил, сеть и т.д.)
      await _authService.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        l10n.googleSignInFailed(e.toString()),
        backgroundColor: Colors.red.shade700,
      );
      if (mounted) setState(() => _authBusy = false);
      return;
    }

    if (mounted) setState(() => _authBusy = false);

    // Синхронизация в фоне — ошибки не показываем пользователю
    _autoSyncInBackground();
  }

  Future<void> _handleSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _authBusy = true);
    try {
      final uid = _authService.currentUser?.uid;
      await _authService.signOut();
      // Очищаем кеш фото при выходе
      if (uid != null) {
        await AvatarCacheService.clearCache(uid);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        l10n.googleSignOutFailed(e.toString()),
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _authBusy = false);
      }
    }
  }

  Future<void> _pickTime(
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked != null) {
      onPicked(picked);
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildAccountAvatar() {
    final photo = _cachedPhotoBase64 != null
        ? AvatarCacheService.decodeBase64Photo(_cachedPhotoBase64!)
        : null;
    if (photo != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: MemoryImage(photo),
      );
    }
    return const CircleAvatar(
      radius: 20,
      child: Icon(Symbols.account_circle, size: 22),
    );
  }

  Widget _buildSyncInfoPanel(ThemeData theme, AppLocalizations l10n) {
    if (_user == null) {
      // Пользователь не вошёл — показываем что будет синхронизироваться
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cloudSyncInfo,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            _buildSyncItem(theme,
                icon: Symbols.person, label: l10n.profile, status: null),
            _buildSyncItem(theme,
                icon: Symbols.receipt_long,
                label: l10n.myRecipes,
                status: null),
            _buildSyncItem(theme,
                icon: Symbols.book, label: l10n.diary, status: null),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата синхронизации заголовком карточки
          Row(
            children: [
              Icon(Symbols.sync,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                _formatLastSync(context),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSyncItem(
            theme,
            icon: Symbols.person,
            label: l10n.profile,
            status: _syncedProfile,
          ),
          _buildSyncItem(
            theme,
            icon: Symbols.receipt_long,
            label: _syncedRecipesCount > 0
                ? '${l10n.myRecipes} ($_syncedRecipesCount)'
                : l10n.myRecipes,
            status: _syncedRecipesCount > 0 || _syncedProfile,
          ),
          _buildSyncItem(
            theme,
            icon: Symbols.book,
            label: l10n.diary,
            status: _syncedDiary,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool? status,
  }) {
    final color = status == null
        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
        : status
            ? Colors.green.shade600
            : theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final statusIcon = status == null
        ? Symbols.sync
        : status
            ? Symbols.check_circle
            : Symbols.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          Icon(statusIcon, size: 16, color: color),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // messageSwitch и связанные кнопки удалены по запросу

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: buildGlassAppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 110),
        children: [
          _buildSectionTitle(theme, l10n.connectionsSection),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              onTap: () => setState(
                () => _connectionsExpanded = !_connectionsExpanded,
              ),
              leading: _buildAccountAvatar(),
              title: Text(l10n.loginToAccount),
              subtitle: Text(
                  _user == null ? l10n.cloudSyncLocalOnly : _user!.email ?? ''),
              trailing: FilledButton.tonal(
                onPressed: _authBusy
                    ? null
                    : (_user == null ? _handleSignIn : _handleSignOut),
                child: Text(_user == null ? l10n.signIn : l10n.signOut),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: _connectionsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card(
                      child: _buildSyncInfoPanel(theme, l10n),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, l10n.notificationMessagesSection),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(l10n.waterReminderTitle),
                  subtitle: Text(l10n.waterReminderSubtitle),
                  value: _settings.waterReminderEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                        _settings.copyWith(waterReminderEnabled: enabled));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: Text(l10n.mealRemindersTitle),
                  subtitle: Text(l10n.mealRemindersSubtitle),
                  value: _settings.mealRemindersEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                        _settings.copyWith(mealRemindersEnabled: enabled));
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _settings.mealRemindersEnabled
                      ? Column(
                          children: [
                            ListTile(
                              title: Text(l10n.breakfast),
                              subtitle:
                                  Text(_formatTime(_settings.breakfastTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.breakfastTime,
                                (time) => _saveNotificationSettings(
                                    _settings.copyWith(breakfastTime: time)),
                              ),
                            ),
                            ListTile(
                              title: Text(l10n.lunch),
                              subtitle: Text(_formatTime(_settings.lunchTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.lunchTime,
                                (time) => _saveNotificationSettings(
                                    _settings.copyWith(lunchTime: time)),
                              ),
                            ),
                            ListTile(
                              title: Text(l10n.dinner),
                              subtitle: Text(_formatTime(_settings.dinnerTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.dinnerTime,
                                (time) => _saveNotificationSettings(
                                    _settings.copyWith(dinnerTime: time)),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: Text(l10n.weightReminderTitle),
                  subtitle: Text(l10n.weightReminderSubtitle),
                  value: _settings.weightReminderEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                        _settings.copyWith(weightReminderEnabled: enabled));
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _settings.weightReminderEnabled
                      ? ListTile(
                          title: Text(l10n.weightReminderTimeTitle),
                          subtitle:
                              Text(_formatTime(_settings.weightReminderTime)),
                          trailing: const Icon(Symbols.edit),
                          onTap: () => _pickTime(
                            _settings.weightReminderTime,
                            (time) => _saveNotificationSettings(
                                _settings.copyWith(weightReminderTime: time)),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, l10n.appSettingsSection),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.auto_awesome,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(l10n.statsAiAssistantToggleTitle),
                  subtitle: Text(l10n.statsAiAssistantToggleSubtitle),
                  trailing: Switch.adaptive(
                    value: _settings.statsAiAssistantEnabled,
                    onChanged: (enabled) async {
                      final updated =
                          _settings.copyWith(statsAiAssistantEnabled: enabled);
                      setState(() => _settings = updated);
                      await _settingsService.save(updated);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Symbols.language),
                  title: Text(l10n.language),
                  subtitle: Text(_getLanguageName(context)),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: () => _showLanguagePicker(context),
                ),
                const Divider(height: 1, indent: 56),
                FutureBuilder<String>(
                  future: AppStartupService()
                      .loadState()
                      .then((s) => s.currentVersion),
                  builder: (context, snapshot) {
                    final version = snapshot.data ?? '...';
                    return ListTile(
                      leading: const Icon(Symbols.info),
                      title: Text(l10n.version),
                      subtitle: Text(version),
                      trailing: TextButton(
                        onPressed: () async {
                          final state = await AppStartupService().loadState();
                          if (!context.mounted) return;
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          final text =
                              await AppStartupService.getWhatsNewForVersion(
                                      state.currentVersion, lang) ??
                                  l10n.noUpdateInfo;
                          if (!context.mounted) return;

                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => WhatsNewScreen(
                                version: state.currentVersion,
                                text: text,
                              ),
                            ),
                          );
                        },
                        child: Text(l10n.whatsNew),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Symbols.history),
                  title: Text(l10n.changelogTitle),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: () => context.push('/profile/changelog'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.description),
              title: Text(l10n.userAgreement),
              subtitle: Text(l10n.userAgreementSubtitle),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => context.push('/profile/agreement'),
            ),
          ),
        ],
      ),
    );
  }
}
