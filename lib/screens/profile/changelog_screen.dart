import 'package:flutter/material.dart';
import 'package:nutri_log/services/app_startup_service.dart';
import 'package:nutri_log/widgets/glass_app_bar_background.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: buildGlassAppBar(
        title: Text(l10n.changelogTitle),
      ),
      body: FutureBuilder<List<MapEntry<String, String>>>(
        future: AppStartupService.getAllVersionChangelog(lang),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final versions = snapshot.data!;
          return ListView(
            padding: glassBodyPadding(context, top: 12, bottom: 24),
            children: [
              for (int i = 0; i < versions.length; i++)
                _buildVersionSection(
                  theme,
                  l10n,
                  versions[i].key,
                  versions[i].value,
                  i,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVersionSection(
    ThemeData theme,
    AppLocalizations l10n,
    String version,
    String content,
    int index,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.versionLabel(version),
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
