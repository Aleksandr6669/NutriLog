import 'package:flutter/material.dart';
import 'package:nutri_log/styles/app_colors.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class WhatsNewScreen extends StatelessWidget {
  final String version;
  final String text;
  final Future<void> Function()? onAcknowledged;

  const WhatsNewScreen({
    super.key,
    required this.version,
    required this.text,
    this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.whatsNew),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppLocalizations.of(context)!.version} $version',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (onAcknowledged != null) {
                      await onAcknowledged!.call();
                    } else {
                      Navigator.of(context).pop(true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(AppLocalizations.of(context)!.acknowledged),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
