import 'package:flutter/material.dart';

class DevLogsScreen extends StatelessWidget {
  final List<String> logs;
  const DevLogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Логи приложения')),
      body: logs.isEmpty
          ? const Center(child: Text('Логи отсутствуют'))
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
