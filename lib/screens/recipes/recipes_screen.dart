import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/recipe.dart';
import '../../services/recipe_loader.dart';
import '../../services/recipe_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import 'create_recipe_from_description_screen.dart';
import 'create_recipe_from_photo_screen.dart';
import 'edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends StatefulWidget {
  final bool selectionMode;
  final Set<String> initialSelectedRecipeIds;

  const RecipesScreen({
    super.key,
    this.selectionMode = false,
    this.initialSelectedRecipeIds = const <String>{},
  });

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _searchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();

  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  bool _selectedRecipesCollapsed = true;
  late Map<String, int> _selectedRecipeCounts;

  @override
  void initState() {
    super.initState();
    _selectedRecipeCounts = {
      for (final id in widget.initialSelectedRecipeIds) id: 1,
    };
    _loadAllRecipes();
    _searchController.addListener(_filterRecipes);
  }

  void _addRecipeSelection(Recipe recipe) {
    setState(() {
      _selectedRecipeCounts[recipe.id] =
          (_selectedRecipeCounts[recipe.id] ?? 0) + 1;
    });
  }

  void _removeRecipeSelection(Recipe recipe) {
    final currentCount = _selectedRecipeCounts[recipe.id] ?? 0;
    if (currentCount <= 0) return;

    setState(() {
      if (currentCount == 1) {
        _selectedRecipeCounts.remove(recipe.id);
      } else {
        _selectedRecipeCounts[recipe.id] = currentCount - 1;
      }
    });
  }

  Future<void> _openRecipeDetail(Recipe recipe) async {
    if (!widget.selectionMode) {
      await _navigateAndRefresh(RecipeDetailScreen(recipe: recipe));
      return;
    }

    final isSelected = (_selectedRecipeCounts[recipe.id] ?? 0) > 0;
    final detailResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: recipe,
          selectionMode: true,
          isSelected: isSelected,
        ),
      ),
    );

    if (detailResult == null) return;

    if (detailResult) {
      _addRecipeSelection(recipe);
    }
  }

  void _finishSelection() {
    final selectedRecipes = <Recipe>[];
    for (final recipe in _allRecipes) {
      final count = _selectedRecipeCounts[recipe.id] ?? 0;
      for (var i = 0; i < count; i++) {
        selectedRecipes.add(recipe);
      }
    }
    Navigator.of(context).pop(selectedRecipes);
  }

  Widget _buildSelectedRecipesBar(ThemeData theme) {
    if (!widget.selectionMode || _selectedRecipeCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedRecipes = _allRecipes
        .where((recipe) => (_selectedRecipeCounts[recipe.id] ?? 0) > 0)
        .toList();
    final totalSelected =
        _selectedRecipeCounts.values.fold<int>(0, (a, b) => a + b);
    final canCollapse = selectedRecipes.length > 3;
    final visibleRecipes = (_selectedRecipesCollapsed && canCollapse)
        ? selectedRecipes.take(3).toList()
        : selectedRecipes;
    final screenHeight = MediaQuery.of(context).size.height;
    const oneCardHeight = 76.0;
    final collapsedMaxHeight = screenHeight * 0.24;
    final expandedMaxHeight = (screenHeight * 0.78) - oneCardHeight;
    final panelListMaxHeight =
        _selectedRecipesCollapsed ? collapsedMaxHeight : expandedMaxHeight;
    final panelColor = AppColors.primary.withAlpha(24);
    final itemBgColor = Colors.white.withAlpha(220);
    const iconColor = AppColors.primary;
    final recipeTiles = visibleRecipes.map(
      (recipe) {
        final count = _selectedRecipeCounts[recipe.id] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: itemBgColor,
              borderRadius: AppStyles.smallBorderRadius,
            ),
            child: Row(
              children: [
                Icon(
                  recipe.icon,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recipe.name} x$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.remove_circle, size: 18),
                  color: iconColor,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeRecipeSelection(recipe),
                  tooltip: 'Убрать одну порцию',
                ),
              ],
            ),
          ),
        );
      },
    ).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: AppStyles.mediumBorderRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Добавлено: $totalSelected',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: panelListMaxHeight),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(children: recipeTiles),
                ),
              ),
            ),
            if (canCollapse)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedRecipesCollapsed = !_selectedRecipesCollapsed;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedRecipesCollapsed
                            ? Symbols.expand_more
                            : Symbols.expand_less,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedRecipesCollapsed
                            ? 'Показать все (${selectedRecipes.length})'
                            : 'Свернуть до 3',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Future<void> _showCreateRecipeMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Как создать рецепт?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: const Icon(Symbols.photo_camera),
                  title: const Text('По фото блюда'),
                  subtitle: const Text('Распознать ингредиенты с фото'),
                  onTap: () => Navigator.of(context).pop('photo'),
                ),
                ListTile(
                  leading: const Icon(Symbols.edit_note),
                  title: const Text('По описанию'),
                  subtitle: const Text('Сгенерировать по текстовому описанию'),
                  onTap: () => Navigator.of(context).pop('description'),
                ),
                ListTile(
                  leading: const Icon(Symbols.draw),
                  title: const Text('Вручную'),
                  subtitle: const Text('Открыть форму создания рецепта'),
                  onTap: () => Navigator.of(context).pop('manual'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    if (selected == 'manual') {
      await _navigateAndRefresh(const EditRecipeScreen());
      return;
    }

    if (selected == 'photo') {
      await _navigateAndRefresh(const CreateRecipeFromPhotoScreen());
      return;
    }

    if (selected == 'description') {
      await _navigateAndRefresh(const CreateRecipeFromDescriptionScreen());
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепт удалён!', style: TextStyle(fontSize: 18)),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 0, left: 16, right: 16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: Text(
          widget.selectionMode ? 'Добавить в прием пищи' : 'Мои рецепты',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        actions: [
          if (widget.selectionMode)
            IconButton(
              icon: const Icon(Symbols.check_circle, size: 28),
              onPressed: _finishSelection,
              tooltip: 'Готово',
            )
          else
            IconButton(
              icon: const Icon(Symbols.add_circle_outline, size: 28),
              onPressed: _showCreateRecipeMenu,
              tooltip: 'Добавить рецепт',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildSelectedRecipesBar(theme),
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
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Symbols.close, color: Colors.grey.shade600),
                  tooltip: 'Очистить поиск',
                  onPressed: () {
                    _searchController.clear();
                    _filterRecipes();
                  },
                )
              : null,
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
        final isSelected = (_selectedRecipeCounts[recipe.id] ?? 0) > 0;
        final item = _RecipeListItem(
          recipe: recipe,
          isSelectionMode: widget.selectionMode,
          isSelected: isSelected,
          onTap: () => _openRecipeDetail(recipe),
          onActionTap:
              widget.selectionMode ? () => _addRecipeSelection(recipe) : null,
        );

        if (widget.selectionMode) {
          return Dismissible(
            key: ValueKey('recipe-add-swipe-${recipe.id}'),
            direction: DismissDirection.startToEnd,
            background: _buildSwipeBackground(
              alignment: Alignment.centerLeft,
              color: Colors.green.shade600,
              icon: Symbols.add_circle,
              label: 'Добавить',
            ),
            confirmDismiss: (_) async {
              _addRecipeSelection(recipe);
              return false;
            },
            child: item,
          );
        }

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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onActionTap;

  const _RecipeListItem({
    required this.recipe,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onActionTap,
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
              if (isSelectionMode)
                IconButton(
                  icon: Icon(
                    Symbols.add_circle,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: onActionTap,
                  tooltip: isSelected ? 'Добавить еще' : 'Добавить',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
