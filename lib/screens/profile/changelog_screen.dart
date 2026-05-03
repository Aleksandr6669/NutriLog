import 'package:flutter/material.dart';
import 'package:nutri_log/services/app_startup_service.dart';
import 'package:nutri_log/styles/app_colors.dart';
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
          return ListView.builder(
            padding: glassBodyPadding(context, top: 12, bottom: 24),
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final entry = versions[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.new_releases_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.versionLabel(entry.key),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.value,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
