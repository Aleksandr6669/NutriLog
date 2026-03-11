import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../services/fatsecret_service.dart';
import '../../models/fatsecret_food.dart';
import '../details/details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fatsecretService = FatsecretService();
  final _searchController = TextEditingController();
  Future<List<FatsecretFood>>? _searchFuture;

  void _performSearch(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _searchFuture = _fatsecretService.searchFoods(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск продуктов', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Symbols.help_outline), onPressed: () {}),
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSearchBar(context),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Найти еду или бренд...',
        prefixIcon: const Icon(Symbols.search, color: Colors.grey),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      ),
      onSubmitted: _performSearch,
    );
  }

  Widget _buildSearchResults() {
    if (_searchFuture == null) {
      return const Center(
        child: Text('Введите поисковый запрос, чтобы начать.', style: TextStyle(color: Colors.grey)),
      );
    }

    return FutureBuilder<List<FatsecretFood>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Ничего не найдено.'));
        }

        final foods = snapshot.data!;
        return ListView.builder(
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            return _buildSearchItem(context, food);
          },
        );
      },
    );
  }

  Widget _buildSearchItem(BuildContext context, FatsecretFood food) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Symbols.restaurant_menu, color: Colors.grey),
      title: Text(food.foodName, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(food.foodDescription ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Symbols.chevron_right, color: Colors.grey),
      onTap: () async {
          final detailedFood = await _fatsecretService.getFood(food.foodId);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DetailsScreen(foodItem: detailedFood),
            ),
          );
        },
    );
  }
}
