import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nutri_log/models/user_profile.dart';
import 'package:nutri_log/services/daily_log_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:provider/provider.dart';
import 'package:nutri_log/providers/profile_provider.dart';
import 'package:nutri_log/providers/daily_log_provider.dart';

class WeightEntryScreen extends StatefulWidget {
  final DateTime date;

  const WeightEntryScreen({
    super.key,
    required this.date,
  });

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  late TextEditingController _weightController;
  bool _saving = false;
  double? _currentWeight;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final log = await DailyLogService().getLogForDate(widget.date);
    
    if (!mounted) return;
    setState(() {
      _currentWeight = log.weight;
      _weightController.text = _currentWeight?.toStringAsFixed(1) ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;

    setState(() => _saving = true);
    
    final logProvider = context.read<DailyLogProvider>();
    final profileProvider = context.read<ProfileProvider>();
    
    await logProvider.updateWeight(value);
    await profileProvider.refreshProfile();
    
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = profileProvider.profile;

        if (_loading || profile == null) {
          return Scaffold(
            appBar: buildGlassAppBar(title: const Text('Вес')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final goalLabel = profile.goalType.ruLabel;
        final goalHint = profile.goalType.ruHint;
        final dateText = DateFormat('d MMMM yyyy', 'ru_RU').format(widget.date);
        final savedWeightText = _currentWeight == null
            ? 'За $dateText вес еще не сохранен'
            : 'Сохранено за $dateText: ${_currentWeight!.toStringAsFixed(1)} кг';

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: buildGlassAppBar(title: const Text('Вес')),
          body: SingleChildScrollView(
            padding: glassBodyPadding(context, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Symbols.info,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Текущая цель: $goalLabel',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                goalHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  savedWeightText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).hintColor,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                    decoration: const InputDecoration(
                      hintText: '0.0',
                      suffixText: 'кг',
                      suffixStyle: TextStyle(fontSize: 20, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,1}')),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить вес'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
