import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../services/daily_log_service.dart';
import '../../styles/app_colors.dart';
import '../../widgets/glass_app_bar_background.dart';

class WeightEntryScreen extends StatefulWidget {
  final DateTime date;
  final double? currentWeight;
  final UserProfile profile;

  const WeightEntryScreen({
    super.key,
    required this.date,
    required this.currentWeight,
    required this.profile,
  });

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  final DailyLogService _service = DailyLogService();
  late TextEditingController _weightController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.currentWeight?.toStringAsFixed(1) ?? '',
    );
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
    await _service.setWeight(widget.date, weight: value);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final goalLabel = widget.profile.goalType.ruLabel;
    final goalHint = widget.profile.goalType.ruHint;
    final dateText = DateFormat('d MMMM yyyy', 'ru_RU').format(widget.date);
    final savedWeightText = widget.currentWeight == null
        ? 'За $dateText вес еще не сохранен'
        : 'Сохранено за $dateText: ${widget.currentWeight!.toStringAsFixed(1)} кг';

    return Scaffold(
      appBar: buildGlassAppBar(title: const Text('Вес')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Здесь вы вносите вес за конкретную дату.\n'
                        'Регулярные записи помогают видеть реальную динамику\n'
                        'и точнее отслеживать прогресс по вашей цели.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ваша основная цель'),
                    const SizedBox(height: 6),
                    Text(goalLabel,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      goalHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        'Целевой вес: ${widget.profile.weightGoal.toStringAsFixed(1)} кг'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Вес за выбранную дату'),
                    const SizedBox(height: 6),
                    Text(savedWeightText,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Введите вес в кг',
                        suffixText: 'кг',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Сохранить вес'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
