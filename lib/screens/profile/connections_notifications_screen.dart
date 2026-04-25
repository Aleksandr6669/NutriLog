import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
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
  final AppNotificationService _notificationService = AppNotificationService();

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
    } catch (e, stack) {
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(
        'Не удалось применить настройки уведомлений. Подробнее: $e',
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_requestingPermission || _loading) return; // Проверка на загрузку
    setState(() => _requestingPermission = true);

    try {
      final granted = await _notificationService.requestPermissionNow();
      if (!mounted) return;
      setState(() {
        _settings = _settings.copyWith(messagesEnabled: granted);
      });
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

    // messageSwitch и связанные кнопки удалены по запросу

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: buildGlassAppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 24),
        children: [
          _buildSectionTitle(theme, 'Подключения'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Symbols.health_and_safety),
                  title: const Text('Приложение "Здоровье"'),
                  subtitle: const Text('В разработке'),
                  trailing: FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Подключить'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Symbols.account_circle),
                  title: const Text('Вход в аккаунт'),
                  subtitle: const Text('В разработке'),
                  trailing: FilledButton.tonal(
                    onPressed: null,
                    child: const Text('Войти'),
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
                              title: const Text('Завтрак'),
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
                              title: const Text('Обед'),
                              subtitle: Text(_formatTime(_settings.lunchTime)),
                              trailing: const Icon(Symbols.edit),
                              onTap: () => _pickTime(
                                _settings.lunchTime,
                                (time) => _saveNotificationSettings(
                                    _settings.copyWith(lunchTime: time)),
                              ),
                            ),
                            ListTile(
                              title: const Text('Ужин'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
