import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/health_steps_service.dart';
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
  final HealthStepsService _healthStepsService = HealthStepsService();
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  final AppNotificationService _notificationService = AppNotificationService();

  bool _loading = true;
  bool _healthConnected = false;
  bool _connectingHealth = false;
  bool _sendingTestNotification = false;
  bool _sendingWaterTestNotification = false;
  bool _runningDiagnostics = false;
  late NotificationSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final connected = await _healthStepsService.isConnected();
    final settings = await _settingsService.load();
    if (!mounted) return;

    setState(() {
      _healthConnected = connected;
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _connectHealth() async {
    if (_connectingHealth) return;
    setState(() => _connectingHealth = true);

    try {
      final result = await _healthStepsService.connectWithStatus();
      if (!mounted) return;
      setState(() => _healthConnected = result.isConnected);
      final color = switch (result.status) {
        HealthConnectStatus.connected => Colors.green.shade700,
        HealthConnectStatus.needsHealthConnectInstall => Colors.orange.shade700,
        HealthConnectStatus.permissionDenied => Colors.red.shade700,
        HealthConnectStatus.failed => Colors.red.shade700,
      };
      _showSnack(result.message, backgroundColor: color);
    } finally {
      if (mounted) setState(() => _connectingHealth = false);
    }
  }

  Future<void> _disconnectHealth() async {
    await _healthStepsService.disconnect();
    if (!mounted) return;
    setState(() => _healthConnected = false);
  }

  Future<void> _saveNotificationSettings(NotificationSettings settings) async {
    final previous = _settings;
    _settings = settings;
    setState(() {});

    try {
      await _notificationService.applySettings(
        settings,
      );
      await _settingsService.save(settings);
      if (!mounted) return;
      _showSnack(
        'Настройки уведомлений сохранены.',
        backgroundColor: Colors.green.shade700,
      );
    } on NotificationPermissionDeniedException catch (error) {
      _settings = previous;
      if (mounted) setState(() {});
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } on NotificationScheduleException catch (error) {
      _settings = previous;
      if (mounted) setState(() {});
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } catch (_) {
      _settings = previous;
      if (mounted) setState(() {});
      await _settingsService.save(previous);
      if (!mounted) return;
      _showSnack(
        'Не удалось подключить уведомления. Проверьте разрешения уведомлений в настройках телефона.',
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    if (_sendingTestNotification) return;
    setState(() => _sendingTestNotification = true);

    try {
      await _notificationService.sendTestNotification();
      if (!mounted) return;
      _showSnack(
        'Тестовое уведомление отправлено. Оно придет через несколько секунд.',
        backgroundColor: Colors.green.shade700,
      );
    } on NotificationPermissionDeniedException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Не удалось отправить тестовое уведомление. Проверьте разрешения и настройки системы.',
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _sendingTestNotification = false);
    }
  }

  Future<void> _sendWaterTestNotification() async {
    if (_sendingWaterTestNotification) return;
    setState(() => _sendingWaterTestNotification = true);

    try {
      await _notificationService.sendWaterTestNotification();
      if (!mounted) return;
      _showSnack(
        'Тест воды отправлен мгновенно.',
        backgroundColor: Colors.green.shade700,
      );
    } on NotificationPermissionDeniedException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, backgroundColor: Colors.red.shade700);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Не удалось отправить тест воды. Проверьте разрешения уведомлений.',
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _sendingWaterTestNotification = false);
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

  Future<void> _runDiagnostics() async {
    if (_runningDiagnostics) return;
    setState(() => _runningDiagnostics = true);

    try {
      final health = await _healthStepsService.diagnosticsForToday();
      final pending = await _notificationService.getPendingReminderCount();
      final timezone = _notificationService.getCurrentTimezoneName();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Диагностика'),
          content: Text(
            'Здоровье: ${health.message}\n\n'
            'Уведомления: запланировано $pending\n'
            'Часовой пояс: $timezone',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Не удалось выполнить диагностику. Попробуйте еще раз.',
        backgroundColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _runningDiagnostics = false);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: buildGlassAppBar(
        title: const Text('Подключения и сообщения'),
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
                  leading: const Icon(Symbols.favorite),
                  title: const Text('Приложение здоровья'),
                  subtitle: Text(
                    _healthConnected ? 'Подключено' : 'Не подключено',
                  ),
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _healthConnected
                        ? TextButton(
                            key: const ValueKey('disconnect_health'),
                            onPressed: _disconnectHealth,
                            child: const Text('Отключить'),
                          )
                        : FilledButton(
                            key: const ValueKey('connect_health'),
                            onPressed:
                                _connectingHealth ? null : _connectHealth,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _connectingHealth
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Подключить'),
                          ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Symbols.person),
                  title: const Text('Вход в аккаунт'),
                  subtitle: const Text('Скоро будет доступно'),
                  trailing: const Icon(Symbols.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Вход в аккаунт скоро будет доступен.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                if (_settings.waterReminderEnabled)
                  ListTile(
                    leading: const Icon(Symbols.water_drop),
                    title: const Text('Тест воды (мгновенно)'),
                    subtitle:
                        const Text('Проверить мгновенное уведомление о воде'),
                    trailing: FilledButton(
                      onPressed: _sendingWaterTestNotification
                          ? null
                          : _sendWaterTestNotification,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _sendingWaterTestNotification
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Отправить'),
                    ),
                  ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Напоминания о приемах пищи'),
                  subtitle:
                      const Text('Завтрак, обед и ужин в выбранное время'),
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
                              subtitle:
                                  Text(_formatTime(_settings.breakfastTime)),
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
                  title: const Text('Тест уведомления'),
                  subtitle: const Text('Проверить, что уведомления работают'),
                  trailing: FilledButton(
                    onPressed:
                        _sendingTestNotification ? null : _sendTestNotification,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _sendingTestNotification
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отправить'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Symbols.stethoscope),
                  title: const Text('Диагностика'),
                  subtitle:
                      const Text('Показать статус здоровья и уведомлений'),
                  trailing: FilledButton(
                    onPressed: _runningDiagnostics ? null : _runDiagnostics,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _runningDiagnostics
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Проверить'),
                  ),
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
