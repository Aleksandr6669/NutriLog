import 'package:flutter/material.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';

class UserAgreementScreen extends StatefulWidget {
  final bool showAcceptButton;
  final VoidCallback? onAccepted;

  const UserAgreementScreen({
    super.key,
    this.showAcceptButton = false,
    this.onAccepted,
  });

  @override
  State<UserAgreementScreen> createState() => _UserAgreementScreenState();
}

class _UserAgreementScreenState extends State<UserAgreementScreen> {
  bool _isCheckboxChecked = false;

  @override
  void initState() {
    super.initState();
    // Если мы просматриваем из настроек (кнопка принятия не нужна),
    // то галочка должна быть уже проставлена.
    if (!widget.showAcceptButton) {
      _isCheckboxChecked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: const Text('Пользовательское соглашение'),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 40),
        children: [
          _buildSection(
            theme,
            '1. Сбор и использование данных',
            'NutriLog собирает данные о вашем питании, весе, физических параметрах и целях, чтобы предоставлять персонализированные расчеты КБЖУ и рекомендации. Ваши данные используются исключительно для функционирования приложения и улучшения вашего опыта.',
          ),
          _buildSection(
            theme,
            '2. Хранение данных',
            'Все ваши данные (дневник питания, рецепты, антропометрические данные) хранятся непосредственно в памяти приложения на вашем устройстве или в вашем личном аккаунте NutriLog. Мы не передаем вашу личную информацию третьим лицам без вашего явного согласия.',
          ),
          _buildSection(
            theme,
            '3. Использование нейросетевых технологий',
            'Приложение использует современные технологии нейронных сетей для анализа ваших приемов пищи, автоматического распознавания продуктов по описанию или фото, а также для помощи в составлении рациона и создании рецептов. Обработка данных происходит анонимно.',
          ),
          _buildSection(
            theme,
            '4. Ответственность',
            'Приложение является инструментом для мониторинга питания и не заменяет консультацию врача или профессионального диетолога. Все расчеты носят рекомендательный характер.',
          ),
          const SizedBox(height: 24),
          
          // Чекбокс согласия
          CheckboxListTile(
            value: _isCheckboxChecked,
            onChanged: widget.showAcceptButton 
                ? (bool? value) {
                    setState(() {
                      _isCheckboxChecked = value ?? false;
                    });
                  }
                : null, // Отключаем изменение, если смотрим через настройки
            title: const Text(
              'Я ознакомлен и принимаю условия пользовательского соглашения',
              style: TextStyle(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: theme.colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: 20),
          Text(
            'Продолжая использовать приложение, вы соглашаетесь с данными условиями.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.showAcceptButton) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isCheckboxChecked ? widget.onAccepted : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Принимаю условия',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
