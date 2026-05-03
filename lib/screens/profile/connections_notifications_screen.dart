import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/services/app_startup_service.dart';
import 'package:nutri_log/screens/onboarding/whats_new_screen.dart';
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

  bool _loading = true;
  late NotificationSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String _getLanguageName(BuildContext context) {
    final locale = Localizations.localeOf(context);
    switch (locale.languageCode) {
      case 'ru':
        return 'Русский';
      case 'uk':
        return 'Українська';
      case 'en':
        return 'English';
      default:
        return 'Системный';
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();

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
              title: const Text('Русский'),
              onTap: () {
                localeProvider.setLocale(const Locale('ru'));
                Navigator.pop(context);
              },
              trailing: Localizations.localeOf(context).languageCode == 'ru'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('Українська'),
              onTap: () {
                localeProvider.setLocale(const Locale('uk'));
                Navigator.pop(context);
              },
              trailing: Localizations.localeOf(context).languageCode == 'uk'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
            ),
            ListTile(
              title: const Text('English'),
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
    if (!mounted) return;

    setState(() {
      _settings = settings;
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
        'Не удалось применить настройки уведомлений. Подробнее: $e',
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
          _buildSectionTitle(theme, 'Подключения'),
          const SizedBox(height: 10),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Symbols.account_circle),
                  title: Text('Вход в аккаунт'),
                  subtitle: Text('В разработке'),
                  trailing: FilledButton.tonal(
                    onPressed: null,
                    child: Text('Войти'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(theme, 'Сообщения'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Напоминание о воде'),
                  subtitle: const Text(
                      'Время и количество рассчитываются автоматически по вашей дневной цели воды'),
                  value: _settings.waterReminderEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                        _settings.copyWith(waterReminderEnabled: enabled));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Напоминания о приёмах пищи'),
                  subtitle:
                      const Text('Завтрак, обед и ужин в выбранное время'),
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
                  title: const Text('Напоминание о взвешивании'),
                  subtitle:
                      const Text('Включить ежедневное напоминание внести вес'),
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
                          title: const Text('Время напоминания о взвешивании'),
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
          _buildSectionTitle(theme, 'Приложение'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
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
                                  'Нет информации об обновлениях.';
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
                  title: const Text('История версий'),
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
              subtitle: const Text('Данные, хранение и нейросети'),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => context.push('/profile/agreement'),
            ),
          ),
        ],
      ),
    );
  }
}
