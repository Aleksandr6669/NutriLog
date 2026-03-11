import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск продуктов'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => context.go('/search/recognition'),
          icon: const Icon(Symbols.camera_alt),
          label: const Text('AI Поиск по фото'),
        ),
      ),
    );
  }
}
