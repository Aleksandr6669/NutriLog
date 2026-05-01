import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/daily_log_provider.dart';
import '../../models/daily_log.dart';
import '../../services/daily_log_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'edit_activity_entry_screen.dart';

class ActivityLogScreen extends StatefulWidget {
  final DateTime date;
  final List<ActivityEntry> initialActivities;

  const ActivityLogScreen({
    super.key,
    required this.date,
    required this.initialActivities,
  });

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final DailyLogService _service = DailyLogService();
  late List<ActivityEntry> _activities;
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _activities = List<ActivityEntry>.from(widget.initialActivities);
  }

  int get _totalCalories =>
      _activities.fold<int>(0, (sum, activity) => sum + activity.calories);

  Future<void> _addOrEditActivity({ActivityEntry? entry}) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<ActivityEntry>(
      MaterialPageRoute(
        builder: (_) => EditActivityEntryScreen(entry: entry),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _saving = true);
    final provider = context.read<DailyLogProvider>();
    
    if (entry == null) {
      await _service.addActivity(
        widget.date,
        name: result.name,
        calories: result.calories,
        iconName: result.iconName,
      );
    } else {
      await _service.updateActivity(
        widget.date,
        id: entry.id,
        name: result.name,
        calories: result.calories,
        iconName: result.iconName,
      );
    }

    await provider.refreshCurrentLog();

    if (!mounted) return;

    setState(() {
      _activities = provider.currentLog?.activities ?? [];
      _saving = false;
      _hasChanges = true;
    });
  }

  Future<void> _removeActivity(ActivityEntry entry) async {
    setState(() => _saving = true);
    final provider = context.read<DailyLogProvider>();
    
    await _service.removeActivity(widget.date, id: entry.id);
    await provider.refreshCurrentLog();

    if (!mounted) return;

    setState(() {
      _activities = provider.currentLog?.activities ?? [];
      _saving = false;
      _hasChanges = true;
    });
  }

  void _saveChanges() {
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmAndRemoveActivity(ActivityEntry entry) async {
    HapticFeedback.mediumImpact();
    await _removeActivity(entry);
    if (!mounted) return;
    // SnackBar при удалении активности убран по требованию
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.grey.shade50,
        appBar: buildGlassAppBar(
          title: const Text('Активность'),
          actions: [
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 56 + 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Symbols.info,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Здесь вы фиксируете все активности за выбранный день.\n'
                              'Эти данные помогают точнее считать сожженные калории\n'
                              'и влияют на суточный баланс в дневнике и аналитике.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(30),
                              borderRadius: AppStyles.mediumBorderRadius,
                            ),
                            child: const Icon(
                              Symbols.local_fire_department,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Всего сожжено',
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 2),
                                Text('$_totalCalories ккал',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Text('${_activities.length} записей',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _activities.isEmpty
                      ? const Center(child: Text('Пока нет активностей'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: _activities.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = _activities[index];
                            return Dismissible(
                              key: ValueKey(entry.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(210),
                                  borderRadius: AppStyles.cardRadius,
                                ),
                                child: const Icon(Symbols.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                await _confirmAndRemoveActivity(entry);
                                return false;
                              },
                              child: Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(30),
                                      borderRadius:
                                          AppStyles.mediumBorderRadius,
                                    ),
                                    child:
                                        Icon(entry.icon, color: Colors.orange),
                                  ),
                                  title: Text(entry.name,
                                      style: theme.textTheme.titleMedium),
                                  subtitle: Text('${entry.calories} ккал'),
                                  onTap: () => _addOrEditActivity(entry: entry),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Symbols.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Удалить активность',
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                            _confirmAndRemoveActivity(entry),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
                right: 24,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _saving
                        ? AppColors.primary.withAlpha(120)
                        : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(100),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(29),
                      onTap: _saving ? null : _addOrEditActivity,
                      child: const Center(
                        child: Icon(
                          Symbols.add,
                          color: Colors.white,
                          size: 30,
                          weight: 700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_saving)
              Container(
                color: Colors.black.withAlpha(30),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
