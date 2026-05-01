import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/recipe.dart';
import '../../services/recipe_loader.dart';
import '../../services/recipe_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_styles.dart';
import '../../widgets/glass_app_bar_background.dart';
import 'create_recipe_from_description_screen.dart';
import 'create_recipe_from_photo_screen.dart';
import 'edit_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'fab_menu_item.dart';

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
  bool _showFabMenu = false;

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
            const SizedBox(height: 6),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelListMaxHeight),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(children: recipeTiles),
                  ),
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
    // SnackBar при успешных действиях убран по требованию

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

    // final count = _selectedRecipeIdsForDelete.length; // не используется
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
    // SnackBar больше не показываем
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    await _recipeService.deleteRecipe(recipe.id);
    _loadAllRecipes();
    // SnackBar больше не показываем
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final fabBottomInset = MediaQuery.of(context).padding.bottom + 8; // не используется
    final fixedTopInset = glassAppBarTotalHeight(context) + 8;

    final fixedSearch = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: AppStyles.defaultBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: kGlassBlurSigma,
            sigmaY: kGlassBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withValues(alpha: kGlassSurfaceAlpha),
              borderRadius: AppStyles.defaultBorderRadius,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: _buildSearchField(isFloatingGlass: true),
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            forceMaterialTransparency: true,
            flexibleSpace: const GlassAppBarBackground(),
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
              SizedBox(height: fixedTopInset),
              fixedSearch,
              _buildSelectedRecipesBar(theme),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (_isDeleteSelectionMode && !widget.selectionMode)
                      SliverToBoxAdapter(
                        child: Padding(
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
                      ),
                    if (_isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredRecipes.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      _buildRecipesList(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: null,
          floatingActionButton: null,
        ),
        if (!widget.selectionMode)
          Positioned(
            right: 24,
            bottom: (MediaQuery.of(context).padding.bottom + 26),
            child: _isDeleteSelectionMode
                ? _buildDeleteFab()
                : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showFabMenu) ...[
                  FabMenuItem(
                    key: UniqueKey(),
                    icon: Symbols.photo_camera,
                    label: 'По фото блюда',
                    onTap: () async {
                      setState(() => _showFabMenu = false);
                      await _navigateAndRefresh(
                          const CreateRecipeFromPhotoScreen());
                    },
                    delay: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 12),
                  FabMenuItem(
                    key: UniqueKey(),
                    icon: Symbols.edit_note,
                    label: 'По описанию',
                    onTap: () async {
                      setState(() => _showFabMenu = false);
                      await _navigateAndRefresh(
                          const CreateRecipeFromDescriptionScreen());
                    },
                    delay: const Duration(milliseconds: 100),
                  ),
                  const SizedBox(height: 12),
                  FabMenuItem(
                    key: UniqueKey(),
                    icon: Symbols.draw,
                    label: 'Вручную',
                    onTap: () async {
                      setState(() => _showFabMenu = false);
                      await _navigateAndRefresh(const EditRecipeScreen());
                    },
                    delay: const Duration(milliseconds: 0),
                  ),
                  const SizedBox(height: 16),
                ],
                GestureDetector(
                  onTap: () => setState(() => _showFabMenu = !_showFabMenu),
                  child: AnimatedRotation(
                    turns: _showFabMenu ? 0.125 : 0.0,
                    duration: const Duration(milliseconds: 220),
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
                      child: const Icon(
                        Symbols.add,
                        color: Colors.white,
                        size: 30,
                        weight: 700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeleteFab() {
    final hasSelection = _selectedRecipeIdsForDelete.isNotEmpty;
    return GestureDetector(
      onTap: hasSelection ? _deleteSelectedRecipes : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasSelection ? Colors.red : Colors.grey.shade400,
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: const Icon(
          Symbols.delete,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildSearchField({bool isFloatingGlass = false}) {
    final inputBorder = OutlineInputBorder(
      borderRadius: AppStyles.defaultBorderRadius,
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: isFloatingGlass
          ? const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0)
          : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          fillColor: isFloatingGlass
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder,
        ),
      ),
    );
  }

  Widget _buildRecipesList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final recipe = _filteredRecipes[index];
            final isSelected = (_selectedRecipeCounts[recipe.id] ?? 0) > 0;
            final item = _RecipeListItem(
              recipe: recipe,
              isSelectionMode: widget.selectionMode || _isDeleteSelectionMode,
              isDeleteMode: _isDeleteSelectionMode && !widget.selectionMode,
              canSelectInDeleteMode: recipe.isUserRecipe,
              isSelected: isSelected,
              isDeleteSelected: _selectedRecipeIdsForDelete.contains(recipe.id),
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
            );

            if (widget.selectionMode) {
              return Dismissible(
                key: ValueKey('recipe-select-${recipe.id}-$isSelected'),
                direction: DismissDirection.endToStart,
                background: _buildSwipeBackground(
                  alignment: Alignment.centerRight,
                  color: AppColors.primary,
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
                  return true;
                }
                return false;
              },
              child: item,
            );
          },
          childCount: _filteredRecipes.length,
        ),
      ),
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
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: AppStyles.cardRadius),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppStyles.cardRadius,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
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
