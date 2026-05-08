import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:nutri_log/services/local_first_sync_service.dart';
import 'package:nutri_log/services/profile_service.dart';
import 'package:nutri_log/services/recipe_service.dart';
import 'package:nutri_log/services/avatar_cache_service.dart';
import 'package:nutri_log/screens/onboarding/whats_new_screen.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
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
    extends State<ConnectionsNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final AppNotificationService _notificationService = AppNotificationService();
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  bool _loading = true;
  bool _authBusy = false;
  bool _isResolvingSignInFlow = false;
  bool _connectionsExpanded = false;
  bool _confirmSignOut = false;
  late final AnimationController _btnAnimController;
  late final Animation<double> _btnScaleAnim;
  late final Animation<double> _spacingAnim;
  User? _user;
  DateTime? _lastSyncAt;
  late NotificationSettings _settings;
  String? _cachedPhotoBase64;
  // Данные о последней синхронизации
  int _syncedRecipesCount = 0;
  bool _syncedProfile = false;
  bool _syncedDiary = false;
  late final VoidCallback _syncStatusListener;

  @override
  void initState() {
    super.initState();
    _btnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _btnScaleAnim = CurvedAnimation(
      parent: _btnAnimController,
      curve: Curves.easeOutBack,
    );
    _spacingAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 16.0, end: 4.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 4.0, end: 12.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _btnAnimController,
      curve: Curves.easeInOut,
    ));
    _btnAnimController.forward();
    _loadSettings();
    _syncStatusListener = _onSyncStatusChanged;
    LocalFirstSyncService.instance.statusNotifier
        .addListener(_syncStatusListener);
    _user = _authService.currentUser;
    if (_user != null) {
      _autoSyncInBackground();
      _loadCachedPhoto(_user!.uid);
    }
    _authService.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
        if (user == null) {
          _cachedPhotoBase64 = null;
          _syncedProfile = false;
          _syncedDiary = false;
          _syncedRecipesCount = 0;
        }
      });
      if (user != null) {
        // During sign-in conflict flow we must not push local data to cloud
        // before the user chooses conflict resolution strategy.
        if (!_isResolvingSignInFlow) {
          _autoSyncInBackground();
        }
        _loadCachedPhoto(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _btnAnimController.dispose();
    LocalFirstSyncService.instance.statusNotifier
        .removeListener(_syncStatusListener);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (!mounted) return;
    final status = LocalFirstSyncService.instance.statusNotifier.value;
    if (status == SyncStatus.synced) {
      final syncedAt = LocalFirstSyncService.instance.lastSyncedAt;
      setState(() {
        _syncedProfile = true;
        _syncedDiary = true;
        if (_syncedRecipesCount == 0) {
          // Если счётчик пока не посчитан, показываем, что синк рецептов тоже успешен.
          _syncedRecipesCount = 1;
        }
        _lastSyncAt = syncedAt?.toLocal() ?? DateTime.now();
      });
    }
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

  String _inlineLocalized({
    required String ru,
    required String en,
    required String uk,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'en') return en;
    if (code == 'uk') return uk;
    return ru;
  }

  String _aiProviderLabel(String provider) {
    switch (provider) {
      case NotificationSettings.aiProviderGemini:
        return 'Gemini';
      default:
        return 'Groq';
    }
  }

  String _geminiModelLabel(String model) {
    switch (model) {
      case NotificationSettings.geminiModelPro:
        return 'Gemini 2.5 Pro';
      case NotificationSettings.geminiModelFlashLite:
        return 'Gemini 2.5 Flash-Lite';
      case NotificationSettings.geminiModelFlash:
      default:
        return 'Gemini 2.5 Flash';
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
    // Мгновенно показываем кеш
    final photo = await AvatarCacheService.getCachedPhoto(uid);
    if (!mounted) return;
    setState(() => _cachedPhotoBase64 = photo);

    // Фоновое обновление: всегда скачиваем свежее из Google (если URL есть)
    // Обновит UI только если картинка изменилась
    if (_user?.photoURL != null) {
      _refreshAvatarInBackground(uid);
    }
  }

  void _refreshAvatarInBackground(String uid) {
    AvatarCacheService.cacheGooglePhoto(_user?.photoURL, uid)
        .then((changed) async {
      if (!changed || !mounted) return;
      final downloaded = await AvatarCacheService.getCachedPhoto(uid);
      if (mounted) setState(() => _cachedPhotoBase64 = downloaded);
    }).catchError((_) {
      // Ошибка сети — оставляем кешированное фото
    });
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
    setState(() {
      _authBusy = true;
      _isResolvingSignInFlow = true;
    });
    try {
      // Только вход — ошибки тут реальные (отменил, сеть и т.д.)
      await _authService.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        l10n.googleSignInFailed,
        backgroundColor: Colors.red.shade700,
      );
      if (mounted) {
        setState(() {
          _authBusy = false;
          _isResolvingSignInFlow = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _authBusy = false);

    final syncService = LocalFirstSyncService.instance;
    try {
      final needsResolution = await syncService.needsSignInConflictResolution();
      if (needsResolution && mounted) {
        final decision = await _showDataConflictDialog();
        if (decision != null) {
          await syncService.resolveSignInDataConflict(decision);
        }
      } else {
        await syncService.syncNow();
      }
    } catch (_) {
      // Не блокируем вход из-за ошибки разрешения конфликта.
    } finally {
      if (mounted) {
        setState(() => _isResolvingSignInFlow = false);
      } else {
        _isResolvingSignInFlow = false;
      }
    }

    // Синхронизация в фоне — ошибки не показываем пользователю
    _autoSyncInBackground();
  }

  Future<SignInDataResolution?> _showDataConflictDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<SignInDataResolution>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.accountDataConflictTitle),
          content: Text(l10n.accountDataConflictMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                SignInDataResolution.useCloud,
              ),
              child: Text(l10n.accountDataConflictUseCloud),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                SignInDataResolution.keepLocal,
              ),
              child: Text(l10n.accountDataConflictUseLocal),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onSignOutTap() async {
    setState(() => _confirmSignOut = true);
    _btnAnimController.forward(from: 0);
  }

  void _cancelSignOut() {
    setState(() => _confirmSignOut = false);
    _btnAnimController.forward(from: 0);
  }

  Future<void> _handleSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _confirmSignOut = false;
      _authBusy = true;
    });
    try {
      final uid = _authService.currentUser?.uid;
      await _authService.signOut();
      // Очищаем только кеш фото Google-аккаунта при выходе
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
    final status = LocalFirstSyncService.instance.statusNotifier.value;
    final hasSynced = status == SyncStatus.synced || _lastSyncAt != null;

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
            status: _syncedProfile || hasSynced,
          ),
          _buildSyncItem(
            theme,
            icon: Symbols.receipt_long,
            label: _syncedRecipesCount > 0
                ? '${l10n.myRecipes} ($_syncedRecipesCount)'
                : l10n.myRecipes,
            status: _syncedRecipesCount > 0 || hasSynced,
          ),
          _buildSyncItem(
            theme,
            icon: Symbols.book,
            label: l10n.diary,
            status: _syncedDiary || hasSynced,
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

  Widget _buildSyncStatusBadge(ThemeData theme) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: LocalFirstSyncService.instance.statusNotifier,
      builder: (context, status, _) {
        final l10n = AppLocalizations.of(context)!;
        final Color color;
        final IconData icon;
        final String label;
        Widget? leading;

        switch (status) {
          case SyncStatus.syncing:
            color = Colors.blue.shade600;
            icon = Symbols.sync;
            label = l10n.syncStatusSyncing;
            leading = SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            );
          case SyncStatus.synced:
            color = Colors.green.shade600;
            icon = Symbols.cloud_done;
            final syncedAt = LocalFirstSyncService.instance.lastSyncedAt;
            final timeStr =
                syncedAt != null ? DateFormat.Hm().format(syncedAt) : '';
            label = timeStr.isNotEmpty
                ? l10n.syncStatusSyncedAt(timeStr)
                : l10n.syncStatusSynced;
          case SyncStatus.error:
            color = Colors.orange.shade700;
            icon = Symbols.sync_problem;
            label = l10n.syncStatusError;
          case SyncStatus.idle:
            color = theme.colorScheme.onSurface.withValues(alpha: 0.4);
            icon = Symbols.cloud_queue;
            label = l10n.syncStatusIdle;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              leading ?? Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
              if (status != SyncStatus.syncing)
                GestureDetector(
                  onTap: () {
                    LocalFirstSyncService.instance.syncNow();
                  },
                  child: Icon(Symbols.refresh, size: 16, color: color),
                ),
            ],
          ),
        );
      },
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
            child: InkWell(
              borderRadius: AppStyles.cardRadius,
              onTap: () => setState(
                () => _connectionsExpanded = !_connectionsExpanded,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    _buildAccountAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.loginToAccount,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _user == null
                                ? l10n.cloudSyncLocalOnly
                                : _user!.email ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_authBusy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_user == null)
                      ScaleTransition(
                        scale: _btnScaleAnim,
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(
                            begin: Colors.blue.shade600,
                            end: Colors.green.shade600,
                          ),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, color, child) => FilledButton(
                            onPressed: _handleSignIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                            ),
                            child: child!,
                          ),
                          child: Text(l10n.signIn),
                        ),
                      )
                    else if (_confirmSignOut)
                      ScaleTransition(
                        scale: _btnScaleAnim,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(
                              onPressed: _handleSignOut,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              child: Text(l10n.confirmYes),
                            ),
                            AnimatedBuilder(
                              animation: _spacingAnim,
                              builder: (context, _) =>
                                  SizedBox(width: _spacingAnim.value),
                            ),
                            FilledButton(
                              onPressed: _cancelSignOut,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              child: Text(l10n.confirmNo),
                            ),
                          ],
                        ),
                      )
                    else
                      ScaleTransition(
                        scale: _btnScaleAnim,
                        child: FilledButton(
                          onPressed: _onSignOutTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                          ),
                          child: Text(l10n.signOut),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_user != null) ...[
            const SizedBox(height: 8),
            _buildSyncStatusBadge(theme),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: _connectionsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        Card(
                          child: _buildSyncInfoPanel(theme, l10n),
                        ),
                      ],
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
                      HapticFeedback.selectionClick();
                      final updated =
                          _settings.copyWith(statsAiAssistantEnabled: enabled);
                      setState(() => _settings = updated);
                      await _settingsService.save(updated);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.auto_fix_high,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(l10n.recipeAiAutoNutritionToggleTitle),
                  subtitle: Text(l10n.recipeAiAutoNutritionToggleSubtitle),
                  trailing: Switch.adaptive(
                    value: _settings.recipeAiAutoNutritionEnabled,
                    onChanged: (enabled) async {
                      HapticFeedback.selectionClick();
                      final updated = _settings.copyWith(
                        recipeAiAutoNutritionEnabled: enabled,
                      );
                      setState(() => _settings = updated);
                      await _settingsService.save(updated);
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.28),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.tune,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(
                    _inlineLocalized(
                      ru: 'AI провайдер',
                      en: 'AI provider',
                      uk: 'AI провайдер',
                    ),
                  ),
                  subtitle: Text(
                    _inlineLocalized(
                      ru: 'Выберите сервис для AI функций',
                      en: 'Choose service for AI features',
                      uk: 'Оберіть сервіс для AI функцій',
                    ),
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _settings.aiProvider,
                      items: const [
                        DropdownMenuItem(
                          value: NotificationSettings.aiProviderGroq,
                          child: Text('Groq'),
                        ),
                        DropdownMenuItem(
                          value: NotificationSettings.aiProviderGemini,
                          child: Text('Gemini'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        HapticFeedback.selectionClick();
                        final updated = _settings.copyWith(aiProvider: value);
                        setState(() => _settings = updated);
                        await _settingsService.save(updated);
                      },
                    ),
                  ),
                ),
                if (_settings.aiProvider == NotificationSettings.aiProviderGemini) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.28),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Symbols.model_training,
                        size: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                    title: Text(
                      _inlineLocalized(
                        ru: 'Модель Gemini',
                        en: 'Gemini model',
                        uk: 'Модель Gemini',
                      ),
                    ),
                    subtitle: Text(
                      _inlineLocalized(
                        ru: 'Только новые модели',
                        en: 'New models only',
                        uk: 'Лише нові моделі',
                      ),
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _settings.geminiModel,
                        items: const [
                          DropdownMenuItem(
                            value: NotificationSettings.geminiModelFlashLite,
                            child: Text('Gemini 2.5 Flash-Lite'),
                          ),
                          DropdownMenuItem(
                            value: NotificationSettings.geminiModelFlash,
                            child: Text('Gemini 2.5 Flash'),
                          ),
                          DropdownMenuItem(
                            value: NotificationSettings.geminiModelPro,
                            child: Text('Gemini 2.5 Pro'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          HapticFeedback.selectionClick();
                          final updated = _settings.copyWith(geminiModel: value);
                          setState(() => _settings = updated);
                          await _settingsService.save(updated);
                        },
                      ),
                    ),
                  ),
                ],
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
