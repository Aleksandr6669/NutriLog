import 'dart:ui';

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
  bool _isDeleteSelectionMode = false;
  late Map<String, int> _selectedRecipeCounts;
  final Set<String> _selectedRecipeIdsForDelete = <String>{};

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

  void _toggleDeleteSelectionMode() {
    setState(() {
      _isDeleteSelectionMode = !_isDeleteSelectionMode;

      // Когда входим в режим удаления, очищаем поиск и показываем все рецепты
      if (_isDeleteSelectionMode) {
        _searchController.clear();
        _filteredRecipes = _allRecipes;
      } else {
        _selectedRecipeIdsForDelete.clear();
        // Восстанавливаем фильтрацию по текущему поисковому запросу
        _filterRecipes();
      }
    });
  }

  void _toggleRecipeForDelete(Recipe recipe) {
    if (!recipe.isUserRecipe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Встроенные рецепты удалять нельзя.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(top: 0, left: 16, right: 16),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedRecipeIdsForDelete.contains(recipe.id)) {
        _selectedRecipeIdsForDelete.remove(recipe.id);
      } else {
        _selectedRecipeIdsForDelete.add(recipe.id);
      }
    });
  }

  Future<void> _deleteSelectedRecipes() async {
    if (_selectedRecipeIdsForDelete.isEmpty) return;

    final count = _selectedRecipeIdsForDelete.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные рецепты?'),
        content: Text('Будет удалено: $count'),
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

    if (confirmed != true) return;

    final ids = _selectedRecipeIdsForDelete.toList(growable: false);
    for (final id in ids) {
      await _recipeService.deleteRecipe(id);
    }

    if (!mounted) return;

    setState(() {
      _isDeleteSelectionMode = false;
      _selectedRecipeIdsForDelete.clear();
    });

    await _loadAllRecipes();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Удалено рецептов: $count',
            style: const TextStyle(fontSize: 18)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 0, left: 16, right: 16),
      ),
    );
  }

  Future<void> _showCreateRecipeMenu() async {
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierLabel: 'Закрыть',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      pageBuilder: (context, animation, secondaryAnimation) {
        final theme = Theme.of(context);
        final optionBg = theme.brightness == Brightness.dark
            ? AppColors.cardDark
            : Colors.white;

        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Material(
                      color: optionBg,
                      borderRadius: BorderRadius.circular(24),
                      elevation: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                                child: Text(
                                  'Как создать рецепт?',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                                child: Text(
                                  'Выберите удобный способ и продолжайте в редакторе.',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Нейросеть может ошибаться примерно на 10%. Проверьте результат перед сохранением.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _CreateRecipeOptionTile(
                                icon: Symbols.photo_camera,
                                title: 'По фото блюда',
                                subtitle: 'Распознать ингредиенты с фото',
                                onTap: () => Navigator.of(context).pop('photo'),
                              ),
                              const SizedBox(height: 8),
                              _CreateRecipeOptionTile(
                                icon: Symbols.edit_note,
                                title: 'По описанию',
                                subtitle:
                                    'Сгенерировать по текстовому описанию',
                                onTap: () =>
                                    Navigator.of(context).pop('description'),
                              ),
                              const SizedBox(height: 8),
                              _CreateRecipeOptionTile(
                                icon: Symbols.draw,
                                title: 'Вручную',
                                subtitle: 'Открыть форму создания рецепта',
                                onTap: () =>
                                    Navigator.of(context).pop('manual'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
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
    final fabBottomInset = MediaQuery.of(context).padding.bottom + 8;

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
              onPressed: _toggleDeleteSelectionMode,
              icon: Icon(
                _isDeleteSelectionMode
                    ? Icons.close_rounded
                    : Icons.check_box_outlined,
                size: 28,
              ),
              tooltip: _isDeleteSelectionMode ? 'Отмена выбора' : 'Выбрать',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildSelectedRecipesBar(theme),
          if (_isDeleteSelectionMode && !widget.selectionMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выбрано: ${_selectedRecipeIdsForDelete.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecipes.isEmpty
                    ? _buildEmptyState()
                    : _buildRecipesList(),
          ),
        ],
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : _isDeleteSelectionMode
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: fabBottomInset),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(100),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(29),
                        onTap: _showCreateRecipeMenu,
                        child: const Center(
                          child: Icon(
                            Symbols.add,
                            color: Colors.white,
                            size: 30,
                            weight: 700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: (_isDeleteSelectionMode && !widget.selectionMode)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedRecipeIdsForDelete.isEmpty
                        ? null
                        : _deleteSelectedRecipes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Symbols.delete),
                    label: const Text('Удалить'),
                  ),
                ),
              ),
            )
          : null,
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
          isSelectionMode: widget.selectionMode || _isDeleteSelectionMode,
          isDeleteMode: _isDeleteSelectionMode && !widget.selectionMode,
          canSelectInDeleteMode: recipe.isUserRecipe,
          isSelected: isSelected,
          onTap: () {
            if (widget.selectionMode) {
              _addRecipeSelection(recipe);
              return;
            }
            if (_isDeleteSelectionMode) {
              if (!recipe.isUserRecipe) return;
              _toggleRecipeForDelete(recipe);
              return;
            }
            _openRecipeDetail(recipe);
          },
          onActionTap: widget.selectionMode
              ? () => _addRecipeSelection(recipe)
              : (_isDeleteSelectionMode
                  ? () => _toggleRecipeForDelete(recipe)
                  : null),
          isDeleteSelected: _selectedRecipeIdsForDelete.contains(recipe.id),
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
  final bool isDeleteMode;
  final bool canSelectInDeleteMode;
  final bool isSelected;
  final bool isDeleteSelected;
  final VoidCallback? onActionTap;

  const _RecipeListItem({
    required this.recipe,
    required this.onTap,
    this.isSelectionMode = false,
    this.isDeleteMode = false,
    this.canSelectInDeleteMode = true,
    this.isSelected = false,
    this.isDeleteSelected = false,
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
              if (isSelectionMode && (!isDeleteMode || canSelectInDeleteMode))
                IconButton(
                  icon: Icon(
                    isDeleteMode
                        ? (isDeleteSelected
                            ? Symbols.check_circle
                            : Symbols.radio_button_unchecked)
                        : Symbols.add_circle,
                    color: isDeleteMode
                        ? (isDeleteSelected
                            ? Colors.red
                            : theme.colorScheme.primary)
                        : theme.colorScheme.primary,
                  ),
                  onPressed: onActionTap,
                  tooltip: isDeleteMode
                      ? (isDeleteSelected ? 'Снять выбор' : 'Выбрать')
                      : (isSelected ? 'Добавить еще' : 'Добавить'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRecipeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateRecipeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Symbols.chevron_right,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
