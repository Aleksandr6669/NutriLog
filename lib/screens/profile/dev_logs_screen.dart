import 'package:flutter/material.dart';
import 'package:nutri_log/l10n/app_localizations.dart';

class DevLogsScreen extends StatelessWidget {
  final List<String> logs;
  const DevLogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appLogs)),
      body: logs.isEmpty
          ? Center(child: Text(l10n.noLogs))
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(logs[index],
                    style: const TextStyle(fontFamily: 'monospace')),
              ),
            ),
    );
  }
}
