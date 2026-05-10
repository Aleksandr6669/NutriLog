import 'package:flutter/material.dart';
import 'package:nutri_log/services/notification_settings_service.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/styles/app_styles.dart';
import 'package:nutri_log/services/ai_error_log_service.dart';
import 'package:intl/intl.dart';

class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() => _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  final _settingsService = NotificationSettingsService();
  NotificationSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings(NotificationSettings settings) async {
    await _settingsService.save(settings);
    if (mounted) {
      setState(() => _settings = settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: const Text('Настройки разработчика', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: glassBodyPadding(context, left: 16, top: 8, right: 16, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Искусственный интеллект'),
            _buildAiSettingsCard(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Логи ошибок AI'),
                TextButton.icon(
                  onPressed: () {
                    AiErrorLogService.instance.clearLogs();
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Очистить'),
                ),
              ],
            ),
            _buildErrorLogsCard(),
            const SizedBox(height: 24),
            _buildWarningCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAiSettingsCard() {
    return Card(
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: Column(
        children: [
          _buildModelPicker(),
          const Divider(height: 1, indent: 56),
          _buildRetryAttemptsPicker(),
          const Divider(height: 1, indent: 56),
          _buildRetryDelayPicker(),
        ],
      ),
    );
  }

  Widget _buildErrorLogsCard() {
    final logs = AiErrorLogService.instance.logs;

    if (logs.isEmpty) {
      return Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('Логов пока нет', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
          
          final color = log.isError 
            ? Colors.red 
            : (log.message == 'Request Started' ? Colors.blue : Colors.green);
          final icon = log.isError 
            ? Icons.error_outline 
            : (log.message == 'Request Started' ? Icons.upload : Icons.check_circle_outline);

          return ExpansionTile(
            leading: Icon(icon, color: color),
            title: Text(log.feature, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$timeStr - ${log.message}'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    log.details ?? 'Нет дополнительных данных',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModelPicker() {
    final models = [
      'gemini-3.1-flash-lite',
      'gemini-3-flash-preview',
      'gemini-3.1-pro-preview',
    ];

    return ListTile(
      leading: const Icon(Icons.psychology, color: Colors.purple),
      title: const Text('Модель Gemini'),
      subtitle: Text(_settings!.geminiModel),
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: models.map((m) => ListTile(
                title: Text(m),
                trailing: _settings!.geminiModel == m ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  _saveSettings(_settings!.copyWith(geminiModel: m));
                  Navigator.pop(context);
                },
              )).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRetryAttemptsPicker() {
    return ListTile(
      leading: const Icon(Icons.replay, color: Colors.orange),
      title: const Text('Количество попыток'),
      subtitle: const Text('При неудачном запросе или ошибке JSON'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _settings!.aiRetryAttempts > 1 
              ? () => _saveSettings(_settings!.copyWith(aiRetryAttempts: _settings!.aiRetryAttempts - 1))
              : null,
          ),
          Text('${_settings!.aiRetryAttempts}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _settings!.aiRetryAttempts < 5
              ? () => _saveSettings(_settings!.copyWith(aiRetryAttempts: _settings!.aiRetryAttempts + 1))
              : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRetryDelayPicker() {
    return ListTile(
      leading: const Icon(Icons.timer, color: Colors.blue),
      title: const Text('Задержка (сек)'),
      subtitle: const Text('Между попытками при 429 ошибке'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _settings!.aiRetryDelaySeconds > 1 
              ? () => _saveSettings(_settings!.copyWith(aiRetryDelaySeconds: _settings!.aiRetryDelaySeconds - 1))
              : null,
          ),
          Text('${_settings!.aiRetryDelaySeconds}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _settings!.aiRetryDelaySeconds < 30
              ? () => _saveSettings(_settings!.copyWith(aiRetryDelaySeconds: _settings!.aiRetryDelaySeconds + 1))
              : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Изменение этих параметров может привести к нестабильной работе AI или временным блокировкам API.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
