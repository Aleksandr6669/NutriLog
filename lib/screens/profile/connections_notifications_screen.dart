import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/services/app_notification_service.dart';
import 'package:nutri_log/services/health_steps_service.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/styles/app_styles.dart';
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
      final connected = await _healthStepsService.connect();
      if (!mounted) return;
      setState(() => _healthConnected = connected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected
                ? 'Источник здоровья подключен.'
                : 'Не удалось подключить источник здоровья.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    _settings = settings;
    setState(() {});
    await _settingsService.save(settings);
    await _notificationService.applySettings(settings);
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

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassSectionCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: AppStyles.cardRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: kGlassSurfaceAlpha),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
          ),
          borderRadius: AppStyles.cardRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(children: children),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        flexibleSpace: const GlassAppBarBackground(),
        title: const Text('Подключения и сообщения'),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppStyles.cardRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: const Text(
              'Настройте источники данных и персональные уведомления. Изменения применяются сразу.',
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(theme, 'Подключения', Symbols.hub),
          const SizedBox(height: 10),
          _buildGlassSectionCard(
            children: [
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Symbols.favorite,
                      size: 20, color: AppColors.primary),
                ),
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
                          onPressed: _connectingHealth ? null : _connectHealth,
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
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Symbols.person, size: 20, color: Colors.blue),
                ),
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
          const SizedBox(height: 18),
          _buildSectionTitle(theme, 'Сообщения', Symbols.notifications),
          const SizedBox(height: 10),
          _buildGlassSectionCard(
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
                    ? Padding(
                        key: const ValueKey('water_enabled_hint'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          child: const Text(
                            'Автоплан воды активен: график и количество рассчитываются сами.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                            leading: const Icon(Symbols.wb_twilight),
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
                            leading: const Icon(Symbols.sunny),
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
                            leading: const Icon(Symbols.nights_stay),
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
            ],
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
