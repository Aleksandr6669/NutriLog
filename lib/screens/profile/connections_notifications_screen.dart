import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

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
  final AppNotificationService _notificationService =
      AppNotificationService();

  bool _loading = true;
  bool _requestingPermission = false;
  late NotificationSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
      _showSnack(
        'Настройки уведомлений сохранены.',
        backgroundColor: Colors.green.shade700,
      );
    } on NotificationPermissionDeniedException catch (error) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } on NotificationScheduleException catch (error) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } catch (_) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(
        'Не удалось применить настройки уведомлений.',
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);

    try {
      final granted = await _notificationService.requestPermissionNow();
      if (!mounted) return;
      _showSnack(
        granted
            ? 'Доступ к уведомлениям выдан.'
            : 'Не удалось получить разрешение на уведомления. Проверьте настройки iOS.',
        backgroundColor: granted ? Colors.green.shade700 : Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
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

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: buildGlassAppBar(
        title: const Text('Подключения и сообщения'),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 24),
        children: [
          _buildSectionTitle(theme, 'Сообщения'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Напоминание о воде'),
                  subtitle: const Text(
                    'Время и количество рассчитываются автоматически по вашей дневной цели воды',
                  ),
                  value: _settings.waterReminderEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                      _settings.copyWith(waterReminderEnabled: enabled),
                    );
                  },
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _settings.waterReminderEnabled
                      ? const Padding(
                          key: ValueKey('water_enabled_hint'),
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'Автоплан воды активен: график и количество рассчитываются сами.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : const SizedBox(key: ValueKey('water_disabled_hint')),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Напоминания о приемах пищи'),
                  subtitle: const Text('Завтрак, обед и ужин в выбранное время'),
                  value: _settings.mealRemindersEnabled,
                  onChanged: (enabled) {
                    _saveNotificationSettings(
                      _settings.copyWith(mealRemindersEnabled: enabled),
                    );
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: _settings.mealRemindersEnabled
                      ? Column(
                          children: [
                            ListTile(
                              title: const Text('Завтрак'),
                              subtitle: Text(_formatTime(_settings.breakfastTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.breakfastTime,
                                (time) => _saveNotificationSettings(
                                  _settings.copyWith(breakfastTime: time),
                                ),
                              ),
                            ),
                            ListTile(
                              title: const Text('Обед'),
                              subtitle: Text(_formatTime(_settings.lunchTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.lunchTime,
                                (time) => _saveNotificationSettings(
                                  _settings.copyWith(lunchTime: time),
                                ),
                              ),
                            ),
                            ListTile(
                              title: const Text('Ужин'),
                              subtitle: Text(_formatTime(_settings.dinnerTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.dinnerTime,
                                (time) => _saveNotificationSettings(
                                  _settings.copyWith(dinnerTime: time),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Symbols.notifications_active),
                  title: const Text('Выдать доступ к уведомлениям'),
                  subtitle: const Text(
                    'Нажмите, чтобы вызвать системный запрос разрешения iOS',
                  ),
                  trailing: FilledButton(
                    onPressed: _requestingPermission
                        ? null
                        : _requestNotificationPermission,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _requestingPermission
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Выдать'),
                  ),
                ),
                // Добавлено сообщение о разработке для аккаунтов и подключения к приложению "Здоровье"
                const ListTile(
                  leading: Icon(Symbols.account_circle),
                  title: Text('Аккаунты'),
                  subtitle: Text('В разработке'),
                  onTap: null,
                ),
                const ListTile(
                  leading: Icon(Symbols.health_and_safety),
                  title: Text('Подключение к приложению "Здоровье"'),
                  subtitle: Text('В разработке'),
                  onTap: null,
                ),
                // Включение и настройка сообщений
                SwitchListTile(
                  title: const Text('Включить сообщения'),
                  value: _settings.messagesEnabled,
                  onChanged: (bool value) async {
                    setState(() => _loading = true);
                    await _settingsService.updateMessagesEnabled(value);
                    setState(() {
                      _settings = _settings.copyWith(messagesEnabled: value);
                      _loading = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Push-уведомления приходят и при закрытом приложении.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
