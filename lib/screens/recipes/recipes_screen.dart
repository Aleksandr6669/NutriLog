import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/recipe.dart';
import '../../services/recipe_loader.dart';
import '../../services/recipe_service.dart';
import '../../styles/app_styles.dart';
import 'edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _searchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();

  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllRecipes();
    _searchController.addListener(_filterRecipes);
  }

  Future<void> _loadAllRecipes() async {
    setState(() => _isLoading = true);
    final defaultRecipes = await RecipeLoader.loadRecipesFromAssets();
    final userRecipes = await _recipeService.loadUserRecipes();

    for (var recipe in userRecipes) {
      recipe.isUserRecipe = true;
    }

    // Пользовательские рецепты сверху (новые первыми), встроенные внизу
    userRecipes.sort((a, b) => b.id.compareTo(a.id));
    final allRecipes = [...userRecipes, ...defaultRecipes];

    setState(() {
      _allRecipes = allRecipes;
      _filteredRecipes = _allRecipes;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterRecipes);
    _searchController.dispose();
    super.dispose();
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecipes = _allRecipes.where((recipe) {
        return recipe.name.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    final result = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => screen));
    if (result == true) {
      _loadAllRecipes();
    }
  }

  Future<void> _editRecipe(Recipe recipe) async {
    await _navigateAndRefresh(EditRecipeScreen(recipe: recipe));
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рецепт?'),
        content: Text('Вы уверены, что хотите удалить "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _recipeService.deleteRecipe(recipe.id);
      _loadAllRecipes();
    }
  }

  Future<void> _showAndroidContextMenu(Recipe recipe) async {
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Symbols.edit),
                title: const Text('Редактировать'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Symbols.delete, color: Colors.red),
                title:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedAction == 'edit') {
      await _editRecipe(recipe);
    } else if (selectedAction == 'delete') {
      await _deleteRecipe(recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: const Text('Мои рецепты',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add_circle_outline, size: 28),
            onPressed: () => _navigateAndRefresh(const EditRecipeScreen()),
            tooltip: 'Добавить рецепт',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecipes.isEmpty
                    ? _buildEmptyState()
                    : _buildRecipesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Найти рецепт...',
          prefixIcon: Icon(Symbols.search, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(
            borderRadius: AppStyles.defaultBorderRadius,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRecipesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _filteredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _filteredRecipes[index];
        final item = _RecipeListItem(
          recipe: recipe,
          onTap: () => _navigateAndRefresh(RecipeDetailScreen(recipe: recipe)),
          onLongPress: recipe.isUserRecipe &&
                  defaultTargetPlatform == TargetPlatform.android
              ? () => _showAndroidContextMenu(recipe)
              : null,
        );

        if (!recipe.isUserRecipe) return item;

        return Dismissible(
          key: ValueKey('recipe-swipe-${recipe.id}'),
          direction: DismissDirection.horizontal,
          background: _buildSwipeBackground(
            alignment: Alignment.centerLeft,
            color: Colors.blue.shade600,
            icon: Symbols.edit,
            label: 'Редактировать',
          ),
          secondaryBackground: _buildSwipeBackground(
            alignment: Alignment.centerRight,
            color: Colors.red.shade600,
            icon: Symbols.delete,
            label: 'Удалить',
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await _editRecipe(recipe);
              return false;
            }
            if (direction == DismissDirection.endToStart) {
              await _deleteRecipe(recipe);
              return false;
            }
            return false;
          },
          child: item,
        );
      },
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppStyles.cardRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          if (alignment == Alignment.centerRight) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          if (alignment == Alignment.centerLeft)
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Symbols.search_off : Symbols.receipt_long,
            size: 80,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'Ничего не найдено' : 'У вас пока нет рецептов',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              isSearching
                  ? 'Попробуйте изменить запрос'
                  : 'Нажмите +, чтобы добавить свой первый рецепт',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RecipeListItem({
    required this.recipe,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppStyles.cardRadius,
        splashColor: theme.colorScheme.primary.withOpacity(0.1),
        highlightColor: theme.colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Icon(recipe.icon,
                    color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                    if (recipe.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          recipe.description,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
