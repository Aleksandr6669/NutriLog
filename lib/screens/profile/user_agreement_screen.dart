import 'package:flutter/material.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

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
        title: Text(AppLocalizations.of(context)!.userAgreement),
      ),
      body: ListView(
        padding: glassBodyPadding(context, top: 16, bottom: 40),
        children: [
          _buildSection(
            theme,
            AppLocalizations.of(context)!.agreementSection1Title,
            AppLocalizations.of(context)!.agreementSection1Content,
          ),
          _buildSection(
            theme,
            AppLocalizations.of(context)!.agreementSection2Title,
            AppLocalizations.of(context)!.agreementSection2Content,
          ),
          _buildSection(
            theme,
            AppLocalizations.of(context)!.agreementSection3Title,
            AppLocalizations.of(context)!.agreementSection3Content,
          ),
          _buildSection(
            theme,
            AppLocalizations.of(context)!.agreementSection4Title,
            AppLocalizations.of(context)!.agreementSection4Content,
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
            title: Text(
              AppLocalizations.of(context)!.agreementCheckboxText,
              style: const TextStyle(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: theme.colorScheme.primary,
            contentPadding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.agreementContinueText,
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
                child: Text(
                  AppLocalizations.of(context)!.agreementAcceptButton,
                  style: const TextStyle(
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
