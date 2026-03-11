import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.chevron_left),
          onPressed: () {},
        ),
        title: Text('Анализ', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Symbols.share),
            onPressed: () {},
          ),
        ],
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTimeframeSwitch(context),
            const SizedBox(height: 24),
            _buildWeightProgress(context),
            const SizedBox(height: 24),
            _buildGridStats(context),
            const SizedBox(height: 24),
            _buildSleepQuality(context),
            const SizedBox(height: 24),
            _buildActivityList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSwitch(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: const Text('День'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  )),
              child: const Text('Неделя'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: const Text('Месяц'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightProgress(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Прогресс веса', style: textTheme.titleMedium),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '72.5', style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                TextSpan(text: ' кг', style: textTheme.headlineSmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          // Placeholder for graph
          Container(
            height: 150,
            width: double.infinity,
            alignment: Alignment.center,
            child: Text('Graph Placeholder', style: textTheme.labelLarge?.copyWith(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildGridStats(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildStepsCard(context)),
        const SizedBox(width: 16),
        Expanded(child: _buildWaterCard(context)),
      ],
    );
  }

  Widget _buildStepsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.footprint, color: Colors.orange, size: 32),
          const SizedBox(height: 8),
          Text('Шаги (среднее)', style: theme.textTheme.titleSmall),
          Text('8,432', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.84,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          )
        ],
      ),
    );
  }

  Widget _buildWaterCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.water_drop, color: Colors.blue, size: 32),
          const SizedBox(height: 8),
          Text('Вода (в день)', style: theme.textTheme.titleSmall),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '2.1', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                TextSpan(text: ' л', style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Placeholder for wave
          Container(height: 20, color: Colors.blue.withAlpha(51)),
        ],
      ),
    );
  }

  Widget _buildSleepQuality(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          const Icon(Symbols.bedtime, color: Colors.indigo, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Качество сна', style: theme.textTheme.titleMedium),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '7ч 45м', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' Хорошо', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text('88%', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActivityList(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Активность за неделю', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('См. все')),
          ],
        ),
        const SizedBox(height: 16),
        _buildActivityItem(context, Symbols.fitness_center, 'Силовая тренировка', 'Пятница, 18:30', '-340 ккал'),
        const SizedBox(height: 12),
        _buildActivityItem(context, Symbols.pool, 'Плавание', 'Среда, 07:15', '-280 ккал'),
        const SizedBox(height: 12),
        _buildActivityItem(context, Symbols.directions_run, 'Бег трусцой', 'Понедельник, 19:00', '-190 ккал'),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, IconData icon, String title, String subtitle, String calories) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: theme.primaryColor),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
            ],
          ),
          const Spacer(),
          Text(calories, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
        ],
      ),
    );
  }
}
